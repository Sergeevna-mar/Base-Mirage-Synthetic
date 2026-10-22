// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface IMirageSyntheticCollateral {
    function depositCollateralAndMint(bytes32 synthId, uint256 mintAmount) external payable;
    function burnSyntheticAndWithdraw(bytes32 synthId, uint256 burnAmount) external;
    function liquidatePosition(address user, bytes32 synthId) external;
}
