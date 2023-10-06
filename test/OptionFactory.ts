import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
// import { BigInt } from 'ethers';
import { ethers  } from "hardhat";

describe("OptionFactory", function () {
  
  async function deployOptionFactoryFixture() {

    const [broker, permit2] = await ethers.getSigners();

    const optionFactory = await ethers.deployContract("OptionFactory" , [broker.address , permit2.address]);

    await optionFactory.waitForDeployment();

    return {optionFactory , broker, permit2 };
  }

  async function deployTestERC20Fixture(){

    const token0 = await ethers.deployContract("TestERC20" , [ethers.toBigInt("100000000000000000000") , 18]);
    await token0.waitForDeployment();

    const token1 = await ethers.deployContract("TestERC20" , [ethers.toBigInt("10000000000") , 6]);
    await token1.waitForDeployment();

    return { token0 ,token1 };

  }


    it("check the broker and permit2 address" , async function(){
      
      const {optionFactory , broker , permit2} = await  loadFixture(deployOptionFactoryFixture);
      const{token0 , token1} = await loadFixture(deployTestERC20Fixture);


      expect(await optionFactory.broker()).to.equal(broker.address);
      expect(await optionFactory.permit2()).to.equal(permit2.address);
      
    })

    it("check option contract deployment" , async function(){

      const{optionFactory} = await loadFixture(deployOptionFactoryFixture);
      const{token0 , token1} = await loadFixture(deployTestERC20Fixture);

      let option = {
        baseToken : await token0.getAddress() ,
        quoteToken : await token1.getAddress() ,
        strikePriceRatio : 10 ** 9 , 
        expirationDate : 1000 ,
        isAmerican : true
      }

      // await expect(optionFactory.createOption(option)).to.emit(optionFactory , "OptionCreated")
      // .withArgs(option.baseToken , option.quoteToken , option.strikePriceRatio , option.expirationDate , option.isAmerican);

      await expect(optionFactory.createOption(option)).to.be.reverted;


    })


    it("check option contract deployment2" , async function(){

      const{optionFactory} = await loadFixture(deployOptionFactoryFixture);
      const{token0 , token1} = await loadFixture(deployTestERC20Fixture);

      let option = {
        baseToken : await token0.getAddress() ,
        quoteToken : await token1.getAddress() ,
        strikePriceRatio : 10 ** 9 , 
        expirationDate : 1000 ,
        isAmerican : true
      }


      await expect(optionFactory.createOption(option)).to.be.reverted;


    })


});