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

import "./BondingCurve.sol";


contract LinearBondingCurve is BondingCurve {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    uint internal immutable K;
    uint internal immutable START_PRICE;

    constructor(IERC20 _token, uint k, uint startPrice) public BondingCurve(_token) {
        K = k;
        START_PRICE = startPrice;
    }

    function s(uint x0, uint x1) public view override returns (uint) {
        require(x1 > x0);
        return x1.add(x0).mul(x1.sub(x0))
            .div(2).div(K)
            .add(START_PRICE.mul(x1 - x0))
            .div(1e18);
    }
}