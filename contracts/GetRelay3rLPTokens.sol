// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import '@openzeppelin/contracts/math/SafeMath.sol';

import './libraries/TokenHelper.sol';
import './libraries/UniswapV2Library.sol';

import './interfaces/Uniswap/IUniswapV2Router.sol';
import './interfaces/Uniswap/IWETH.sol';

contract GetRelay3rLPTokens{
    using SafeMath for uint256;
    //define constants
    bool hasApproved = false;
    address owner = msg.sender;
    uint constant public INF = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    address self = address(this);

    address public  UniswapRouter;
    IERC20 public Relay3rInterface;
    IUniswapV2Router uniswapInterface;
    IERC20 public pairInterface;
    IWETH wethInterface;
    constructor(address UniRouter,address KeeperToken) public{
        UniswapRouter = UniRouter;
        Relay3rInterface = IERC20(KeeperToken);
        uniswapInterface = IUniswapV2Router(UniswapRouter);
        pairInterface = IERC20(UniswapV2Library.pairFor(uniswapInterface.factory(),address(Relay3rInterface),uniswapInterface.WETH()));
        wethInterface = IWETH(uniswapInterface.WETH());
    }


     function getPathForETHToToken() private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = uniswapInterface.WETH();
        path[1] = address(Relay3rInterface);
        return path;
    }

    function doInfiniteApprove(IERC20 token) internal{
        token.approve(UniswapRouter, INF);
    }

    function DoApprove() internal {
        doInfiniteApprove(Relay3rInterface);
        doInfiniteApprove(pairInterface);
        doInfiniteApprove(wethInterface);
    }

    function GetRelay3rBalance() public view returns (uint256){
       return tokenHelper.getTokenBalance(address(Relay3rInterface));
    }

    function getWETHBalance() public view returns (uint256){
        return tokenHelper.getTokenBalance(uniswapInterface.WETH());
    }

    receive() external payable {
        if(msg.sender != UniswapRouter || msg.sender != address(wethInterface))
            deposit();
    }

    function deposit() public payable{
        if(!hasApproved){
            DoApprove();
        }
        //Convert ETH to WETH
        wethInterface.deposit{value:msg.value}();
        convertWETHToRL3R();
        addLiq(msg.sender);
        //Send back the eth dust given from refund
        if(getWETHBalance() > 0){
            wethInterface.withdraw(getWETHBalance());
            (bool success,  ) = msg.sender.call{value : address(this).balance}("");
            require(success,"Refund failed");
        }
    }

    function convertWETHToRL3R() internal {
        uniswapInterface.swapExactTokensForTokens(getWETHBalance().div(2),UniswapV2Library.getAmountsOut(uniswapInterface.factory(), getWETHBalance().div(2),getPathForETHToToken())[1], getPathForETHToToken(),self,INF);
    }

    function addLiq(address dest) internal {
        //finally add liquidity
        uniswapInterface.addLiquidity(uniswapInterface.WETH(),address(Relay3rInterface),getWETHBalance(),GetRelay3rBalance(),1,1,dest,INF);
    }

    function withdrawFunds() public {
        tokenHelper.recoverERC20(uniswapInterface.WETH(),owner);
        tokenHelper.recoverERC20((address(Relay3rInterface)),owner);
    }
}
