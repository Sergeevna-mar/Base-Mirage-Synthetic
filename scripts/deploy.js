const hre = require("hardhat");
async function main() {
  const SyntheticFactory = await hre.ethers.getContractFactory("MirageSyntheticCollateral");
  const mirage = await SyntheticFactory.deploy();
  await mirage.deployed();
  console.log("-> Mirage Synthetic Engine live at:", mirage.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
