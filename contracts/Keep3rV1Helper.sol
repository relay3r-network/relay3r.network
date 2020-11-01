// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/Math.sol';

import "./interfaces/IChainLinkFeed.sol";
import "./interfaces/Keep3r/IKeep3rV1Mini.sol";

contract Keep3rV1Helper {
    using SafeMath for uint;

    IChainLinkFeed public constant FASTGAS = IChainLinkFeed(0x169E633A2D1E6c10dD91238Ba11c4A708dfEF37C);
    IKeep3rV1Mini public constant KP3R = IKeep3rV1Mini(0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44);

    uint constant public BOOST = 25;
    uint constant public BASE = 10;
    uint constant public TARGETBOND = 100e18;

    function getFastGas() external view returns (uint) {
        return uint(FASTGAS.latestAnswer());
    }

    function bonds(address keeper) public view returns (uint) {
        return KP3R.bonds(keeper, address(KP3R)).add(KP3R.votes(keeper));
    }

    function getQuoteLimitFor(address origin, uint gasUsed) public view returns (uint) {
        uint _min = gasUsed.mul(uint(FASTGAS.latestAnswer()));
        uint _boost = _min.mul(BOOST).div(BASE); // increase by 2.5
        uint _bond = Math.min(bonds(origin), TARGETBOND);
        return Math.max(_min, _boost.mul(_bond).div(TARGETBOND));
    }

    function getQuoteLimit(uint gasUsed) external view returns (uint) {
        return getQuoteLimitFor(tx.origin, gasUsed);
    }
}
