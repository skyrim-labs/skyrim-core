// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { network } = require("hardhat");
const commonConfigs = require("../config/contractAddress.js");

const currentNet = network.name;
const configs = commonConfigs[currentNet];

async function deploy(address) {
  let busd;
  if (!address) {
    console.log("Deploy a new BUSD!");
    const BUSD = await hre.ethers.getContractFactory("BUSD");
    busd = await BUSD.deploy();

    await busd.deployed();

    // Token faucet.
    await busd.mint(deployer.address, await ethers.utils.parseEther("1000000"));
  } else {
    console.log("BUSD has been deployed!");
    let factory = await ethers.getContractFactory("BUSD");
    busd = factory.attach(address);
  }
  console.log("BUSD deployed to:", busd.address);
  return busd;
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

  const address = configs.BUSD;
  // We get the contract to deploy
  await deploy(address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
