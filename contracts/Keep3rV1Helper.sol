// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import "./interfaces/IChainLinkFeed.sol";
import "./interfaces/IUniswapV2SlidingOracle.sol";
import "./interfaces/Keep3r/IKeep3rV1Mini.sol";

contract Keep3rV1HelperNewCustom is Ownable{
    using SafeMath for uint;

    IChainLinkFeed public FASTGAS = IChainLinkFeed(0x169E633A2D1E6c10dD91238Ba11c4A708dfEF37C);
    IKeep3rV1Mini public RLR;
    IUniswapV2SlidingOracle public UV2SO;
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    uint constant public MAX = 11;
    uint constant public BASE = 10;
    uint constant public SWAP = 300000;
    uint public TARGETBOND = 200e18;

    uint internal CurrentGas = 20 gwei;
    bool public useConstantGas = true;

    constructor (address rlrtoken,address oracle) public {
        RLR   = IKeep3rV1Mini(rlrtoken);
        UV2SO = IUniswapV2SlidingOracle(oracle);
    }

    function quote(uint eth) public view returns (uint) {
        return UV2SO.current(address(WBNB), eth, address(RLR));
    }

    function setOracle(address oracle) public onlyOwner {
        UV2SO = IUniswapV2SlidingOracle(oracle);
    }

    function setGasOracle(address oracle) external onlyOwner {
        FASTGAS = IChainLinkFeed(oracle);
    }

    function setGasPrice(uint newGas) external onlyOwner {
        CurrentGas = newGas;
    }

    function setTargetBond(uint newBond) external onlyOwner {
        TARGETBOND = newBond;
    }

    function setToken(address keepertoken) public onlyOwner{
        RLR = IKeep3rV1Mini(keepertoken);
    }

    function getFastGas() external view returns (uint) {
        if(!useConstantGas)
            return uint(FASTGAS.latestAnswer());
        else
            return CurrentGas;
    }

    function bonds(address keeper) public view returns (uint) {
        return RLR.bonds(keeper, address(RLR)).add(RLR.votes(keeper));
    }

    function getQuoteLimitFor(address origin, uint gasUsed) public view returns (uint) {
        uint _min = quote((gasUsed.add(SWAP)).mul(uint(FASTGAS.latestAnswer())));
        uint _boost = _min.mul(MAX).div(BASE);
        uint _bond = Math.min(bonds(origin), TARGETBOND);
        return Math.max(_min, _boost.mul(_bond).div(TARGETBOND));
    }

    function getQuoteLimit(uint gasUsed) external view returns (uint) {
        return getQuoteLimitFor(tx.origin, gasUsed);
    }
}
