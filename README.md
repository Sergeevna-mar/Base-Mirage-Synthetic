# Base Mirage Synthetic Collateral

A robust decentralized finance protocol deployed on the Base L2 network. Mirage allows users to lock native crypto assets as collateral to mint synthetic derivatives pegged to real-world assets, enabling borderless exposure to traditional financial markets entirely on-chain.

## Core Mechanics
* **Overcollateralized Minting:** To ensure system solvency, all synthetic positions require a minimum collateralization ratio (e.g., 150%). Users must deposit excess value to mint synthetic tokens, protecting the protocol against sudden market downturns.
* **Automated Liquidation Engine:** If the value of the underlying collateral drops below the required maintenance margin, the position becomes eligible for immediate liquidation. External keepers can repay the synthetic debt to claim the locked collateral at a discount.
* **Dynamic Price Feeds:** Integrates secure decentralized oracle networks to continuously update the spot price of both the collateral and the target synthetic asset, preventing price manipulation and flash-loan attacks.

## Architecture
Developed using Solidity `0.8.37`. The protocol strictly isolates state mutations from oracle updates and token transfers, utilizing the Checks-Effects-Interactions pattern during minting, burning, and liquidation events to eliminate reentrancy vulnerabilities.
