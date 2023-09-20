const { privateKey, mumbaiApiKey } = require("./config.json")
require("hardhat-contract-sizer");
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.19",
};

export default config;


module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {

    polygon_mumbai: {
      url: mumbaiApiKey,
      accounts: [privateKey],
    }
  },

  defaultNetwork: "polygon_mumbai",
};
