import { MaxUint256 } from "ethers";
import { ethers  } from "hardhat";
const fs = require("fs");

async function main(){

    const [signer , signer2] = await ethers.getSigners()
    let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())

    const TestWETH = await ethers.getContractAt("TestERC20" , contracts.TestWETH , signer)
    const TestUSDT = await ethers.getContractAt("TestERC20" , contracts.TestUSDT , signer2)

    // TestUSDT.addListener("Approval" , (user , spender ,amount) =>{
    //     console.log(user , spender , amount)
    // })

    // console.log("listen for new approval : ")

    await TestWETH.approve(contracts.Permit2 , MaxUint256)
    await TestUSDT.approve(contracts.Permit2 , MaxUint256)
    console.log(await TestWETH.allowance(signer.address , contracts.Permit2))
    console.log(await TestUSDT.allowance(signer2.address , contracts.Permit2))
}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});