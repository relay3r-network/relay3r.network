// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../libraries/TransferHelper.sol";
import "../interfaces/Keep3r/IKeep3rV1Mini.sol";

interface iKeep3r is IKeep3rV1Mini ,IERC20 {
    function bondings ( address, address ) external view returns ( uint256 );
    function workCompleted ( address ) external view returns ( uint256 );
    function jobs ( address ) external view returns ( bool );

    function bond(address bonding, uint amount) external;
    function activate(address bonding) external;
    function unbond ( address bonding, uint256 amount ) external;
    function withdraw(address bonding) external;
}

contract WrappedKeep3rRelayer is Ownable, ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for iKeep3r;

    address RLRToken = 0x5b3F693EfD5710106eb2Eac839368364aCB5a70f;

    address public feeGetter = msg.sender;//Deployer is the feeGetter be default

    iKeep3r public KP3R = iKeep3r(address(KP3R));
    IKeep3rV1Mini public RLR = IKeep3rV1Mini(RLRToken);

    uint256 targetKP3RBond = 250e18;
    uint256 unbondTimeFrame = 14 days;

    uint256 lastUnbond = 0;
    uint256 timesUnbonded = 0;
    //Fee data
    /// @notice Service fee at 10 % initially
    uint public FEE = 1000;
    uint constant public BASE = 10000;
    event ServiceFeeChanged(uint256 indexed newFee);
    event Withdrew(address indexed addr, uint256 indexed _shares, uint256 indexed _underlyingToWithdraw,uint256 fee);
    event FeeGetterChanged(address indexed newFeeGetter);

    //Stats
    uint256 totalKP3RDeposited = 0;
    uint256 totalKP3RWithdrawn = 0;

    uint256 totalKP3RRewardsBalance = 0;
    uint256 totalKP3RRewardsPaid = 0;
    mapping (address => uint256) public deposits;
    // mapping (address => uint256) public shares;

    //Taken from yearn vault code
    constructor(address _token, address _tokenrlr)
        public
        ERC20("RelayerKP3R","rKP3R")
    {
        KP3R = iKeep3r(_token);
        RLR = IKeep3rV1Mini(_tokenrlr);
    }

    modifier upkeep() {
        require(RLR.isKeeper(msg.sender), "::isKeeper: relayer is not registered");
        _;
        RLR.worked(msg.sender);
    }

    /**
     * @notice Get remaining kp3r to reach target
     */
    function remainingToTarget() public view returns  (uint256) {
        if(totalKP3RDeposited >= targetKP3RBond)
            return 0;
        return targetKP3RBond.sub(totalKP3RDeposited);
    }

    /**
     * @notice Get if kp3r requirement reached threshold
     */
    function reachedThreshold() public view returns (bool) {
        return remainingToTarget() == 0;
    }

    /**
     * @notice Get bonded kp3r balance
     */
    function getBondedBalance() public view returns (uint256) {
        return KP3R.bonds(address(this),address(KP3R));
    }

    /**
     * @notice Get rewards for executed jobs
     */
    function getWorkRewards() public view returns (uint256) {
        return KP3R.workCompleted(address(this));
    }

    /**
     * @notice Get rewards for executed jobs minus paid out amount
     */
    function getWorkRewardsRemaining() public view returns (uint256) {
        return getWorkRewards() > 0 ? getWorkRewards().sub(totalKP3RRewardsPaid) : 0;
    }

    /**
     * @notice Get time this contract bonded tokens
     */
    function getBondTime() public view returns (uint256) {
        return KP3R.bondings(address(KP3R),address(this));
    }

    /**
     * @notice Get time when partialunbond amount can be withdrawn
     */
    function getUnbondTime() public view returns (uint256) {
        return KP3R.bondings(address(KP3R),address(this));
    }

    /**
     * @notice Get time remaining until bonds can be activated
     */
    function remainingBondingTime() public view returns (uint256){
        if(getBondTime() > block.timestamp)
            return block.timestamp - getBondTime();
        return 0;
    }

    /**
     * @notice Get amount of profit share possibly withdrawable by a address
     */
    function getProfitShareOfAddr(address addr) public view returns (uint256) {
        if(getWorkRewardsRemaining()<= 0)
            return 0;
        uint availRewards = getWorkRewardsRemaining().sub(getProtocolFees(getWorkRewardsRemaining()));
        return availRewards.div(totalKP3RDeposited.div(deposits[addr]));
    }

    /**
     * @notice Get amount of profit share fees in KP3R
     */
    function getProtocolFees(uint256 amount) public view returns (uint256) {
        return amount.mul(FEE).div(BASE);
    }

    /**
     * @notice Get amount of profit share possibly withdrawable by caller's address
     */
    function getProfitShare() public view returns (uint256) {
        return getProfitShareOfAddr(msg.sender);
    }

    function workableUnbond() public view returns (bool) {
        return (block.timestamp - lastUnbond) > unbondTimeFrame;
    }

    function getPricePerFullShare() public view returns (uint256) {
        return totalUnderlying().mul(1e18).div(totalSupply());
    }

    function unusedUnderlyingBalance() public view returns (uint256) {
        return KP3R.balanceOf(address(this));
    }

    function totalUnderlying() public view returns (uint256) {
        return unusedUnderlyingBalance().add(getBondedBalance());
    }

    /**
     * @notice Set new service fee for pool by owner
     */
    function setServicefee(uint256 fee) public onlyOwner {
        FEE = fee;
        emit ServiceFeeChanged(fee);
    }

    function setFeeGetter(address newFeeGetter) public onlyOwner{
        feeGetter = newFeeGetter;
        emit FeeGetterChanged(newFeeGetter);
    }

    /**
     * @notice deposit kp3r tokens to contract
     * @param _amount of kp3r to deposit
    */
    function deposit(uint256 _amount) public {
        require(!reachedThreshold(),"!limit");
        uint256 _pool = unusedUnderlyingBalance();
        uint256 _before = unusedUnderlyingBalance();
        KP3R.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = unusedUnderlyingBalance();
        _amount = _after.sub(_before); // Additional check for deflationary tokens
        //Update deposit data
        totalKP3RDeposited = totalKP3RDeposited.add(_amount);
        deposits[msg.sender] = deposits[msg.sender].add(_amount);
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
    }

    /** Withdraw
    *  User should withdraw amount of KP3R Share erc20 tokens into the pool and receive KP3R  back */
    function withdraw(uint256 _shares) public returns (uint256 _underlyingToWithdraw) {
        _underlyingToWithdraw = (totalUnderlying().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);
        uint256 fee = getProtocolFees(_underlyingToWithdraw);
        // Check balance
        uint256 _unusedUnderlyingBalance = unusedUnderlyingBalance();
        if (_underlyingToWithdraw > _unusedUnderlyingBalance) {
            uint256 _missingUnderlying = _underlyingToWithdraw.sub(_unusedUnderlyingBalance);

            // Check if we can unbond to satisfy missing balance
            if(workableUnbond()) KP3R.withdraw(address(KP3R));

            uint256 _underlyingAfterUnbond = unusedUnderlyingBalance();

            // Revert if we still haven't got enough underlying.
            require(_underlyingAfterUnbond >= _underlyingToWithdraw, 'kp3r-pool/not-enough-to-unbond');
            //Remove rewards balance if the above check passes
            totalKP3RRewardsBalance = totalKP3RRewardsBalance.sub(_underlyingAfterUnbond.sub(_underlyingToWithdraw));
        }

        if(_underlyingToWithdraw > deposits[msg.sender])
            _underlyingToWithdraw = _underlyingToWithdraw.sub(fee);
        else
            fee = 0;
        KP3R.safeTransfer(msg.sender, _underlyingToWithdraw);
        KP3R.safeTransfer(feeGetter, fee);
        //Update deposit data
        deposits[msg.sender] = deposits[msg.sender].sub(_underlyingToWithdraw);

        emit Withdrew(msg.sender, _shares, _underlyingToWithdraw,fee);
    }

    /**
     * @notice Withdraw deposit from caller address balance
    */
    function withdrawAll() external returns (uint256 _underlyingToWithdraw) {
        return withdraw(balanceOf(msg.sender));
    }

    /**
     * @notice Start bonding the kp3r balance in contract
    */
    function bondBalance() public {
        require(reachedThreshold(),"!limit");
        KP3R.bond(address(KP3R),unusedUnderlyingBalance());
    }

    /**
     * @notice Activate pending bonds to activate keeper rights
    */
    function activateBonds() public upkeep {
        KP3R.activate(address(KP3R));
    }

    function startUnbondingRewards() public upkeep {
        //Check if we have pending unbonds,if so withdraw those to contract
        require(workableUnbond(),"!workable");

        uint256 before = unusedUnderlyingBalance();

        KP3R.withdraw(address(KP3R));

        uint256 afterx = unusedUnderlyingBalance();
        uint256 diff = afterx.sub(before);

        require(diff > 0 ,"No rewards gotten");

        totalKP3RRewardsBalance = totalKP3RRewardsBalance.add(diff);
        //Now call unbond for work rewards
        KP3R.unbond(address(KP3R),getWorkRewards());
    }

    //Use this function to execute job work calls

    function executeCall(address target, uint value, string memory signature,bytes memory data) public upkeep {
        //Check that target is a job
        require(KP3R.jobs(target),"!job");
        //Call code,taken from compound's timelock contract code
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value:value}(callData);
        require(success,"exec fail");
    }


}