import { ethers  } from "hardhat";
const fs = require("fs");
import { AllowanceProvider, PermitSingle, AllowanceTransfer } from '@uniswap/Permit2-sdk'
import { Provider, JsonRpcProvider } from '@ethersproject/providers'


async function main(){

    const [signer , signer2] = await ethers.getSigners()
    let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())


    const PERMIT2_ADDRESS = contracts.Permit2
    const provider: Provider = new JsonRpcProvider("http://127.0.0.1:8545")
    const allowanceProvider = new AllowanceProvider(provider, PERMIT2_ADDRESS)


    const { amount: permitAmount, expiration: expiration, nonce: nonce } = await allowanceProvider.getAllowanceData(contracts.TestUSDT , signer2.address , contracts.AmericanOption);
    console.log(permitAmount , expiration  , nonce)
  
    const permitSingle: PermitSingle = { 
        details: {
            token: contracts.TestUSDT,
            amount: (5n * 10n ** 8n),
            // You may set your own deadline - we use 30 days.
            expiration: toDeadline(/* 30 days= */ 1000 * 60 * 60 * 24 * 30),
            nonce: nonce,
        },
        spender: contracts.AmericanOption, 
        // You may set your own deadline - we use 30 minutes.
        sigDeadline: toDeadline(/* 30 minutes= */ 1000 * 60 * 60 * 30),
    }

    const chainID = Number((await ethers.provider.getNetwork()).chainId)    


    const { domain : domain, types : types , values : values } = AllowanceTransfer.getPermitData(permitSingle, PERMIT2_ADDRESS, chainID)
    const signature = await signer2.signTypedData(<any> domain, types, values)

    console.log(permitSingle)

    const AmericanOption = await ethers.getContractAt("AmericanOption" , contracts.AmericanOption , signer2)

    let tx = await AmericanOption.exercise((5n * 10n ** 17n) , <any>permitSingle , signature )





}

function toDeadline(expiration: number): number {
    return Math.floor((Date.now() + expiration) / 1000)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});