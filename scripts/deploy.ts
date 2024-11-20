import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {
  const Config = await ethers.getContractFactory("AMTConfig");
  
  const config = await hre.upgrades.deployProxy(Config);
  
  await config.deployed();

  console.log("Contract address: ", config.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
