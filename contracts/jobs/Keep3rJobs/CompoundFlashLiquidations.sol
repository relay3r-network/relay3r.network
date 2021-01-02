// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;


import { SafeERC20, IERC20 } from "../../libraries/SafeERC20.sol";
import '@openzeppelin/contracts/math/Math.sol';
import "../../interfaces/Keep3r/IKeep3rV1Mini.sol";
// Cream and compound use the same codebase
import '../../interfaces/Cream/ICERC20.sol';
import '../../interfaces/Cream/ICEther.sol';
import '../../interfaces/Cream/IComptroller.sol';

import '../../interfaces/Uniswap/IUniswapV2Pair.sol';

import '../../interfaces/Uniswap/IUniswapV2Router.sol';

import '../../interfaces/Uniswap/IUniswapV2Factory.sol';

import '../../interfaces/Uniswap/IWETH.sol';

import '../../libraries/UniswapV2Library.sol';

contract CompoundFlashLiquidationsKeep3r {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IComptroller constant public Comptroller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    IUniswapV2Factory constant public FACTORY = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IUniswapV2Router constant public ROUTER = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address constant public WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant public cETH = address(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);

    modifier upkeep() {
        require(KP3R.isMinKeeper(tx.origin, 100e18, 0, 0), "::isKeeper: keeper is not registered");
        _;
        KP3R.worked(msg.sender);
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    IKeep3rV1Mini public constant KP3R = IKeep3rV1Mini(0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44);

    function pairFor(address borrowed) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(borrowed, WETH);
        pair = UniswapV2Library.pairFor(address(FACTORY), token0, token1);
    }

    function calcRepayAmount(IUniswapV2Pair pair, uint amount0, uint amount1) public view returns (uint) {
        (uint reserve0, uint reserve1, ) = pair.getReserves();
        uint val = 0;
        if (amount0 == 0) {
            val = amount1.mul(reserve0).div(reserve1);
        } else {
            val = amount0.mul(reserve1).div(reserve0);
        }

        return (val
                .add(val.mul(301).div(100000)))
                .mul(reserve0.mul(reserve1))
                .div(IERC20(pair.token0()).balanceOf(address(pair))
                .mul(IERC20(pair.token1()).balanceOf(address(pair))));
    }
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint) {
        uint amountInWithFee = amountIn.mul(997);
        return amountInWithFee.mul(reserveOut) / reserveIn.mul(1000).add(amountInWithFee);
    }

    function _swap(address suppliedUnderlying, address supplied, IUniswapV2Pair toPair) internal {
        address _underlying = suppliedUnderlying;
        if (supplied == cETH) {
            _underlying = WETH;
            IWETH(WETH).deposit{ value : address(this).balance }();
        } else {
            (uint reserve0, uint reserve1,) = toPair.getReserves();
            uint amountIn = IERC20(_underlying).balanceOf(address(this));
            IERC20(_underlying).transfer(address(toPair), amountIn);
            if (_underlying == toPair.token0()) {
                toPair.swap(0, getAmountOut(amountIn, reserve0, reserve1), address(this), new bytes(0));
            } else {
                toPair.swap(getAmountOut(amountIn, reserve1, reserve0), 0, address(this), new bytes(0));
            }
        }
    }

    function uniswapV2Call(uint amount0, uint amount1, bytes calldata data) external {
        uint liquidatableAmount = (amount0 == 0 ? amount1 : amount0);
        (address borrower, address borrowed, address supplied, address fromPair, address toPair, address suppliedUnderlying) = decode(data);

        ICERC20(borrowed).liquidateBorrow(borrower, liquidatableAmount, supplied);
        ICERC20(supplied).redeem(ICERC20(supplied).balanceOf(address(this)));

        _swap(suppliedUnderlying, supplied, IUniswapV2Pair(toPair));

        IERC20(WETH).transfer(fromPair, calcRepayAmount(IUniswapV2Pair(fromPair), amount0, amount1));
        IERC20(WETH).transfer(tx.origin, IERC20(WETH).balanceOf(address(this)));
    }

    function underlying(address token) external view returns (address) {
        return ICERC20(token).underlying();
    }

    function underlyingPair(address token) external view returns (address) {
        return pairFor(ICERC20(token).underlying());
    }

    receive () external payable { }

    function liquidatable(address borrower, address borrowed) external view returns (uint) {
        (,,uint256 shortFall) = Comptroller.getAccountLiquidity(borrower);
        require(shortFall > 0, "liquidate:shortFall == 0");

        uint256 liquidatableAmount = ICERC20(borrowed).borrowBalanceStored(borrower);

        require(liquidatableAmount > 0, "liquidate:borrowBalanceStored == 0");

        return liquidatableAmount.mul(Comptroller.closeFactorMantissa()).div(1e18);
    }

    function calculate(address borrower, address borrowed, address supplied) external view returns (address fromPair, address toPair, address borrowedUnderlying, address suppliedUnderlying, uint amount) {
        amount = ICERC20(borrowed).borrowBalanceStored(borrower);
        amount = amount.mul(Comptroller.closeFactorMantissa()).div(1e18);
        borrowedUnderlying = ICERC20(borrowed).underlying();

        fromPair = pairFor(borrowedUnderlying);
        suppliedUnderlying = ICERC20(supplied).underlying();
        toPair = pairFor(suppliedUnderlying);
    }

    function liquidate(address borrower, address borrowed, address supplied) external {
        (,,uint256 shortFall) = Comptroller.getAccountLiquidity(borrower);
        require(shortFall > 0, "liquidate:shortFall == 0");

        uint256 amount = ICERC20(borrowed).borrowBalanceStored(borrower);
        require(amount > 0, "liquidate:borrowBalanceStored == 0");
        amount = amount.mul(Comptroller.closeFactorMantissa()).div(1e18);
        require(amount > 0, "liquidate:liquidatableAmount == 0");

        address borrowedUnderlying = ICERC20(borrowed).underlying();

        address fromPair = pairFor(borrowedUnderlying);
        address suppliedUnderlying = ICERC20(supplied).underlying();
        address toPair = pairFor(suppliedUnderlying);

        liquidateCalculated(borrower, borrowed, supplied, fromPair, toPair, borrowedUnderlying, suppliedUnderlying, amount);
    }

    function encode(address borrower, address borrowed, address supplied, address fromPair, address toPair, address suppliedUnderlying) internal pure returns (bytes memory) {
        return abi.encode(borrower, borrowed, supplied, fromPair, toPair, suppliedUnderlying);
    }

    function decode(bytes memory b) internal pure returns (address, address, address, address, address, address) {
        return abi.decode(b, (address, address, address, address, address, address));
    }

    function liquidateCalculated(
        address borrower,
        address borrowed,
        address supplied,
        address fromPair,
        address toPair,
        address borrowedUnderlying,
        address suppliedUnderlying,
        uint amount
    ) public upkeep {
        IERC20(borrowedUnderlying).safeIncreaseAllowance(borrowed, amount);
        (uint _amount0, uint _amount1) = (borrowedUnderlying == IUniswapV2Pair(fromPair).token0() ? (amount, uint(0)) : (uint(0), amount));
        IUniswapV2Pair(fromPair).swap(_amount0, _amount1, address(this), encode(borrower, borrowed, supplied, fromPair, toPair, suppliedUnderlying));
    }
}
