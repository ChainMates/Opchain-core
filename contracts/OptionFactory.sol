//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {EuropeanOption} from "./EuropeanOption.sol";
import {AmericanOption} from "./AmericanOption.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";


contract OptionFactory {

  struct Option {
    address baseToken; 
    address quoteToken;
    uint strikePriceBaseTokenRatio;
    uint strikePriceQuoteTokenRatio;
    uint expirationDate;
    bool isAmerican;
  }

  IPermit2 public immutable permit2;

  constructor(IPermit2 _permit2){
    permit2 = _permit2;
  }

  mapping(bytes32 => address) public getOptions;

  event OptionCreated(address indexed baseToken, address indexed quoteToken ,uint strikePrice , uint expirationDate , bool isAmerican , address Option);


  function createOption(Option memory option ) 
  external returns (address createdOption) {

    require(option.baseToken != option.quoteToken, 'ERROR : identical addresses');
    require(option.baseToken != address(0) || option.quoteToken != address(0) , "ERROR : zero address");
    
    bytes32 hash = keccak256(abi.encode(option.baseToken, option.quoteToken, option.strikePriceBaseTokenRatio , option.strikePriceQuoteTokenRatio, option.expirationDate , option.isAmerican));
    
    require(getOptions[hash] == address(0), "ERROR: option already exists");



    if(option.isAmerican)
      createdOption = address(new AmericanOption(option.baseToken, option.quoteToken, option.strikePriceBaseTokenRatio , option.strikePriceQuoteTokenRatio, option.expirationDate , IERC20(option.baseToken).decimals() , permit2));
     else
       createdOption = address(new EuropeanOption(option.baseToken, option.quoteToken, option.strikePriceBaseTokenRatio , option.strikePriceQuoteTokenRatio, option.expirationDate , IERC20(option.baseToken).decimals() , permit2));
    
    getOptions[hash] = createdOption;

    emit OptionCreated(option.baseToken ,option.quoteToken ,option.strikePrice ,option.expirationDate , option.isAmerican , createdOption);

  }

}