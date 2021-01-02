// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface Keep3r {
    function getKeepers (  ) external view returns ( address[] memory );
    function bonds ( address, address ) external view returns ( uint256 );
    function totalBonded (  ) external view returns ( uint256 );
}

contract KeeperBonderDistributor is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint;
    Keep3r public iKeep3r = Keep3r(0x0E3EF895c59E7Db27214AB5bbf56347cE115A3f4);

    constructor(address keepertoken) public { iKeep3r = Keep3r(keepertoken); }

    receive() external payable {}

    function getKeepersLength() public view returns (uint256 count) {
        return iKeep3r.getKeepers().length;
    }

    function getPositiveKeepersCount() public view returns (uint256 count) {
        address[] memory keepers = iKeep3r.getKeepers();
        count=0;
        for(uint i=0;i<keepers.length;i++) {
            if(iKeep3r.bonds(keepers[i],address(iKeep3r)) > 0) {
                count++;
            }
        }
    }

    function getPositiveKeepers() public view returns (address[] memory positivekeepers) {
        uint index = 0;
        address[] memory keepers = iKeep3r.getKeepers();
        positivekeepers = new address[](getPositiveKeepersCount());
        for(uint i =0;i<keepers.length;i++) {
            if(iKeep3r.bonds(keepers[i],address(iKeep3r)) > 0) {
                positivekeepers[index] = keepers[i];
                index++;
            }
        }
    }

    function distributeToken(address token) public nonReentrant {
        IERC20 iToken = IERC20(token);
        uint256 currTokenBalance = iToken.balanceOf(address(this));
        uint256 totaKP3RBonded = iKeep3r.totalBonded();
        address[] memory eligibleKeepers = getPositiveKeepers();
        for(uint i=0;i<eligibleKeepers.length;i++) {
            iToken.transfer(eligibleKeepers[i],currTokenBalance.mul(iKeep3r.bonds(eligibleKeepers[i],address(iKeep3r))).div(totaKP3RBonded));
        }
    }

    function distributeETH() public nonReentrant {
        uint256 ETHBal = address(this).balance;
        uint256 totaKP3RBonded = iKeep3r.totalBonded();
        address[] memory eligibleKeepers = getPositiveKeepers();
        for(uint i=0;i<eligibleKeepers.length;i++) {
            (bool success ,) = eligibleKeepers[i].call{value:ETHBal.mul(iKeep3r.bonds(eligibleKeepers[i],address(iKeep3r))).div(totaKP3RBonded)}("");
            require(success,"!send");
        }
    }
}