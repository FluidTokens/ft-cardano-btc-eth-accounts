
# Aiken Smart Contracts for Bitcoin Wallet Integration

This repository contains smart contracts written in **Aiken** designed to integrate Bitcoin and EVM wallet signatures into the **Cardano** blockchain ecosystem.

## Validators Folder

- The `validators` folder contains the **Aiken** smart contracts responsible for signature validation. These contracts allow compatibility with **Bitcoin wallets** and **EVM wallets**, leveraging their public key infrastructure for secure interaction within the Cardano blockchain.
  
## Project Flow

1. **Contract Address Generation:**
   - The smart contract generates a Cardano-compatible address using the **public key** of a **Bitcoin wallet**. This address is then tied to that Bitcoin wallet for future operations.
   
2. **Transaction Control:**
   - The generated address can only perform specific actions like:
     - **Sending assets**
     - **Delegating to stake pools**
     - **Withdrawing assets**
   - These actions require the explicit **approval** of the Bitcoin wallet owner. This is done through an off-chain signature mechanism.

3. **Cross-Chain Authorization:**
   - **How does a Bitcoin wallet submit a transaction on Cardano?** It doesn’t.
     - Instead, the **Bitcoin wallet signs an off-chain message**, authorizing a specific transaction. 
     - Once signed, **anyone on Cardano** can submit the corresponding transaction on behalf of the Bitcoin wallet. This is done according to the contract owner's predefined rules, ensuring secure and transparent execution.
     - In exchange for submitting the transaction, the user is rewarded with a small fee in **ADA**.

## Key Features

- **Cross-chain integration**: Bitcoin and EVM wallet signatures can be used to authorize Cardano blockchain transactions.
- **Decentralized execution**: Cardano users can execute approved actions, reducing the burden on the Bitcoin wallet owner.
- **Small incentives**: Users submitting authorized transactions earn a small **ADA** reward for their service.
