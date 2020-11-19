pragma solidity 0.6.12;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2020 Hegic Protocol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */



import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


abstract
contract BondingCurve {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint public soldAmount;
    address payable public relayerDevFund;

    event Bought(address indexed account, uint amount, uint ethAmount);
    event Sold(address indexed account, uint amount, uint ethAmount, uint comission);

    constructor(IERC20 _token) public {
        token = _token;
        relayerDevFund = msg.sender;
    }

    function buy(uint tokenAmount) external payable {
        uint nextSold = soldAmount.add(tokenAmount);
        uint ethAmount = s(soldAmount, nextSold);
        soldAmount = nextSold;
        require(msg.value >= ethAmount, "Value is too small");
        token.safeTransfer(msg.sender, tokenAmount);
        if (msg.value > ethAmount)
            msg.sender.transfer(msg.value - ethAmount);
        emit Bought(msg.sender, tokenAmount, ethAmount);
    }

    function sell(uint tokenAmount) external {
        uint nextSold = soldAmount.sub(tokenAmount);
        uint ethAmount = s(nextSold, soldAmount);
        uint comission = ethAmount / 10;
        uint refund = ethAmount.sub(comission);
        require(comission > 0);

        soldAmount = nextSold;
        token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        relayerDevFund.transfer(comission);
        msg.sender.transfer(refund);
        emit Sold(msg.sender, tokenAmount, refund, comission);
    }

    function s(uint x0, uint x1) public view virtual returns (uint);
}