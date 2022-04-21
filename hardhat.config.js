require("dotenv").config();
require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require('hardhat-contract-sizer');

const privateKey = process.env.PRIVATE_KEY;

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    bsc_test: {
      url: `https://data-seed-prebsc-2-s1.binance.org:8545/`,
      accounts: [`0x${privateKey}`],
      gas: 8000000,
      gasPrice: 10000000000,
    },
  },
  solidity: {
    version: "0.7.6",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
};

