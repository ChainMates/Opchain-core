import { ethers } from "hardhat";
const fs = require("fs");

async function main() {
  const contractName: string = "Broker"
  let Contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())
  const [deployer1 , deployer2] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer1.address)

  const contract = await ethers.deployContract(contractName,[Contracts.Permit2])

  console.log("contract address:", await contract.getAddress())

  // await contract.mint(deployer2.address , 10n ** 12n)

  // console.log(await contract.balanceOf(deployer2))

  let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())
  contracts["TestUSDT"] = await contract.getAddress()
  fs.writeFileSync("./contracts.json", JSON.stringify(contracts))
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });