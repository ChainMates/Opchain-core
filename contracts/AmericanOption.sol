//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
 
import {ERC20} from "./ERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";


contract AmericanOption is ERC20 {

  struct optionMaker {
    uint balance;
    uint shares; 
  }

  address public immutable baseToken ;
  address public immutable quoteToken ;
  uint public immutable strikePrice ;
  uint public immutable expirationDate ;
  
  bool private _reentrancyGuard;
  IPermit2 public immutable permit2;


  mapping(address => optionMaker) public optionMakers;

  constructor(address _baseToken, address _quoteToken, uint _strikePrice, uint _expirationDate , uint8 baseTokenDecimals , IPermit2 _permit2) ERC20("AmericanOption", "EOPT" , baseTokenDecimals) {
   
    baseToken = _baseToken;
    quoteToken = _quoteToken;
    strikePrice = _strikePrice;
    expirationDate =_expirationDate;
    permit2 = _permit2;
    // (baseToken , quoteToken , strikePrice , expirationDate) = (_baseToken , _quoteToken ,_strikePrice , _expirationDate);
  }


  // Prevents reentrancy attacks via tokens with callback mechanisms. 
  modifier nonReentrant() {
    require(!_reentrancyGuard, 'no reentrancy');
    _reentrancyGuard = true;
    _;
    _reentrancyGuard = false;
  }

  function issuance(address maker , address taker , uint amount , bytes calldata makerPermit2Signature ) external nonReentrant {


    require(amount != 0, 'ERROR: amount cannot be zero');
   


  }




  function exercise(uint amount) external {

    

  }

  function withdraw(uint amount) external {


  }

  function _mint(address to, uint amount) internal {
  }

  function _burn(address from, uint amount) internal {
  }

  function _transferBaseTokens(address to, uint amount) internal {
    // Transfer base tokens
  }



}