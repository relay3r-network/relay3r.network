// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract BurnableToken is ERC20,ERC20Burnable,Ownable {
    constructor (string memory name, string memory symbol) ERC20(name,symbol) public {
        //Mint initial supply for owner
        _mint(msg.sender,1000 * 10**18);
    }

    /**
     * @notice Allows owner to mint new tokens
     * @param amount the amount of tokens to mint
     */
    function mint(uint amount) public onlyOwner{
        _mint(owner(), amount);
    }

}