/**
 *Submitted for verification at Etherscan.io on 2020-10-28
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import { SafeERC20, SafeMath, IERC20 } from "../../libraries/SafeERC20.sol";

import '../../interfaces/Keep3r/IKeep3rV1Mini.sol';

interface IAave {
    function liquidationCall(
        address _collateral,
        address _reserve,
        address _user,
        uint256 _purchaseAmount,
        bool _receiveAToken
    ) external payable;
    function getUserReserveData(address _reserve, address _user)
    external
    view
    returns (
        uint256 currentATokenBalance,
        uint256 currentBorrowBalance,
        uint256 principalBorrowBalance,
        uint256 borrowRateMode,
        uint256 borrowRate,
        uint256 liquidityRate,
        uint256 originationFee,
        uint256 variableBorrowIndex,
        uint256 lastUpdateTimestamp,
        bool usageAsCollateralEnabled
    );
}

contract AaveLiquidate {
    using SafeERC20 for IERC20;

    IAave constant public AAVE = IAave(0x398eC7346DcD622eDc5ae82352F02bE94C62d119);
    address constant public CORE = address(0x3dfd23A6c5E8BbcFc9581d2E864a68feb6a076d3);

    function getUserReserveBalance(address _reserve, address _user) public view returns (uint256) {
        (,uint currentBorrowBalance,,,,,,,,) = AAVE.getUserReserveData(_reserve, _user);
        return currentBorrowBalance;
    }

    modifier upkeep() {
        require(KP3R.isKeeper(msg.sender), "::isKeeper: keeper is not registered");
        _;
        KP3R.worked(msg.sender);
    }

    IKeep3rV1Mini public constant KP3R = IKeep3rV1Mini(0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44);

    function liquidate(address _collateral, address _reserve, address _user) external upkeep {
        uint256 _repay = getUserReserveBalance(_reserve, _user);
        require(_repay > 0, "No debt");

        IERC20(_reserve).safeTransferFrom(msg.sender, address(this), _repay);
        IERC20(_reserve).safeApprove(CORE, _repay);
        AAVE.liquidationCall(_collateral, _reserve, _user, _repay, false);
        IERC20(_reserve).safeApprove(CORE, 0);

        uint256 _liquidated = IERC20(_collateral).balanceOf(address(this));
        require(_liquidated > 0, "Failed to liquidate");

        IERC20(_reserve).safeTransfer(msg.sender, IERC20(_reserve).balanceOf(address(this)));
        IERC20(_collateral).safeTransfer(msg.sender, IERC20(_collateral).balanceOf(address(this)));
    }
}
