// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IComptroller {
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
    function closeFactorMantissa() external view returns (uint);
}