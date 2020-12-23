// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import "../interfaces/IChainLinkFeed.sol";
import "../interfaces/Keep3r/IKeep3rV1Mini.sol";

contract Keep3rV1HelperMock is Ownable{
    using SafeMath for uint;

    IKeep3rV1Mini public KP3R;

    uint constant public BOOST = 50;
    uint constant public BASE = 10;
    uint constant public TARGETBOND = 200e18;

    uint constant public PRICE = 10;

    function setToken(address keepertoken) public onlyOwner{
        KP3R = IKeep3rV1Mini(keepertoken);
    }

    //Return 20 gwei as fast
    function getFastGas() public view returns (uint) {
        return 20e9;
    }

    function bonds(address keeper) public view returns (uint) {
        return KP3R.bonds(keeper, address(KP3R)).add(KP3R.votes(keeper));
    }

    function getQuoteLimitFor(address origin, uint gasUsed) public view returns (uint) {
        uint _min = gasUsed.mul(PRICE).mul(getFastGas());
        uint _boost = _min.mul(BOOST).div(BASE); // increase by 2.5
        uint _bond = Math.min(bonds(origin), TARGETBOND);
        return Math.max(_min, _boost.mul(_bond).div(TARGETBOND));
    }

    function getQuoteLimit(uint gasUsed) external view returns (uint) {
        return getQuoteLimitFor(tx.origin, gasUsed);
    }
}