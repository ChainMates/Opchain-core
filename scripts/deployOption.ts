import { artifacts, ethers  } from "hardhat";
const fs = require("fs");

async function main(){

    const [signer] = await ethers.getSigners();
    let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())
    
    let option = {
        baseToken : contracts.TestWETH ,
        quoteToken :  contracts.TestUSDT,
        strikePriceRatio : 10n ** 9n , 
        expirationDate : toDeadline(/* 30 days= */ 1000 * 60 * 60 * 24 * 30) ,
        isAmerican : true
      }

      
      const optionFactory = await ethers.getContractAt("OptionFactory" , contracts.OptionFactory , signer)
      optionFactory.addListener("OptionCreated" , (baseToken , quoteToken , strikePriceRatio , expirationDate , isAmerican , optionAddress) => {
          console.log(baseToken , quoteToken , strikePriceRatio , expirationDate , isAmerican , optionAddress)
          let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())
          contracts["AmericanOption"] = optionAddress
          fs.writeFileSync("./contracts.json", JSON.stringify(contracts))
        })
        
        console.log("listene to create new option :")
        let newOption = await optionFactory.createOption(option)

}

function toDeadline(expiration: number): number {
    return Math.floor((Date.now() + expiration) / 1000)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});