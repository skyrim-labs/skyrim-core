// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { network } = require("hardhat");
const { deployJTToken } = require("../test/helpers/fixture.js");
const commonConfigs = require("../config/contractAddress.js");

const currentNet = network.name;
const configs = commonConfigs[currentNet];

async function deployJuniorToken(BUSDAddress, JTTokenAddr) {
  let JTToken;
  if (!JTTokenAddr) {
    console.log("Deploy a new Junior Token!");
    JTToken = await deployJTToken(BUSDAddress);
  } else {
    console.log("Junior Token has been deployed!");
    let JTTokenFactory = await ethers.getContractFactory("JuniorToken");
    JTToken = JTTokenFactory.attach(JTTokenAddr);
  }
  console.log("JT token deployed to: ", JTToken.address);
  return JTToken;
}

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  [deployer] = await ethers.getSigners();
  console.log("\nDeploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString(), "\n");

  const BUSDAddress = configs.BUSD;
  if (!BUSDAddress) {
    console.log("Please set BUSD address first!");
    return;
  }

  const JTTokenAddress = configs.JTToken;
  // We get the contract to deploy
  await deployJuniorToken(BUSDAddress, JTTokenAddress);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
