// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
// VALIDATION: Ensure users cannot mint synthetics if their collateral ratio is below the minimum threshold
// REQUIREMENT: Verify liquidation math accurately calculates the discount bonus for keepers without rounding errors
