// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {Client} from "src/ccip/Client.sol";

interface IAny2EVMMessageReceiver {
    function ccipReceive(Client.Any2EVMMessage calldata message) external;
}
