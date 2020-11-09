// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IKeep3rRights {
    function bondings ( address, address ) external view returns ( uint256 );
    function blacklist ( address ) external view returns ( bool );
    function BOND (  ) external view returns ( uint256 );
    function keepers ( address ) external view returns ( bool );
}