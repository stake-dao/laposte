// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import "@forge-std/mocks/MockERC20.sol";

import {FakeToken} from "test/mocks/FakeToken.sol";
import {AdapterMock} from "test/mocks/AdapterMock.sol";
import {ExecuteMock} from "test/mocks/ExecuteMock.sol";
import {AdapterFailMock} from "test/mocks/AdapterFailMock.sol";

import {Client} from "src/ccip/Client.sol";
import {TokenFactory} from "src/TokenFactory.sol";
import {IAdapter, ILaPoste, LaPoste} from "src/LaPoste.sol";

contract LaPosteTest is Test {
    LaPoste public laPoste;
    TokenFactory public tokenFactory;

    FakeToken public fakeToken;
    AdapterMock public adapter;
    ExecuteMock public executeMock;
    AdapterFailMock public adapterFailMock;

    address public owner = address(this);

    function setUp() public {
        tokenFactory = new TokenFactory(owner, 1);
        laPoste = new LaPoste(address(tokenFactory), owner);

        executeMock = new ExecuteMock();
        adapterFailMock = new AdapterFailMock();
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
        uint256 indexed chainId, uint256 indexed nonce, address indexed sender, address to, ILaPoste.Message message
    );

    function test_sendMessage() public {
        ILaPoste.MessageParams memory messageParams = ILaPoste.MessageParams({
            destinationChainId: 2,
            to: address(1),
            token: ILaPoste.Token({tokenAddress: address(fakeToken), amount: 50e18}),
            payload: "Hello, world!"
        });

        uint256 additionalGasLimit = 1_000_000;

        /// 1. Adapter not set
        laPoste.setAdapter(address(0));
        vm.expectRevert(LaPoste.NoAdapterSet.selector);
        laPoste.sendMessage(messageParams, additionalGasLimit, address(0));

        laPoste.setAdapter(address(adapter));

        /// 2. Send to same chain
        vm.chainId(messageParams.destinationChainId);
        vm.expectRevert(LaPoste.CannotSendToSelf.selector);
        laPoste.sendMessage(messageParams, additionalGasLimit, address(0));

        vm.chainId(1);

        /// 3. Send message with Token main chain.
        uint256 nonce = laPoste.sentNonces(messageParams.destinationChainId);
        assertEq(nonce, 0);

        ILaPoste.Message memory message = ILaPoste.Message({
            destinationChainId: messageParams.destinationChainId,
            to: messageParams.to,
            sender: address(owner),
            token: messageParams.token,
            tokenMetadata: ILaPoste.TokenMetadata({name: "Fake Token", symbol: "FAKE", decimals: 18}),
            payload: messageParams.payload,
            nonce: 1
        });

        fakeToken.approve(address(tokenFactory), 100e18);

        vm.expectEmit(true, true, true, true);
        emit MessageSent(messageParams.destinationChainId, 1, message.sender, message.to, message);

        laPoste.sendMessage(messageParams, additionalGasLimit, address(0));

        nonce = laPoste.sentNonces(messageParams.destinationChainId);
        assertEq(nonce, 1);

        assertEq(fakeToken.balanceOf(address(owner)), 50e18);
        assertEq(fakeToken.balanceOf(address(tokenFactory)), 50e18);

        /// 4. Send message without Token main chain.
        messageParams.token = ILaPoste.Token({tokenAddress: address(0), amount: 0});
        message.token = messageParams.token;
        message.tokenMetadata = ILaPoste.TokenMetadata({name: "", symbol: "", decimals: 0});
        message.nonce = 2;

        vm.expectEmit(true, true, true, true);
        emit MessageSent(messageParams.destinationChainId, 2, message.sender, message.to, message);

        laPoste.sendMessage(messageParams, additionalGasLimit, address(0));

        nonce = laPoste.sentNonces(messageParams.destinationChainId);
        assertEq(nonce, 2);

        assertEq(fakeToken.balanceOf(address(owner)), 50e18);
        assertEq(fakeToken.balanceOf(address(tokenFactory)), 50e18);

        /// 5. Send message with token from not main chain.
        vm.chainId(2);
        messageParams.destinationChainId = 1;
        messageParams.token = ILaPoste.Token({tokenAddress: address(fakeToken), amount: 50e18});

        vm.expectRevert(TokenFactory.WrappedTokenDoesNotExist.selector);
        laPoste.sendMessage(messageParams, additionalGasLimit, address(0));

        vm.chainId(1);

        /// 6. Adapter fails
        messageParams.destinationChainId = 2;

        laPoste.setAdapter(address(adapterFailMock));
        vm.expectRevert(LaPoste.ExecutionFailed.selector);
        laPoste.sendMessage(messageParams, additionalGasLimit, address(0));
    }

    event HelloWorld(uint256 param);
    event MessageReceived(
        uint256 indexed chainId,
        uint256 indexed nonce,
        address indexed sender,
        address to,
        ILaPoste.Message message,
        bool success
    );

    function test_receiveMessage() public {
        uint256 sourceChainId = 1;

        ILaPoste.Message memory message = ILaPoste.Message({
            destinationChainId: 2,
            to: address(1),
            sender: address(owner),
            token: ILaPoste.Token({tokenAddress: address(0), amount: 0}),
            tokenMetadata: ILaPoste.TokenMetadata({name: "", symbol: "", decimals: 0}),
            payload: "",
            nonce: 1
        });

        vm.chainId(message.destinationChainId);

        bool received = laPoste.receivedNonces(sourceChainId, message.nonce);
        assertFalse(received);

        adapter.ccipReceive(sourceChainId, message);

        received = laPoste.receivedNonces(sourceChainId, message.nonce);
        assertTrue(received);

        /// 1. Message already processed
        vm.expectRevert(LaPoste.MessageAlreadyProcessed.selector);
        adapter.ccipReceive(sourceChainId, message);

        /// 2. Message with token from main chain.
        /// It should create and mint a wrapped token.
        message.token = ILaPoste.Token({tokenAddress: address(fakeToken), amount: 50e18});
        message.tokenMetadata = ILaPoste.TokenMetadata({name: "Fake Token", symbol: "FAKE", decimals: 18});
        message.nonce = 2;

        adapter.ccipReceive(sourceChainId, message);

        received = laPoste.receivedNonces(sourceChainId, message.nonce);
        assertTrue(received);

        address wrapped = tokenFactory.wrappedTokens(address(fakeToken));
        assertEq(IERC20(wrapped).balanceOf(address(1)), 50e18);

        /// 3. Message with token from side chain.
        /// It should try to transfer.
        vm.chainId(sourceChainId);
        message.nonce = 3;

        vm.expectRevert("ERC20: subtraction underflow");
        adapter.ccipReceive(sourceChainId, message);

        vm.chainId(message.destinationChainId);

        /// 4. Message with Token and Payload
        message.token = ILaPoste.Token({tokenAddress: address(fakeToken), amount: 50e18});
        message.to = address(executeMock);
        message.payload = abi.encode(address(owner), address(wrapped));
        message.nonce = 4;

        adapter.ccipReceive(sourceChainId, message);

        received = laPoste.receivedNonces(sourceChainId, message.nonce);
        assertTrue(received);

        assertEq(IERC20(wrapped).balanceOf(address(1)), 50e18);
        assertEq(IERC20(wrapped).balanceOf(address(owner)), 50e18);

        /// 5. Message with Payload only.
        message.token = ILaPoste.Token({tokenAddress: address(0), amount: 0});
        message.to = address(executeMock);
        message.payload = abi.encode(address(owner), address(wrapped));
        message.nonce = 5;

        vm.expectEmit(true, true, true, true);
        emit HelloWorld(sourceChainId);

        vm.expectEmit(true, true, true, true);
        emit MessageReceived(sourceChainId, message.nonce, message.sender, message.to, message, true);

        adapter.ccipReceive(sourceChainId, message);

        uint256 totalSupply = IERC20(wrapped).totalSupply();
        assertEq(totalSupply, 100e18);

        /// 6. Payload to TokenFactory
        message.to = address(tokenFactory);
        message.payload =
            abi.encodeWithSelector(TokenFactory.mint.selector, address(executeMock), 100e18, "Fake Token", "FAKE", 18);
        message.nonce = 6;

        adapter.ccipReceive(sourceChainId, message);

        /// Supply should not change.
        totalSupply = IERC20(wrapped).totalSupply();
        assertEq(totalSupply, 100e18);
    }

    receive() external payable {}
}
