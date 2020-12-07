// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

//Import job interfaces and helper interfaces
import '../interfaces/Keep3r/IKeep3rV1Helper.sol';
import '../interfaces/Keep3r/IKeep3rV1Mini.sol';
interface IKeep3rV1Plus is IKeep3rV1Mini {
    function KPRH() external view returns (IKeep3rV1Helper);
    function jobs ( address ) external view returns ( bool );
    function balanceOf(address account) external view returns (uint256);

}
interface IKeep3rJob {
    function work() external;
}

contract MockMetaKeep3r is Ownable {
    using SafeMath for uint256;
    IKeep3rV1Plus public KP3R;

    receive() external payable {}

    modifier upkeep() {
        uint _before = KP3R.bonds(address(this), address(KP3R));
        require(KP3R.isKeeper(msg.sender), "::isKeeper: relayer is not registered");
        _;
        uint _after = KP3R.bonds(address(this), address(KP3R));
        uint _received = _after.sub(_before);
        uint _balance = KP3R.balanceOf(address(this));
        if (_balance < _received) {
            KP3R.receipt(address(KP3R), address(this), _received.sub(_balance));
        }
        _received = _swap(_received);
    }

    //Init interfaces with addresses
    constructor (address token) public {
        KP3R = IKeep3rV1Plus(token);
    }

    //Use this to depricate this job to move rlr to another job later
    function destructJob() public onlyOwner {
     //Get the credits for this job first
     uint256 currKP3RCreds = KP3R.credits(address(this),address(KP3R));
     uint256 currETHCreds = KP3R.credits(address(this),KP3R.ETH());
     //Send out KP3R Credits if any
     if(currKP3RCreds > 0) {
        //Invoke receipt to send all the credits of job to owner
        KP3R.receipt(address(KP3R),owner(),currKP3RCreds);
     }
     //Send out ETH credits if any
     if (currETHCreds > 0) {
        KP3R.receiptETH(owner(),currETHCreds);
     }
     //Finally self destruct the contract after sending the credits
     selfdestruct(payable(owner()));
    }

    function task(address job, bytes calldata data) external upkeep {
        require(KP3R.jobs(job), "MetaKeep3r::work: invalid job");
        (bool success,) = job.call{value : 0}(data);
        require(success, "MetaKeep3r::work: job failure");
    }
    function work(address job) external upkeep {
        require(KP3R.jobs(job), "MetaKeep3r::work: invalid job");
        IKeep3rJob(job).work();
    }
    function _swap(uint _amount) internal returns (uint) {
        return _amount;
    }

}