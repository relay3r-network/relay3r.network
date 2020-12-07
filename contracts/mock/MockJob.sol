// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import '@openzeppelin/contracts/access/Ownable.sol';
//Import job interfaces and helper interfaces
import '../interfaces/Keep3r/IKeep3rV1Mini.sol';


contract MockJob is Ownable {
    IKeep3rV1Mini public RLR;
    uint256 updateme = 0;

    modifier upkeep() {
        require(RLR.isKeeper(msg.sender), "::isKeeper: relayer is not registered");
        _;
        RLR.worked(msg.sender);
    }

    //Init interfaces with addresses
    constructor (address token) public {
        RLR = IKeep3rV1Mini(token);
    }

    //Use this to depricate this job to move rlr to another job later
    function destructJob() public onlyOwner {
     //Get the credits for this job first
     uint256 currRLRCreds = RLR.credits(address(this),address(RLR));
     uint256 currETHCreds = RLR.credits(address(this),RLR.ETH());
     //Send out RLR Credits if any
     if(currRLRCreds > 0) {
        //Invoke receipt to send all the credits of job to owner
        RLR.receipt(address(RLR),owner(),currRLRCreds);
     }
     //Send out ETH credits if any
     if (currETHCreds > 0) {
        RLR.receiptETH(owner(),currETHCreds);
     }
     //Finally self destruct the contract after sending the credits
     selfdestruct(payable(owner()));
    }

    function workable() public view returns (bool) {
        return true;
    }

    function work() public upkeep {
        updateme = 1;
    }

}