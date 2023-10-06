import { ethers  } from "hardhat";
const fs = require("fs");


async function main(){

    const [signer] = await ethers.getSigners()
    let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())

    const AmericanOption = await ethers.getContractAt("AmericanOption" , contracts.AmericanOption , signer)

    let tx = await AmericanOption.collect(signer.address)


}



main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
})