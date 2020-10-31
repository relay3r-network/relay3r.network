//SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
interface IKeep3rV1Mini {
    function isKeeper(address) external returns (bool);
    function worked(address keeper) external;
}