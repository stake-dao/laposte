// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "src/Token.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title TokenFactory
/// @notice A factory contract for creating and managing wrapped tokens across different chains
/// @dev This contract handles minting, burning, and tracking of wrapped tokens
contract TokenFactory is Ownable {
    using SafeERC20 for IERC20;

    /// @notice The address of the minter
    address public minter;

    /// @notice Whether the token is wrapped.
    mapping(address => bool) public isWrapped;

    /// @notice Does the token exist on this chain.
    mapping(address => bool) public isChainNative;

    /// @notice Mapping of native tokens to their wrapped versions.
    mapping(address => address) public wrappedTokens;

    /// @notice Mapping of wrapped tokens to their native versions.
    mapping(address => address) public nativeTokens;

    /// @notice Thrown when the caller is not the minter
    error NotMinter();
    /// @notice Thrown when the minter is already set.
    error MinterAlreadySet();
    /// @notice Thrown when a wrapped token does not exist
    error WrappedTokenDoesNotExist();

    /// @notice Ensures that only the minter can call the function
    modifier onlyMinter() {
        if (msg.sender != minter) revert NotMinter();
        _;
    }

    constructor(address owner) {
        _transferOwnership(owner);
    }

    /// @notice Mints or locks tokens
    /// @param nativeToken Address of the token (whether on Chain A or Chain B)
    /// @param to Address to receive tokens
    /// @param amount Amount of tokens to mint or lock
    /// @param name Name of the original token
    /// @param symbol Symbol of the original token
    /// @param decimals Decimals of the original token
    function mint(
        address nativeToken,
        address to,
        uint256 amount,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) external onlyMinter {
        if (isChainNative[nativeToken]) {
            // The token exists on this chain, lock it
            IERC20(nativeToken).safeTransfer(to, amount);
        } else {
            // Token doesn't exist on this chain, mint wrapped token
            address wrappedToken = getOrCreateWrappedToken(nativeToken, name, symbol, decimals);
            Token(wrappedToken).mint(to, amount);
        }
    }

    /// @notice Burns or unlocks tokens
    /// @param nativeToken Address of the token (whether on Chain A or Chain B)
    /// @param from Address from which tokens are burned/unlocked
    /// @param amount Amount of tokens to burn or unlock
    function burn(address nativeToken, address from, uint256 amount) external onlyMinter {
        address wrappedToken = wrappedTokens[nativeToken];
        if (wrappedToken == address(0) && !isWrapped[nativeToken]) {
            // The token exists on this chain, unlock it
            IERC20(nativeToken).safeTransferFrom(from, address(this), amount);

            // Update original token.
            if (!isChainNative[nativeToken]) isChainNative[nativeToken] = true;
        } else {
            // Token is wrapped, burn it
            if (wrappedToken == address(0)) revert WrappedTokenDoesNotExist();
            Token(wrappedToken).burn(from, amount);
        }
    }

    /// @notice Creates or retrieves an existing wrapped token on the target chain
    /// @param nativeToken The address of the original token on the other chain
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param decimals The number of decimals for the token
    /// @return wrappedToken The address of the wrapped token
    function getOrCreateWrappedToken(address nativeToken, string memory name, string memory symbol, uint8 decimals)
        internal
        returns (address wrappedToken)
    {
        wrappedToken = wrappedTokens[nativeToken];
        if (wrappedToken == address(0)) {
            bytes32 salt = keccak256(abi.encodePacked(nativeToken, name, symbol, decimals));
            wrappedToken = address(new Token{salt: salt}(name, symbol, decimals));

            wrappedTokens[nativeToken] = wrappedToken;
            nativeTokens[wrappedToken] = nativeToken;

            isWrapped[wrappedToken] = true;
        }
        return wrappedToken;
    }

    /// @notice Retrieves the metadata of a token
    /// @param token The address of the token
    /// @return name The name of the token
    /// @return symbol The symbol of the token
    /// @return decimals The number of decimals for the token
    function getTokenMetadata(address token)
        external
        view
        returns (string memory name, string memory symbol, uint8 decimals)
    {
        token = isChainNative[token] ? token : wrappedTokens[token];
        return (IERC20Metadata(token).name(), IERC20Metadata(token).symbol(), IERC20Metadata(token).decimals());
    }

    /// @notice One time function to set the minter.
    function setMinter(address newMinter) external onlyOwner {
        if (minter != address(0)) revert MinterAlreadySet();

        minter = newMinter;

        /// Renounce ownership.
        _transferOwnership(address(0));
    }
}
