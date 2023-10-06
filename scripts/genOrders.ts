import { ethers, network } from "hardhat";
import { AllowanceProvider, PermitSingle, AllowanceTransfer } from '@uniswap/Permit2-sdk'
import { Provider, JsonRpcProvider } from '@ethersproject/providers'
const fs = require("fs");




async function main() {

    let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())
    const PERMIT2_ADDRESS = contracts.Permit2
    const [signer , signer2] = await ethers.getSigners();
    const provider: Provider = new JsonRpcProvider("http://127.0.0.1:8545")
    // const provider: Provider = new JsonRpcProvider("https://burned-hardworking-general.matic-testnet.discover.quiknode.pro/0300f3bbb9c83fa98a8352fa970ee4c642964caf/")
    const allowanceProvider = new AllowanceProvider(provider, PERMIT2_ADDRESS)


    const { amount: makerPermitAmount, expiration: makerExpiration, nonce: makerNonce } = await allowanceProvider.getAllowanceData(contracts.TestWETH , signer.address , contracts.AmericanOption);

  
    const makerPermitSingle: PermitSingle = {
        details: {
            token: contracts.TestWETH,  
            amount: 10n ** 18n,
            // You may set your own deadline - we use 30 days.
            expiration: toDeadline(/* 30 days= */ 1000 * 60 * 60 * 24 * 30),
            nonce: makerNonce,
        },
        spender: contracts.AmericanOption,
        // You may set your own deadline - we use 30 minutes.
        sigDeadline: toDeadline(/* 30 minutes= */ 1000 * 60 * 60 * 30),
    }

    const { amount: takerPermitAmount, expiration: takerExpiration, nonce: takerNonce } = await allowanceProvider.getAllowanceData(contracts.TestUSDT , signer2.address , contracts.Broker);


    const takerPermitSingle: PermitSingle = {
        details: {
        token: contracts.TestUSDT,
        amount: 10n ** 9n,
        // You may set your own deadline - we use 30 days.
        expiration: toDeadline(/* 30 days= */ 1000 * 60 * 60 * 24 * 30),
        nonce : takerNonce,
        },
        spender: contracts.Broker,
        // You may set your own deadline - we use 30 minutes.
        sigDeadline: toDeadline(/* 30 minutes= */ 1000 * 60 * 60 * 30),
        }

    const chainID = Number((await ethers.provider.getNetwork()).chainId)    


    const { domain : makerDomain, types : makerTypes , values : makerValues } = AllowanceTransfer.getPermitData(makerPermitSingle, PERMIT2_ADDRESS, chainID)
    const makerSignature = await signer.signTypedData(<any> makerDomain, makerTypes, makerValues)

    const { domain : takerDomain, types : takerTypes , values : takerValues } = AllowanceTransfer.getPermitData(takerPermitSingle, PERMIT2_ADDRESS, chainID)
    const takerSignature = await signer2.signTypedData(<any> takerDomain, takerTypes, takerValues)



    let makerOrder = {
        orderID: 12345,
        isMaker: true,
        optionAmount: 10n ** 18n,
        permiumRatio: 10n ** 7n,
        deadline: toDeadline(/* 30 days= */ 1000 * 60 * 60 * 24 * 30),
        nonce: makerNonce,
        // makerPermitSingle : makerPermitSingle,
        signature: makerSignature,
        optionContractAddress: contracts.AmericanOption
    }

    let takerOrder = {
        orderID: 54321,
        isMaker: false,
        optionAmount: 10n ** 18n,
        permiumRatio: 10n ** 7n,
        deadline: toDeadline(/* 30 days= */ 1000 * 60 * 60 * 24 * 30),
        nonce: takerNonce,
        // takerPermitSingle : takerPermitSingle,
        signature: takerSignature,
        optionContractAddress: contracts.AmericanOption
    }

    console.log("maker Order : " , makerOrder)
    console.log("taker Order : " , takerOrder)

    
    const broker = await ethers.getContractAt("Broker" , contracts.Broker , signer)
    broker.addListener("orderAdded" , (owner , order) => {
        console.log("add",owner , order)
    })
    broker.addListener("orderDeleted" , (orderID) => console.log("delete",orderID))
    broker.addListener("orderUpdated" , (owner , order) => console.log("update",owner ,order))

    console.log("listen for new orders :")

    await broker.addOrder(makerOrder)

    await broker.connect(signer2).addOrder(takerOrder)

    let matchedOrder = {
        matchID : 11111 ,
        makerOrderID: 12345,
        takerOrderID: 54321,
        makerAddress : signer.address ,
        takerAddress : signer2.address ,
        makerPermiumRatio: 10n ** 7n,
        makerOptionAmount: 10n ** 18n,
        takerPermiumRatio: 10n ** 7n,
        takerOptionAmount: 10n ** 18n,
        makerDeadline: makerOrder.deadline,
        takerDeadline: takerOrder.deadline,
        makerNonce: makerOrder.nonce,
        takerNonce: takerOrder.nonce,
        makerSignature: makerOrder.signature,
        takerSignature: takerOrder.signature,
        optionContractAddress: contracts.AmericanOption
      }



      let tx = await broker.executeOrder(matchedOrder , <any>makerPermitSingle , <any> takerPermitSingle)


}


function toDeadline(expiration: number): number {
    return Math.floor((Date.now() + expiration) / 1000)
}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});