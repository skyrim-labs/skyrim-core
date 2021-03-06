// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { network } = require("hardhat");
const { deploydVaultAdmin } = require("../test/helpers/fixture.js");
const { sleep } = require("../test/helpers/utils.js");
const commonConfigs = require("../config/contractAddress.js");

const currentNet = network.name;
const configs = commonConfigs[currentNet];

let STToken, JTToken, Skyrim;

async function deploydVault(vaultAddress, startTime, lockTime, STTokenAddr, JTTokenAddr, SkyrimTokenAddr, investTokenAddr) {
  let vault;
  if (!vaultAddress) {
    console.log("Deploy a new Skyrim vault!");
    vault = await deploydVaultAdmin(startTime, 300, STTokenAddr, JTTokenAddr, SkyrimTokenAddr, investTokenAddr);
  } else {
    console.log("Skyrim vault has been deployed!");
    let vaultFactory = await ethers.getContractFactory("SkyrimInvestVaultAdmin");
    vault = vaultFactory.attach(vaultAddress);
  }
  console.log("Skyrim vault deployed to: ", vault.address);
  return vault;
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

  const rawSTSupplyRate = configs.STSupplyRate;
  const STSupplyRate = ethers.utils.parseEther(rawSTSupplyRate.toString());

  const currentTime = Date.parse(new Date()) / 1000;
  console.log("currentTime", currentTime.toString());
  const startTime = currentTime + 60;
  console.log("startTime", startTime.toString())

  const lockedTime = configs.lockedTime;
  console.log("lockedTime", lockedTime.toString())

  let BUSDFactory = await ethers.getContractFactory("BUSD");
  let dai = BUSDFactory.attach(configs.BUSD);
  console.log("dai address", dai.address);

  const STTokenAddr = configs.STToken;
  if (!STTokenAddr) {
    console.log("Please set senior token address first!");
    return;
  } else {
    let STTokenFactory = await ethers.getContractFactory("SeniorToken");
    STToken = STTokenFactory.attach(STTokenAddr);
  }

  const JTTokenAddr = configs.JTToken;
  if (!JTTokenAddr) {
    console.log("Please set junior token address first!");
    return;
  } else {
    let JTTokenFactory = await ethers.getContractFactory("JuniorToken");
    JTToken = JTTokenFactory.attach(JTTokenAddr);
  }

  const SkyrimTokenAddr = configs.Skyrim;
  if (!SkyrimTokenAddr) {
    console.log("Please set skyrim token address first!");
    return;
  } else {
    let SkyrimFactory = await ethers.getContractFactory("SkyrimToken");
    Skyrim = SkyrimFactory.attach(SkyrimTokenAddr);
  }

  const investTokenAddr = configs.BUSD;
  if (!investTokenAddr) {
    console.log("Please set dai address first!");
    return;
  }



  const vaultAddress = configs.vault;
  // We get the contract to deploy
  const vault = await deploydVault(vaultAddress, startTime, lockedTime, STTokenAddr, JTTokenAddr, SkyrimTokenAddr, investTokenAddr);

  // Set vault contract in the senior token.
  let hasSetVaultInST = await STToken.isVault(vault.address);
  console.log("Has set valut in the ST token", hasSetVaultInST, "\n");
  if (!hasSetVaultInST) {
    await STToken.setVault(vault.address);
  }

  // Set vault contract in the junior token.
  let hasSetVaultInJT = await JTToken.isVault(vault.address);
  console.log("Has set vault in the JT token", hasSetVaultInJT, "\n");
  if (!hasSetVaultInJT) {
    await JTToken.setVault(vault.address);
  }

  // Set vault contract as minter in the skyrim token.
  let hasSetVaultInSkyrim = await Skyrim.isMinter(vault.address);
  console.log("Has set vault in the Skyrim token", hasSetVaultInSkyrim, "\n");
  if (!hasSetVaultInSkyrim) {
    await Skyrim.addMinter(vault.address);
  }
  let hasSetVaultInSkyrimAfter = await Skyrim.isMinter(vault.address);
  console.log("Has set vault in the Skyrim token after", hasSetVaultInSkyrimAfter, "\n");

  // Set senior token supply rate.
  let seniorTokenSupplyRate = await vault.getCurrentSTSupplyRate();
  console.log("Current senior token supply rate is: ", seniorTokenSupplyRate.toString());
  if (seniorTokenSupplyRate.toString() == '0') {
    await vault.setSeniorTokenSupplyRate(STSupplyRate);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
