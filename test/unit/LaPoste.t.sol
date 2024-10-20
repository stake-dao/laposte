// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import "@forge-std/mocks/MockERC20.sol";
import {FakeToken} from "test/mocks/FakeToken.sol";

import {Client} from "src/ccip/Client.sol";
import {TokenFactory} from "src/TokenFactory.sol";
import {IAdapter, LaPoste} from "src/LaPoste.sol";


contract AdapterMock {
    address public laPoste;

    constructor(address _laPoste) {
        laPoste = _laPoste;
    }

    function sendMessage(address, uint256, uint256, bytes calldata) external payable returns (bytes32) {
        return bytes32("Success");
    }

    function ccipReceive(uint256 chainId, bytes calldata message) external {
        IAdapter(laPoste).receiveMessage({chainId: chainId, payload: message});
    }
}

contract LaPosteTest is Test {
    LaPoste public laPoste;
    FakeToken public fakeToken;
    AdapterMock public adapter;
    TokenFactory public tokenFactory;

    address public owner = address(this);

    function setUp() public {
        tokenFactory = new TokenFactory(owner, 1);
        laPoste = new LaPoste(address(tokenFactory), owner);

        adapter = new AdapterMock(address(laPoste));
        fakeToken = new FakeToken("Fake Token", "FAKE", 18);

        laPoste.setAdapter(address(adapter));
        tokenFactory.setMinter(address(laPoste));

        fakeToken.mint(owner, 100e18);
    }

    function test_setup() public view {
        assertEq(laPoste.owner(), owner);
        assertEq(laPoste.tokenFactory(), address(tokenFactory));
        assertEq(laPoste.adapter(), address(adapter));

        assertEq(tokenFactory.owner(), address(0));
        assertEq(tokenFactory.minter(), address(laPoste));
        assertEq(tokenFactory.CHAIN_ID(), 1);
    }

    event MessageSent(
        uint256 indexed chainId, uint256 indexed nonce, address indexed sender, address to, IAdapter.Message message
    );

    function test_sendMessage() public {
        IAdapter.MessageParams memory messageParams = IAdapter.MessageParams({
            destinationChainId: 2,
            to: address(1),
            token: IAdapter.Token({tokenAddress: address(fakeToken), amount: 50e18}),
            payload: "Hello, world!"
        });

        uint256 additionalGasLimit = 1_000_000;

        /// 1. Adapter not set
        laPoste.setAdapter(address(0));
        vm.expectRevert(LaPoste.NoAdapterSet.selector);
        laPoste.sendMessage(messageParams, additionalGasLimit);

        laPoste.setAdapter(address(adapter));

        /// 2. Send to same chain
        vm.chainId(messageParams.destinationChainId);
        vm.expectRevert(LaPoste.CannotSendToSelf.selector);
        laPoste.sendMessage(messageParams, additionalGasLimit);

        vm.chainId(1);

        /// 3. Send message with Token main chain.
        uint256 nonce = laPoste.sentNonces(messageParams.destinationChainId);
        assertEq(nonce, 0);

        IAdapter.Message memory message = IAdapter.Message({
            destinationChainId: messageParams.destinationChainId,
            to: messageParams.to,
            sender: address(owner),
            token: messageParams.token,
            tokenMetadata: IAdapter.TokenMetadata({name: "Fake Token", symbol: "FAKE", decimals: 18}),
            payload: messageParams.payload,
            nonce: 1
        });

        fakeToken.approve(address(tokenFactory), 50e18);

        vm.expectEmit(true, true, true, true);
        emit MessageSent(messageParams.destinationChainId, 1, message.sender, message.to, message);

        laPoste.sendMessage(messageParams, additionalGasLimit);

        nonce = laPoste.sentNonces(messageParams.destinationChainId);
        assertEq(nonce, 1);

        assertEq(fakeToken.balanceOf(address(owner)), 50e18);
        assertEq(fakeToken.balanceOf(address(tokenFactory)), 50e18);

        /// 4. Send message without Token main chain.
        messageParams.token = IAdapter.Token({tokenAddress: address(0), amount: 0});
        message.token = messageParams.token;
        message.tokenMetadata = IAdapter.TokenMetadata({name: "", symbol: "", decimals: 0});
        message.nonce = 2;

        vm.expectEmit(true, true, true, true);
        emit MessageSent(messageParams.destinationChainId, 2, message.sender, message.to, message);

        laPoste.sendMessage(messageParams, additionalGasLimit);

        nonce = laPoste.sentNonces(messageParams.destinationChainId);
        assertEq(nonce, 2);

        assertEq(fakeToken.balanceOf(address(owner)), 50e18);
        assertEq(fakeToken.balanceOf(address(tokenFactory)), 50e18);

        /// 5. Send message with token from not main chain.
        vm.chainId(2);
        messageParams.destinationChainId = 1;
        messageParams.token = IAdapter.Token({tokenAddress: address(fakeToken), amount: 50e18});

        vm.expectRevert(TokenFactory.WrappedTokenDoesNotExist.selector);
        laPoste.sendMessage(messageParams, additionalGasLimit);

        vm.chainId(1);
    }
}
