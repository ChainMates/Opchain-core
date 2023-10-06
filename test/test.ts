import {
    loadFixture,
  } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers  } from "hardhat";
const fs = require("fs");
import { AllowanceProvider, PermitSingle, AllowanceTransfer } from '@uniswap/Permit2-sdk'
import { Provider, JsonRpcProvider , getDefaultProvider } from '@ethersproject/providers'


  
  describe("Permit2", function () {

    it("test AllowanceTransfer" ,  async function () {
    
      const [signer] = await ethers.getSigners()
      let contracts = JSON.parse(fs.readFileSync("./contracts.json").toString())

    


        
      let matchedOrder = {
        matchID : 1111 ,
        makerOrderID: 1234567,
        takerOrderID: 7654321,
        makerAddress : signer.address ,
        takerAddress : signer.address ,
        makerPermiumRatio: 10n ** 9n,
        makerOptionAmount: 10n ** 18n,
        takerPermiumRatio: 10n ** 9n,
        takerOptionAmount: 10n ** 18n,
        makerDeadline: 1699001206,
        takerDeadline: 1699001206,
        makerNonce: 0,
        takerNonce: 0,
        makerSignature: '0x35885156d19cb8d58fdcb6a5f560fda498764bc5270741dd79dbc486c5e7ed48463ef586465ab18359b3c1344f8251d1d2fa58a8bc430d06d1c4145901f2c35d1b',
        takerSignature: '0x1d35f6f3a9f25f3f56ad4ee3685ea7cb287f414786766e2692edf856eb8cc1b43dc413c017ed143de03d0f7fda00847a26022097cd19b5fad47268eec378b5d21b',
        optionContractAddress: contracts.AmericanOption
      }
      // const broker = await ethers.getContractAt("Broker" , contracts.Broker , signer)
      const permit2 = await ethers.deployContract("Permit2")
      await permit2.waitForDeployment();

      const testPer = await ethers.deployContract("testPer" ,[await permit2.getAddress()])
      await testPer.waitForDeployment();

      await testPer.permitOrder(matchedOrder)


      // await broker.executeOrder(matchedOrder)

    //   expect(await broker.permit2()).to.equal(contracts.Permit2)
        // expect(await broker.executeOrder(matchedOrder)).to.be.reverted
        // expect(broker.executeOrder(matchedOrder)).to.emit(broker , "orderDeleted").withArgs(matchedOrder.matchID)

  })
  })