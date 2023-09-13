//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {EuropeanOption} from "./EuropeanOption.sol";
import {AmericanOption} from "./AmericanOption.sol";
import {IERC20} from "./interface/IERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";


contract OptionFactory {

  struct Option {
    address baseToken; 
    address quoteToken;
    uint strikePrice;
    uint expirationDate;
  }

  IPermit2 public immutable permit2;

  constructor(IPermit2 _permit2){
    permit2 = _permit2;
  }

  mapping(bytes32 => address) public getOptions;

  event OptionCreated(address indexed baseToken, address indexed quoteToken ,uint strikePrice , uint expirationDate , bool isAmerican , address Option);


  function createOption(address baseToken , address quoteToken , uint strikePrice , uint expirationDate , bool isAmerican ) 
  external returns (address option) {

    require(baseToken != quoteToken, 'ERROR : identical addresses');
    require(baseToken != address(0) || quoteToken != address(0) , "ERROR : zero address");
    
    bytes32 hash = keccak256(abi.encode(baseToken, quoteToken, strikePrice, expirationDate , isAmerican));
    
    require(getOptions[hash] == address(0), "ERROR: option already exists");



    if(isAmerican)
      option = address(new AmericanOption(baseToken, quoteToken, strikePrice, expirationDate , IERC20(baseToken).decimals() , permit2));
     else
       option = address(new EuropeanOption(baseToken, quoteToken, strikePrice, expirationDate , IERC20(baseToken).decimals() , permit2));
    
    getOptions[hash] = option;

    emit OptionCreated(baseToken ,quoteToken ,strikePrice ,expirationDate , isAmerican , option);

  }

}