```
##########################################################################################
##########################################################################################
##########################################################################################
##########################################################################################
##########################################################################################
##########################################################################################
##########################################################################################
#############################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓############################
###############################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓##########################
###################################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓###########################
########################################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓############################
##########################################################################################
########################################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓###############
#####################################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓###################
##################################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓###########################
##############################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓##################################
###########################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓#########################################
########################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓########▓▓▓▓▓####################################
#####################▓▓▓▓▓▓▓▓▓▓▓▓▓#######▓▓▓▓▓▓▓▓▓▓▓▓#####################################
##################▓▓▓▓▓▓▓▓########▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓######################################
###############▓▓▓▓#########▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓#########################################
##########################################################################################
##########################################################################################
##########################################################################################
################▓▓#######▓▓▓######▓▓▓▓▓▓▓##▓▓▓▓▓▓▓##▓▓▓#▓▓#▓▓▓▓▓▓▓#▓▓▓▓▓▓#################
################▓▓######▓▓#▓▓#####▓▓##▓▓▓#▓▓#####▓▓#▓▓▓▓▓▓####▓▓###▓▓▓▓▓▓#################
################▓▓#####▓▓▓▓▓▓▓####▓▓▓▓####▓▓▓###▓▓▓#▓###▓▓▓###▓▓###▓▓#####################
#################▓▓▓▓##▓######▓####▓########▓▓▓▓#####▓▓▓▓#####▓#####▓▓▓▓▓▓################
##########################################################################################
##########################################################################################
##########################################################################################
##########################################################################################
##########################################################################################
##########################################################################################
```

LaPoste is an utility contract designed to simplify cross-chain use, providing a single entry point for cross-chain communication and token transfers from mainnet to other chains. It leverages CCIP to send and receive messages and tokens across chains.

## Key Components

1. **LaPoste**: The main contract that serves as the entry point for sending and receiving cross-chain messages and tokens.

2. **TokenFactory**: Manages the creation, minting, and burning of wrapped tokens across different chains.

3. **Adapter**: Implements the specific logic for interacting with the underlying cross-chain communication protocol (e.g., Chainlink's CCIP).

4. **Token**: A standard ERC20 token contract used for creating wrapped versions of tokens on different chains.

## How It Works

1. **Sending Messages and Tokens**:
   - Users interact with the LaPoste contract to send messages and tokens across chains.
   - If tokens are involved, the TokenFactory handles the locking or burning of tokens on the source chain.
   - The Adapter is used to send the message through the underlying cross-chain protocol.

2. **Receiving Messages and Tokens**:
   - The Adapter receives messages from the underlying protocol and forwards them to LaPoste.
   - LaPoste processes the message, minting or unlocking tokens if necessary using the TokenFactory.
   - If the message contains a payload, it's forwarded to the intended receiver contract.

3. **Token Wrapping**:
   - When tokens are transferred across chains, the TokenFactory creates wrapped versions of the tokens on the destination chain if they don't already exist.
   - This allows for seamless token transfers between different blockchain networks.

## Features

- Send and receive cross-chain messages
- Transfer tokens between different blockchain networks
- Automatic creation of wrapped tokens on destination chains

## Known Limitations

- It relies on having all contract deployed at the same address on all chains.