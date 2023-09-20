import { ethers } from "hardhat";
const fs = require("fs");

async function main() {
  const contractName: string = process.env.CONTRACT_NAME || ""
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address)

  const contract = await ethers.deployContract(contractName)

  console.log("contract address:", await contract.address)

  let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())
  contracts.push({ address: contract.address, name: contract.name })
  fs.writeFileSync("./contracts.json", JSON.stringify(contracts))
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });