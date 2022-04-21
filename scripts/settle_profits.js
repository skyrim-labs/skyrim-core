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

let STToken, JTToken, TRA;

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

  let DAIFactory = await ethers.getContractFactory("DAI");
  let dai = DAIFactory.attach(configs.DAI);
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

  const vaultAddress = configs.vault;
  // We get the contract to deploy
  let vaultFactory = await ethers.getContractFactory("SkyrimInvestVaultAdmin");
  const vault = vaultFactory.attach(vaultAddress);

  let currentJTBalance = await JTToken.balanceOf(deployer.address);
  console.log("currentJTBalance", currentJTBalance.toString());

  let currentperiod = await vault.getCurrentPeriod();
  console.log("currentperiod is: ", currentperiod.toString());

  let startTime1 = await vault.startTime();
  // let lockTime = await vault.lockTime();
  console.log("startTime1", startTime1.toString());
  // console.log("lockTime", lockTime.toString());
  // console.log("vault period", (await vault.currentPeriod()).toString())
  // return;
  // console.log("startTime1.div(lockTime)", (startTime1.div(lockTime)).toString());

  // TODO:
  let profits = ethers.utils.parseEther("10");
  let investmetns = ethers.utils.parseEther("1");
   // !!!For the first time, profits should be 0.
  // await vault.settleProfitsByOwner([0, 0], [0, 0]);
  await vault.settleProfitsByOwner(['10000000000000000000', '10000000000000000000'], [0, 0]);  // 10
  // await vault.settleProfitsByOwner(['10000000000000000000', 0], [0, 0]);  // 10
  // await vault.settleProfitsByOwner([0, 0], ['0', '9000000000000000000'], ); // 9
  // await vault.settleProfitsByOwner([0, 0], ['10000000000000000000', '10000000000000000000'], ); // [10, 10]
  await vault.investByOwner([0, investmetns]);

  // let investor = "0x..."
  // await getUserInfo(vault, investor);
  // await getVaultInfo(vault);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
