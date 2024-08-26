// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title Token
/// @notice A custom ERC20 token with minting and burning capabilities
/// @dev This token is used for wrapped representations of tokens across different chains
contract Token is ERC20, ERC20Burnable, Ownable {
    uint8 private _decimals;

    /// @notice Constructs the Token contract
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param decimals_ The number of decimals for the token
    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    /// @notice Returns the number of decimals used to get its user representation
    /// @return The number of decimals
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /// @notice Mints new tokens
    /// @param to The address that will receive the minted tokens
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burns tokens from a specific address
    /// @param from The address to burn tokens from
    /// @param amount The amount of tokens to burn
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /// @notice Returns the version of the token contract
    /// @return A string representing the version
    function version() public pure returns (string memory) {
        return "LaPoste Token v1";
    }
}
