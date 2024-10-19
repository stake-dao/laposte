// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import "@forge-std/mocks/MockERC20.sol";

import {Token, TokenFactory} from "src/TokenFactory.sol";

contract FakeToken is MockERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) {
        initialize(name, symbol, decimals);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}

contract TokenFactoryTest is Test {
    FakeToken public fakeToken;
    TokenFactory public tokenFactory;

    address public owner = address(this);
    uint256 public mainChainId = 1;

    function setUp() public {
        tokenFactory = new TokenFactory({owner: owner, mainChainId: mainChainId});
        fakeToken = new FakeToken("Fake Token", "FAKE", 18);

        vm.chainId(mainChainId);

        tokenFactory.setMinter(owner);
    }

    function test_setup() public view {
        assertEq(tokenFactory.owner(), address(0));
        assertEq(tokenFactory.minter(), address(this));
        assertEq(tokenFactory.CHAIN_ID(), mainChainId);
        assertEq(block.chainid, mainChainId);
    }

    function test_mintMainChain() public {
        address nativeToken = address(fakeToken);
        address to = address(0x2);
        uint256 amount = 100e18;

        address random = address(0x3);
        vm.prank(random);
        vm.expectRevert(TokenFactory.NotMinter.selector);
        tokenFactory.mint({
            nativeToken: nativeToken,
            to: to,
            amount: amount,
            name: "Fake Token",
            symbol: "FAKE",
            decimals: 18
        });

        vm.expectRevert("ERC20: subtraction underflow");
        tokenFactory.mint({
            nativeToken: nativeToken,
            to: to,
            amount: amount,
            name: "Fake Token",
            symbol: "FAKE",
            decimals: 18
        });

        fakeToken.mint(address(tokenFactory), amount);

        tokenFactory.mint({
            nativeToken: nativeToken,
            to: to,
            amount: amount,
            name: "Fake Token",
            symbol: "FAKE",
            decimals: 18
        });

        assertEq(fakeToken.balanceOf(owner), 0);
        assertEq(fakeToken.balanceOf(to), amount);
        assertEq(fakeToken.balanceOf(address(tokenFactory)), 0);
    }

    function test_mintSideChain() public {
        vm.chainId(2);

        address nativeToken = address(fakeToken);
        address to = address(0x2);
        uint256 amount = 100e18;

        tokenFactory.mint({
            nativeToken: nativeToken,
            to: to,
            amount: amount,
            name: "Fake Token",
            symbol: "FAKE",
            decimals: 18
        });

        assertEq(fakeToken.balanceOf(owner), 0);
        assertEq(fakeToken.balanceOf(to), 0);
        assertEq(fakeToken.balanceOf(address(tokenFactory)), 0);

        address wrappedToken = tokenFactory.wrappedTokens(nativeToken);
        assertNotEq(wrappedToken, address(0));

        assertEq(IERC20(wrappedToken).balanceOf(to), amount);
        assertEq(IERC20(wrappedToken).balanceOf(address(tokenFactory)), 0);
        assertEq(IERC20(wrappedToken).totalSupply(), amount);

        assertEq(IERC20(wrappedToken).name(), fakeToken.name());
        assertEq(IERC20(wrappedToken).symbol(), fakeToken.symbol());
        assertEq(IERC20(wrappedToken).decimals(), fakeToken.decimals());

        assertEq(tokenFactory.isWrapped(wrappedToken), true);
        assertEq(tokenFactory.isWrapped(nativeToken), false);

        assertEq(tokenFactory.wrappedTokens(nativeToken), wrappedToken);
        assertEq(tokenFactory.nativeTokens(wrappedToken), nativeToken);
    }

    function test_burnMainChain() public {
        address nativeToken = address(fakeToken);
        uint256 amount = 100e18;

        address random = address(0x3);
        vm.prank(random);
        vm.expectRevert(TokenFactory.NotMinter.selector);
        tokenFactory.burn(nativeToken, random, amount);

        vm.expectRevert("ERC20: subtraction underflow");
        tokenFactory.burn(nativeToken, owner, amount);

        fakeToken.mint(owner, amount);
        fakeToken.approve(address(tokenFactory), amount);

        tokenFactory.burn(nativeToken, owner, amount);
        assertEq(fakeToken.balanceOf(owner), 0);
        assertEq(fakeToken.balanceOf(address(tokenFactory)), amount);

        assertEq(tokenFactory.isWrapped(nativeToken), false);
        assertEq(tokenFactory.wrappedTokens(nativeToken), address(0));
    }

    function test_burnSideChain() public {
        vm.chainId(2);

        address nativeToken = address(fakeToken);
        uint256 amount = 100e18;

        vm.expectRevert(TokenFactory.WrappedTokenDoesNotExist.selector);
        tokenFactory.burn(nativeToken, owner, amount);

        tokenFactory.mint(nativeToken, owner, amount, "Fake Token", "FAKE", 18);

        address wrappedToken = tokenFactory.wrappedTokens(nativeToken);
        assertEq(IERC20(wrappedToken).balanceOf(owner), amount);
        assertEq(IERC20(wrappedToken).balanceOf(address(tokenFactory)), 0);
        assertEq(IERC20(wrappedToken).totalSupply(), amount);

        tokenFactory.burn(nativeToken, owner, amount);
        assertEq(IERC20(wrappedToken).balanceOf(owner), 0);
        assertEq(IERC20(wrappedToken).balanceOf(address(tokenFactory)), 0);
        assertEq(IERC20(wrappedToken).totalSupply(), 0);
    }
}
