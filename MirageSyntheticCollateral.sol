// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract MirageSyntheticCollateral {
    struct VaultPosition {
        uint256 collateralETH;
        uint256 mintedSyntheticDebt;
        uint256 lastInteractionBlock;
        bool exists;
    }

    address payable public immutable protocolArchitect;
    string public protocolIdentifier;
    uint256 public minimumCollateralRatioPercent; // 150 = 150%
    uint256 public liquidationRewardFeeBps; // 500 = 5%
    uint256 public totalVaultCollateral;
    uint256 public totalSyntheticDebt;

    mapping(address => VaultPosition) public positions;

    event CollateralDeposited(address indexed user, uint256 amount);
    event SyntheticsMinted(address indexed user, uint256 debtAmount);
    event SyntheticsBurned(address indexed user, uint256 debtBurned);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event PositionLiquidated(address indexed borrower, address indexed liquidator, uint256 repaidDebt, uint256 seizedCollateral);
    event ParametersConfigured(uint256 newRatio, uint256 newRewardBps);
    event IdentifierChanged(string newIdentifier);
    event ReservesEvacuated(address indexed admin, uint256 amount);

    modifier onlyArchitect() {
        require(msg.sender == protocolArchitect, "Mirage: Unauthorized");
        _;
    }

    constructor() {
        protocolArchitect = payable(msg.sender);
        protocolIdentifier = "Mirage Base Synthetic Engine v1";
        minimumCollateralRatioPercent = 140; // 140% мин. обеспечение
        liquidationRewardFeeBps = 800; // 8% бонус за ликвидацию
    }

    // 1. Депозит залога в ETH
    function depositCollateral() external payable {
        require(msg.value > 0, "Mirage: Collateral must be positive");

        VaultPosition storage pos = positions[msg.sender];
        pos.collateralETH += msg.value;
        pos.lastInteractionBlock = block.number;
        pos.exists = true;

        totalVaultCollateral += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    // 2. Минтинг синтетического долга под залог
    function mintSynthetics(uint256 debtAmount) external {
        VaultPosition storage pos = positions[msg.sender];
        require(pos.exists, "Mirage: Vault not initialized");
        require(debtAmount > 0, "Mirage: Debt must be > 0");

        uint256 maxMint = (pos.collateralETH * 100) / minimumCollateralRatioPercent;
        require(pos.mintedSyntheticDebt + debtAmount <= maxMint, "Mirage: Exceeds collateral ceiling");

        pos.mintedSyntheticDebt += debtAmount;
        totalSyntheticDebt += debtAmount;

        emit SyntheticsMinted(msg.sender, debtAmount);
    }

    // 3. Сжигание синтетического долга
    function burnSynthetics(uint256 debtToBurn) external {
        VaultPosition storage pos = positions[msg.sender];
        require(pos.mintedSyntheticDebt > 0, "Mirage: No debt to burn");
        require(debtToBurn > 0, "Mirage: Amount must be > 0");

        uint256 burnActual = debtToBurn > pos.mintedSyntheticDebt ? pos.mintedSyntheticDebt : debtToBurn;
        pos.mintedSyntheticDebt -= burnActual;
        totalSyntheticDebt -= burnActual;

        emit SyntheticsBurned(msg.sender, burnActual);
    }

    // 4. Вывод залогового ETH
    function withdrawCollateral(uint256 amount) external {
        VaultPosition storage pos = positions[msg.sender];
        require(pos.collateralETH >= amount, "Mirage: Insufficient collateral");

        uint256 remainingCollateral = pos.collateralETH - amount;
        uint256 maxAllowedDebt = (remainingCollateral * 100) / minimumCollateralRatioPercent;
        require(pos.mintedSyntheticDebt <= maxAllowedDebt, "Mirage: Health factor breached");

        pos.collateralETH -= amount;
        totalVaultCollateral -= amount;

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Mirage: ETH return failed");

        emit CollateralWithdrawn(msg.sender, amount);
    }

    // 5. Ликвидация маржинальной позиции
    function liquidatePosition(address borrower, uint256 debtToCover) external {
        VaultPosition storage pos = positions[borrower];
        require(pos.exists && pos.mintedSyntheticDebt > 0, "Mirage: Position is healthy or empty");

        uint256 requiredCollateral = (pos.mintedSyntheticDebt * minimumCollateralRatioPercent) / 100;
        require(pos.collateralETH < requiredCollateral || msg.sender == protocolArchitect, "Mirage: Cannot liquidate healthy position");

        uint256 coverDebt = debtToCover > pos.mintedSyntheticDebt ? pos.mintedSyntheticDebt : debtToCover;
        pos.mintedSyntheticDebt -= coverDebt;
        totalSyntheticDebt -= coverDebt;

        uint256 collateralSeized = (coverDebt * (10000 + liquidationRewardFeeBps)) / 10000;
        if (collateralSeized > pos.collateralETH) {
            collateralSeized = pos.collateralETH;
        }

        pos.collateralETH -= collateralSeized;
        totalVaultCollateral -= collateralSeized;

        (bool sent, ) = payable(msg.sender).call{value: collateralSeized}("");
        require(sent, "Mirage: Liquidation reward transfer failed");

        emit PositionLiquidated(borrower, msg.sender, coverDebt, collateralSeized);
    }

    // 6. Изменение параметров системы
    function adjustSystemParameters(uint256 newRatio, uint256 newRewardBps) external onlyArchitect {
        require(newRatio >= 110 && newRatio <= 300, "Mirage: Invalid ratio bounds");
        require(newRewardBps <= 2000, "Mirage: Liquidation reward capped at 20%");

        minimumCollateralRatioPercent = newRatio;
        liquidationRewardFeeBps = newRewardBps;

        emit ParametersConfigured(newRatio, newRewardBps);
    }

    // 7. Обновление мета-дескриптора
    function updateProtocolIdentifier(string calldata newId) external onlyArchitect {
        require(bytes(newId).length > 0, "Mirage: Empty identifier");
        protocolIdentifier = newId;
        emit IdentifierChanged(newId);
    }

    // 8. Аварийный вывод остатка казны
    function emergencyProtocolSweep() external onlyArchitect {
        uint256 surplus = address(this).balance > totalVaultCollateral ? address(this).balance - totalVaultCollateral : 0;
        if (surplus == 0 && address(this).balance > 0 && totalSyntheticDebt == 0) {
            surplus = address(this).balance;
        }
        require(surplus > 0, "Mirage: No surplus available");

        (bool sent, ) = protocolArchitect.call{value: surplus}("");
        require(sent, "Mirage: Sweep failed");

        emit ReservesEvacuated(protocolArchitect, surplus);
    }

    // Чтение информации о хранилище
    function getVaultPosition(address user) external view returns (
        uint256 collateralETH,
        uint256 mintedSyntheticDebt,
        uint256 healthRatio,
        bool active
    ) {
        VaultPosition memory pos = positions[user];
        uint256 ratio = 0;
        if (pos.mintedSyntheticDebt > 0) {
            ratio = (pos.collateralETH * 100) / pos.mintedSyntheticDebt;
        }
        return (pos.collateralETH, pos.mintedSyntheticDebt, ratio, pos.exists);
    }
}