// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { network } = require("hardhat");
const { deployProtocolToken } = require("../test/helpers/fixture.js");
const commonConfigs = require("../config/contractAddress.js");

const currentNet = network.name;
const configs = commonConfigs[currentNet];

async function deployProtocolToken(SkyrimAddr, recipient, initalSupply) {
  let Skyrim;
  if (!SkyrimAddr) {
    console.log("Deploy a new Protocol Token!");
    Skyrim = await deployProtocolToken(recipient, initalSupply);
  } else {
    console.log("Protocol Token has been deployed!");
    let SkyrimFactory = await ethers.getContractFactory("SkyrimToken");
    Skyrim = SkyrimFactory.attach(SkyrimAddr);
  }
  console.log("Protocol token deployed to: ", Skyrim.address);
  return Skyrim;
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

  const recipient = deployer.address;
  const initalSupply = ethers.utils.parseEther("1000000");

  const SkyrimAddress = configs.Skyrim;
  await deployProtocolToken(SkyrimAddress, recipient, initalSupply);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
