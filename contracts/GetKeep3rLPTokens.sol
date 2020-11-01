// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import './libraries/TokenHelper.sol';
import './libraries/UniswapV2Library.sol';

import './interfaces/Uniswap/IUniswapV2Router.sol';
import './interfaces/Uniswap/IWETH.sol';

contract GetKeep3rLPTokens{
    //define constants
    bool hasApproved = false;
    address owner = msg.sender;
    uint constant public INF = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    address self = address(this);

    address public  UniswapRouter = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    IUniswapV2Router uniswapInterface = IUniswapV2Router(UniswapRouter);
    IERC20 public KeeperInterface = IERC20(0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44);
    IERC20 public pairInterface = IERC20(UniswapV2Library.pairFor(uniswapInterface.factory(),address(KeeperInterface),uniswapInterface.WETH()));
    IWETH wethInterface = IWETH(uniswapInterface.WETH());

     function getPathForETHToToken() private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = uniswapInterface.WETH();
        path[1] = address(KeeperInterface);
        return path;
    }

    function doInfiniteApprove(IERC20 token) internal{
        token.approve(UniswapRouter, INF);
    }

    function DoApprove() internal {
        doInfiniteApprove(KeeperInterface);
        doInfiniteApprove(pairInterface);
        doInfiniteApprove(wethInterface);
    }

    function getKeeperBalance() public view returns (uint256){
       return tokenHelper.getTokenBalance(address(KeeperInterface));
    }

    function getWETHBalance() public view returns (uint256){
        return tokenHelper.getTokenBalance(uniswapInterface.WETH());
    }

    receive() external payable {
        if(msg.sender != UniswapRouter)
            deposit();
    }

    function deposit() public payable{
        if(!hasApproved){
            DoApprove();
        }
        //Convert ETH to WETH
        wethInterface.deposit{value:msg.value}();
        convertWETHToKP3R();
        addLiq(msg.sender);
        //Send back the eth dust given from refund
        if(getWETHBalance() > 0){
            wethInterface.withdraw(getWETHBalance());
            (bool success,  ) = msg.sender.call{value : address(this).balance}("");
            require(success,"Refund failed");
        }
    }

    function convertWETHToKP3R() internal {
        uniswapInterface.swapExactTokensForTokensSupportingFeeOnTransferTokens(getWETHBalance() / 2,1,getPathForETHToToken(),self,INF);
    }

    function addLiq(address dest) internal {
        //finally add liquidity
        uniswapInterface.addLiquidity(address(KeeperInterface),uniswapInterface.WETH(),getKeeperBalance(),getWETHBalance(),1,1,dest,INF);
    }

    function withdrawFunds() public {
        tokenHelper.recoverERC20(uniswapInterface.WETH(),owner);
        tokenHelper.recoverERC20((address(KeeperInterface)),owner);
    }
}
