import { artifacts, ethers } from "hardhat";
const fs = require("fs");

async function main() {

    const [signer] = await ethers.getSigners();
    let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())

    let option = {
        baseToken: "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa",
        quoteToken: "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889",
        strikePriceRatio: 10n ** 9n,
        expirationDate: toDeadline(/* 30 days= */ 1000 * 60 * 60 * 24 * 30),
        isAmerican: true
    }


    const optionFactory = await ethers.getContractAt("OptionFactory", contracts.OptionFactory, signer)


    console.log(await optionFactory.broker())
    
    optionFactory.addListener("OptionCreated", (baseToken, quoteToken, strikePriceRatio, expirationDate, isAmerican, optionAddress) => {
        console.log(baseToken, quoteToken, strikePriceRatio, expirationDate, isAmerican, optionAddress)
        let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())
        contracts["AmericanOption"] = optionAddress
        fs.writeFileSync("./contracts.json", JSON.stringify(contracts))
    })

    console.log("listening to create new option :")
    let newOption = await optionFactory.createOption(option)

}

function toDeadline(expiration: number): number {
    return Math.floor((Date.now() + expiration) / 1000)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});