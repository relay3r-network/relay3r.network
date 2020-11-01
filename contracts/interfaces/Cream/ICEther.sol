// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface ICEther {
    function liquidateBorrow(address borrower, address cTokenCollateral) external payable;
    function borrowBalanceStored(address account) external view returns (uint);
}