import { Signature } from "ethers";
import { ethers  } from "hardhat";
const fs = require("fs");


async function main(){

    const [signer , signer2] = await ethers.getSigners()
    let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())

    const TestWETH = await ethers.getContractAt("TestERC20" , contracts.TestWETH , signer)
    const TestUSDT = await ethers.getContractAt("TestERC20" , contracts.TestUSDT , signer2)
    const AmericanOption = await ethers.getContractAt("AmericanOption" , contracts.AmericanOption , signer)


    console.log(await TestWETH.balanceOf(signer))
    console.log(await TestUSDT.balanceOf(signer))
    console.log(await TestUSDT.balanceOf(signer2))
    // console.log(await AmericanOption.balanceOf(signer))
    console.log(await AmericanOption.balanceOf(signer2))
    console.log(await TestWETH.balanceOf(contracts.AmericanOption))









}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});