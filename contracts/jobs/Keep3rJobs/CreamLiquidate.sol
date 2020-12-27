// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

//Import openzepplin libraries and interfaces
import '@openzeppelin/contracts/math/SafeMath.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import '../../interfaces/Keep3r/IKeep3rV1Mini.sol';
//Import Cream interfaces
import '../../interfaces/Cream/ICERC20.sol';
import '../../interfaces/Cream/ICEther.sol';
import '../../interfaces/Cream/IComptroller.sol';



contract CreamLiquidate {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IComptroller constant public Comptroller = IComptroller(0x3d5BC3c8d13dcB8bF317092d84783c2697AE9258);

    modifier upkeep() {
        require(KP3R.isKeeper(msg.sender), "::isKeeper: keeper is not registered");
        _;
        KP3R.worked(msg.sender);
    }

    IKeep3rV1Mini public constant KP3R = IKeep3rV1Mini(0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44);

    function liquidate(address borrower, uint256 _repayAmount, address cTokenBorrow, address cTokenCollateral) external upkeep {
        (,,uint256 shortFall) = Comptroller.getAccountLiquidity(borrower);
        require(shortFall > 0, "!shortFall");

        uint256 repayAmount;
        uint256 liquidatableAmount = ICERC20(cTokenBorrow).borrowBalanceStored(borrower);
        liquidatableAmount = liquidatableAmount.mul(Comptroller.closeFactorMantissa()).div(1e18);
        if(_repayAmount == uint256(-1)) {
            repayAmount = liquidatableAmount;
        } else {
            repayAmount = _repayAmount;
        }
        require(repayAmount <= liquidatableAmount, ">liquidatableAmount");

        address underlying = ICERC20(cTokenBorrow).underlying();
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), repayAmount);
        IERC20(underlying).safeIncreaseAllowance(cTokenBorrow, repayAmount);
        uint256 err = ICERC20(cTokenBorrow).liquidateBorrow(borrower, repayAmount, cTokenCollateral);
        require(err == 0, "failed");
        uint256 liquidatedAmount = IERC20(cTokenCollateral).balanceOf(address(this));
        require(liquidatedAmount > 0, "failed");

        IERC20(cTokenCollateral).safeTransfer(msg.sender, IERC20(cTokenCollateral).balanceOf(address(this)));
    }

    function liquidateETH(address borrower, address payable cTokenBorrow, address cTokenCollateral) external payable upkeep {
        (,,uint256 shortFall) = Comptroller.getAccountLiquidity(borrower);
        require(shortFall > 0, "!shortFall");

        uint256 liquidatableAmount = ICEther(cTokenBorrow).borrowBalanceStored(borrower);
        require(msg.value <= liquidatableAmount, ">liquidatableAmount");

        (bool success,) = cTokenBorrow.call{value: msg.value}(
            abi.encodeWithSignature("liquidateBorrow(address, address)", borrower, cTokenCollateral)
        );
        require(success, "failed");
        uint256 liquidatedAmount = IERC20(cTokenCollateral).balanceOf(address(this));
        require(liquidatedAmount > 0, "failed");

        IERC20(cTokenCollateral).safeTransfer(msg.sender, IERC20(cTokenCollateral).balanceOf(address(this)));
    }
}
