//SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
interface IKeep3rV1 {
    function isKeeper(address) external returns (bool);
    function worked(address keeper) external;
    function totalBonded() external view returns (uint);
    function getPriorVotes(address account, uint blockNumber) external view returns (uint);
    function addVotes(address voter, uint amount) external;
    function removeVotes(address voter,uint amount)  external;
    function addKPRCredit(address job, uint amount) external;
    function approveLiquidity(address liquidity) external;
    function revokeLiquidity(address liquidity) external;
    function addJob(address job) external;
    function removeJob(address job) external;
    function setKeep3rHelper(address _kprh) external;
    function setGovernance(address _governance) external;
    function acceptGovernance() external;
    function dispute(address keeper) external;
    function slash(address bonded, address keeper, uint amount) external;
    function revoke(address keeper) external;
    function resolve(address keeper) external;
}