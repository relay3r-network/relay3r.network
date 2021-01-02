// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import { SafeERC20, SafeMath, IERC20 } from "../../libraries/SafeERC20.sol";
import '@openzeppelin/contracts/math/Math.sol';

import "../../interfaces/Keep3r/IKeep3rV1Mini.sol";


//Import Cream interfaces
import '../../interfaces/Cream/ICERC20.sol';
import '../../interfaces/Cream/ICEther.sol';
import '../../interfaces/Cream/IComptroller.sol';
//Import Uniswap interfaces
import '../../interfaces/Uniswap/IUniswapV2Pair.sol';

import '../../interfaces/Uniswap/IUniswapV2Router.sol';

import '../../interfaces/Uniswap/IUniswapV2Factory.sol';

import '../../interfaces/Uniswap/IWETH.sol';


contract CreamFlashLiquidate {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IComptroller constant public Comptroller = IComptroller(0x3d5BC3c8d13dcB8bF317092d84783c2697AE9258);
    IUniswapV2Factory constant public FACTORY = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IUniswapV2Router constant public ROUTER = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address constant public WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant public crETH = address(0xD06527D5e56A3495252A528C4987003b712860eE);

    modifier upkeep() {
        require(KP3R.isKeeper(msg.sender), "::isKeeper: keeper is not registered");
        _;
        KP3R.worked(msg.sender);
    }

    IKeep3rV1Mini public constant KP3R = IKeep3rV1Mini(0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44);

    function getPair(address borrow) public view returns (address) {
        return FACTORY.getPair(borrow, WETH);
    }

    function calcRepayAmount(uint amount0, uint amount1) public view returns (uint) {
        (uint reserve0, uint reserve1, ) = _pair.getReserves();
        uint expected = reserve0.mul(reserve1);

        uint balance0 = IERC20(_pair.token0()).balanceOf(address(_pair));
        uint balance1 = IERC20(_pair.token1()).balanceOf(address(_pair));

        uint current = balance0.mul(balance1);

        uint val = 0;
        if (amount0 == 0) {
            val = amount1.mul(reserve0).div(reserve1);
        } else {
            val = amount0.mul(reserve1).div(reserve0);
        }

        uint fee = val.mul(31).div(10000);

        return (val.add(fee)).mul(expected).div(current);
    }

    function uniswapV2Call(uint amount0, uint amount1) external {

        uint liquidatableAmount = (amount0 == 0 ? amount1 : amount0);

        uint256 err = ICERC20(_borrow).liquidateBorrow(_account, liquidatableAmount, _collateral);
        require(err == 0, "failed");

        uint256 liquidatedAmount = IERC20(_collateral).balanceOf(address(this));

        require(liquidatedAmount > 0, "failed");
        require(ICERC20(_collateral).redeem(ICERC20(_collateral).balanceOf(address(this))) == 0, "uniswapV2Call: redeem != 0");

        address underlying;
        if (_collateral == crETH) {
            underlying = WETH;
            IWETH(WETH).deposit{value:address(this).balance}();
        } else {
            underlying = ICERC20(_collateral).underlying();
        }

        if (_borrow != _collateral) {
            if (underlying != WETH) {
                uint swap = IERC20(underlying).balanceOf(address(this));
                address[] memory path = new address[](2);
                    path[0] = address(underlying);
                    path[1] = address(WETH);

                IERC20(underlying).safeApprove(address(ROUTER), swap);
                ROUTER.swapExactTokensForTokens(swap, 0, path, address(this), now.add(1800));
            }
            uint repay = calcRepayAmount(amount0, amount1);
            require(IERC20(WETH).balanceOf(address(this)) > repay, "liquidate: WETH <= repay");
            IERC20(WETH).safeTransfer(address(_pair), repay);
            IERC20(WETH).safeTransfer(tx.origin, IERC20(WETH).balanceOf(address(this)));
        } else {
            IERC20(underlying).safeTransfer(address(_pair), liquidatableAmount.add(liquidatableAmount.mul(31).div(10000)));
            IERC20(underlying).safeTransfer(tx.origin, IERC20(underlying).balanceOf(address(this)));
        }



    }

    address internal _borrow;
    address internal _collateral;
    address internal _account;
    IUniswapV2Pair internal _pair;

    receive() external payable { }

    function liquidate(address borrower, address cTokenBorrow, address cTokenCollateral) external {
        (,,uint256 shortFall) = Comptroller.getAccountLiquidity(borrower);
        require(shortFall > 0, "liquidate:shortFall == 0");

        uint256 liquidatableAmount = ICERC20(cTokenBorrow).borrowBalanceStored(borrower);

        require(liquidatableAmount > 0, "liquidate:borrowBalanceStored == 0");

        liquidatableAmount = liquidatableAmount.mul(Comptroller.closeFactorMantissa()).div(1e18);

        address underlying = ICERC20(cTokenBorrow).underlying();
        IUniswapV2Pair pair = IUniswapV2Pair(getPair(underlying));
        uint available = IERC20(underlying).balanceOf(address(pair));

        liquidatableAmount = Math.min(liquidatableAmount, available);
        require(liquidatableAmount > 0, "liquidate:liquidatableAmount == 0");
        IERC20(underlying).safeIncreaseAllowance(cTokenBorrow, liquidatableAmount);

        (uint _amount0, uint _amount1) = (underlying == pair.token0() ? (liquidatableAmount, uint(0)) : (uint(0), liquidatableAmount));

        _borrow = cTokenBorrow;
        _collateral = cTokenCollateral;
        _account = borrower;
        _pair = pair;

        pair.swap(_amount0, _amount1, address(this), abi.encode(msg.sender));
    }

    function liquidateCalculated(address borrower, IUniswapV2Pair pair, address underlying, uint amount, address repay, address collateral) external {
        IERC20(underlying).safeIncreaseAllowance(repay, amount);
        (uint _amount0, uint _amount1) = (underlying == pair.token0() ? (amount, uint(0)) : (uint(0), amount));

        _borrow = repay;
        _collateral = collateral;
        _account = borrower;

        pair.swap(_amount0, _amount1, address(this), abi.encode(msg.sender));
    }
}
