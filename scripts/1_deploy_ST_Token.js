// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { network } = require("hardhat");
const { deploySTToken } = require("../test/helpers/fixture.js");
const commonConfigs = require("../config/contractAddress.js");

const currentNet = network.name;
const configs = commonConfigs[currentNet];

async function deploySeniorToken(BUSDAddress, STTokenAddr) {
  let STToken;
  if (!STTokenAddr) {
    console.log("Deploy a new Senior Token!");
    STToken = await deploySTToken(BUSDAddress);
  } else {
    console.log("Senior Token has been deployed!");
    let STTokenFactory = await ethers.getContractFactory("SeniorToken");
    STToken = STTokenFactory.attach(STTokenAddr);
  }
  console.log("ST token deployed to: ", STToken.address);
  return STToken;
}


async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  [deployer] = await ethers.getSigners();
  console.log("\nDeploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString(), "\n");

  const BUSDAddress = configs.BUSD;
  if (!BUSDAddress) {
    console.log("Please set BUSD address first!");
    return;
  }

  const STTokenAddress = configs.STToken;
  // We get the contract to deploy
  await deploySeniorToken(BUSDAddress, STTokenAddress);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
