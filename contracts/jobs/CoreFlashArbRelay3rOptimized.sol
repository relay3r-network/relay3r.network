// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
//Import OpenZepplin libs
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
//Import job interfaces and helper interfaces
import '../interfaces/Keep3r/IKeep3rV1Mini.sol';
import '../interfaces/ICoreFlashArb.sol';
import "../interfaces/IChi.sol";
//Import Uniswap interfaces
import '../interfaces/Uniswap/IUniswapV2Pair.sol';

contract CoreFlashArbRelayerV3 is Ownable{

    //Custom upkeep modifer with CHI support
    modifier upkeep() {
        uint256 gasStart = gasleft();
        require(RLR.isKeeper(msg.sender), "!relayer");
        _;
        uint256 gasSpent = 21000 + gasStart - gasleft() + 16 * msg.data.length;
        CHI.freeFromUpTo(address(this), (gasSpent + 14154) / 41947);
        //Payout RLR
        RLR.worked(msg.sender);
    }

    IKeep3rV1Mini public RLR;
    ICoreFlashArb public CoreArb;
    iCHI public CHI = iCHI(0x0000000000004946c0e9F43F4Dee607b0eF1fA1c);

    //Init interfaces with addresses
    constructor (address token,address corearb) public {
        RLR = IKeep3rV1Mini(token);
        CoreArb = ICoreFlashArb(corearb);
        //Approve chi for gas expense
        require(CHI.approve(address(this), uint256(-1)));
    }

    //Helper functions for handling sending of reward token
    function getTokenBalance(address tokenAddress) public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function sendERC20(address tokenAddress,address receiver) internal {
        IERC20(tokenAddress).transfer(receiver, getTokenBalance(tokenAddress));
    }

    //Required cause coreflasharb contract doesnt make this easily retrievable
    function getRewardToken(uint strat) public view returns (address) {
        ICoreFlashArb.Strategy memory stratx = CoreArb.strategyInfo(strat);//Get full strat data
        // Eg. Token 0 was out so profit token is token 1
        return stratx.token0Out[0] ? IUniswapV2Pair(stratx.pairs[0]).token1() : IUniswapV2Pair(stratx.pairs[0]).token0();
    }

    //Set new contract address incase core devs change the flash arb contract
    function setCoreArbAddress(address newContract) public onlyOwner {
        CoreArb = ICoreFlashArb(newContract);
    }

    function workable() public view returns (bool) {
        for(uint i=0;i<CoreArb.numberOfStrategies();i++){
            if(CoreArb.strategyProfitInReturnToken(i) > 0)
                return true;
        }
    }

    function profitableCount() public view returns (uint){
        uint count = 0;
        for(uint i=0;i<CoreArb.numberOfStrategies();i++){
            if(CoreArb.strategyProfitInReturnToken(i) > 0)
                count++;
        }
        return count;
    }

    //Return profitable strats array and reward tokens
    function profitableStratsWithTokens() public view returns (uint[] memory,address[] memory){
        uint profitableCountL = profitableCount();
        uint index = 0;

        uint[] memory _profitable = new uint[](profitableCountL);
        address[] memory _rewardToken = new address[](profitableCountL);

        for(uint i=0;i<CoreArb.numberOfStrategies();i++){
            if(CoreArb.strategyProfitInReturnToken(i) > 0){
                _profitable[index] = i;
                _rewardToken[index] = getRewardToken(i);
                index++;
            }

        }
        return (_profitable,_rewardToken);
    }

    function hasMostProfitableStrat() public view returns (bool) {
        (uint256 profit, ) = CoreArb.mostProfitableStrategyInETH();
        return profit > 0;
    }

    function getMostProfitableStrat() public view returns (uint){
        //Get data from interface on profit and strat id
        (, uint256 strategyID) = CoreArb.mostProfitableStrategyInETH();
        return strategyID;
    }

    function getMostProfitableStratWithToken() public view returns (uint,address){
        //Get data from interface on profit and strat id
        (, uint256 strategyID) = CoreArb.mostProfitableStrategyInETH();
        return (strategyID,getRewardToken(strategyID));
    }

    //Used to execute multiple profitable strategies,only use when there are multiple executable strats
    function workBatch(uint[] memory profitable,address[] memory rewardTokens) public upkeep{
        //No need to check for profitablility here as it wont execute if arb isnt profitable
        for(uint i=0;i<profitable.length;i++){
            CoreArb.executeStrategy(profitable[i]);
            //Send strat reward to executor
            sendERC20(rewardTokens[i],msg.sender);
        }
    }

    //Execute single profitable strat
    function work(uint strat,address rewardToken) public upkeep{
        //No need to check for profitablility here as it wont execute if arb isnt profitable
        CoreArb.executeStrategy(strat);
        //Send strat reward to executor
        sendERC20(rewardToken,msg.sender);
    }

    //Added to recover erc20 tokens
    function recoverERC20(address token) public onlyOwner {
        sendERC20(token,owner());
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
}