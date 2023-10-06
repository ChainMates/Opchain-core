const { privateKey, mumbaiApiKey, sepoliaApiKey } = require("./config.json")
require("hardhat-contract-sizer");
require("hardhat-tracer");
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.19",
};

export default config;


module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      viaIR: true,
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
      chainId: 80001
    },
    sepolia: {
      url: sepoliaApiKey,
      accounts: [privateKey],
      chainId: 11155111
    },
    hardhat: {
      allowUnlimitedContractSize: false,
    },
  },

  defaultNetwork: "sepolia",
};
