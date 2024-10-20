// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExecuteMock {
    function helloWorld(address to, address token) external {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(to, balance);
    }

    event HelloWorld(uint256 param);

    function helloWorld2(uint256 param) external {
        emit HelloWorld(param);
    }
}
