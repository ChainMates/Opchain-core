const { privateKey, mumbaiApiKey } = require("./config.json")
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.19",
};

export default config;


module.exports = {
  solidity: "0.8.19",
  networks: {

    polygon_mumbai: {
      url: mumbaiApiKey,
      accounts: [privateKey],
    }
  },
  settings: {
    optimizer: {
      enabled: true,
      runs: 1,
    },
  },
  defaultNetwork: "polygon_mumbai",
};
