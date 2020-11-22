// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

contract BurnableToken is ERC20,ERC20Burnable {
    constructor (string memory name, string memory symbol) ERC20(name,symbol) public {
        //Mint initial supply for owner
        _mint(msg.sender,1000 * 10**18);
    }
}