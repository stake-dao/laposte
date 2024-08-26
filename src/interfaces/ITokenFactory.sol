// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface ITokenFactory {
    function mint(
        address mainToken,
        address to,
        uint256 amount,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) external;
    function burn(address mainToken, address from, uint256 amount) external;
    function getTokenMetadata(address token)
        external
        view
        returns (string memory name, string memory symbol, uint8 decimals);
}
