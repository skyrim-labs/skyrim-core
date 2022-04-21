// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { network } = require("hardhat");
const commonConfigs = require("../config/contractAddress.js");

const { getUserInfo, getVaultInfo } = require("../test/helpers/utils.js");

const currentNet = network.name;
const configs = commonConfigs[currentNet];

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  [deployer] = await ethers.getSigners();

  const vaultAddress = configs.vault;
  // We get the contract to deploy
  let vaultFactory = await ethers.getContractFactory("SkyrimInvestVaultAdmin");
  const vault = vaultFactory.attach(vaultAddress);

   // !!!For the first time, profits should be 0.
  await vault.setAPY(0, 50000); // 5%
  await vault.setAPY(1, 150000);  // 15%
  const apyST = await vault.getAPY(0);
  const apyJT = await vault.getAPY(1);
  console.log('apyST: ', apyST.toString());
  console.log('apyJT: ', apyJT.toString());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
