// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;


import '@openzeppelin/contracts/math/SafeMath.sol';

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';


import '../interfaces/Keep3r/IKeep3rV1Mini.sol';

interface CTokenInterface {
    function accrueInterest() external returns (uint);
}

interface ICERC20 {
    function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) external returns (uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function underlying() external view returns (address);
}

interface IComptroller {
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
    function closeFactorMantissa() external view returns (uint256);
}


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

    function liquidate(address _collateral, address _borrow, address _user) external upkeep {
        (,,uint256 _shortFall) = Comptroller.getAccountLiquidity(_user);
        require(_shortFall > 0, "!shortFall");

        uint256 _to_liquidate = ICERC20(_borrow).borrowBalanceStored(_user);
        _to_liquidate = _to_liquidate.mul(Comptroller.closeFactorMantissa()).div(1e18);

        address underlying = ICERC20(_borrow).underlying();
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), _to_liquidate);
        IERC20(underlying).safeIncreaseAllowance(_borrow, _to_liquidate);
        uint256 err = ICERC20(_borrow).liquidateBorrow(_user, _to_liquidate, CTokenInterface(_collateral));
        require(err == 0, "failed");
        uint256 _liquidated = IERC20(_collateral).balanceOf(address(this));
        require(_liquidated > 0, "failed");

        IERC20(_collateral).safeTransfer(msg.sender, IERC20(_collateral).balanceOf(address(this)));
    }
}
