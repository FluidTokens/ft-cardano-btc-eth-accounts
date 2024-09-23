
# Aiken Smart Contracts for Bitcoin Wallet Integration

This repository contains smart contracts written in **Aiken** designed to integrate Bitcoin and EVM wallet signatures into the **Cardano** blockchain ecosystem.

## Validators Folder

- The `validators` folder contains the **Aiken** smart contracts responsible for signature validation. These contracts allow compatibility with **Bitcoin wallets** and **EVM wallets**, leveraging their public key infrastructure for secure interaction within the Cardano blockchain.
  
## Project Flow



1. **Contract Address Generation:**
   - The smart contract generates a Cardano-compatible address using the **public key** of a **Bitcoin wallet**. This address is then tied to that Bitcoin wallet for future operations.
<img width="916" alt="image" src="https://github.com/user-attachments/assets/3c60f36d-29b7-4c67-9c9a-4dd21dbc8a30">

In the image we can see an example of contract address generated like this, how can we understand it's a contract, because credentials are the same of the plutus.json file generated by aiken
   


2. **Transaction Control:**
   - The generated address can only perform specific actions like:
     - **Sending assets**
     - **Delegating to stake pools**
     - **Withdrawing assets**
   - These actions require the explicit **approval** of the Bitcoin wallet owner. This is done through an off-chain signature mechanism.

Here an example of transaction [explorer](https://cexplorer.io/tx/965e0a9dfc7584ad9fb6b2b56ec0467851a07dab539962757839c9c859f9bab1/contract#data) that allows staking delegation to a specific stake pool

<img width="1064" alt="image" src="https://github.com/user-attachments/assets/3c0b9495-0a89-403f-8dc1-80df79d9a6e8">

A Cardano wallet is able to allow the transaction using the signature of the bitcoin wallet



3. **Cross-Chain Authorization:**
   - **How does a Bitcoin wallet submit a transaction on Cardano?** It doesn’t.
     - Instead, the **Bitcoin wallet signs an off-chain message**, authorizing a specific transaction. 
     - Once signed, **anyone on Cardano** can submit the corresponding transaction on behalf of the Bitcoin wallet. This is done according to the contract owner's predefined rules, ensuring secure and transparent execution.
     - In exchange for submitting the transaction, the user is rewarded with a small fee in **ADA**.

4. **Compatible wallets**
   -XVerse
   -Unisat
   -Leather
   -MagicEden
   -OKX

<img width="265" alt="image" src="https://github.com/user-attachments/assets/02303f7d-d869-4bd3-9b34-d742b5bb84e4">


## Key Features

- **Cross-chain integration**: Bitcoin and EVM wallet signatures can be used to authorize Cardano blockchain transactions.
- **Decentralized execution**: Cardano users can execute approved actions, reducing the burden on the Bitcoin wallet owner.
- **Small incentives**: Users submitting authorized transactions earn a small **ADA** reward for their service.
