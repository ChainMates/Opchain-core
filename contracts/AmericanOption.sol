//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
 
import {ERC20} from "./ERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";


contract AmericanOption is ERC20 {

  struct optionMaker {
    uint balance;
    uint shares; 
  }

  struct Order {
    address maker;
    address taker;
    uint256 chainID;
    uint64 deadline;
    uint256 nonce;
    uint256 permiumAmount;
    uint256 optionAmount;
    address optionContractAddress;
    bytes32 hash;
    bytes signature;
 }  

  string PERMIT2_ORDER_TYPE = "";

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
  }


  // Prevents reentrancy attacks via tokens with callback mechanisms. 
  modifier nonReentrant() {
    require(!_reentrancyGuard, 'no reentrancy');
    _reentrancyGuard = true;
    _;
    _reentrancyGuard = false;
  }

  function issuance(Order memory order) external nonReentrant {

    require(order.optionAmount != 0, 'ERROR: optionAmount cannot be zero');

    // Transfer tokens from the caller to ourselves.
    permit2.permitWitnessTransferFrom(
      // The permit message.
      IPermit2.PermitTransferFrom({
          permitted: IPermit2.TokenPermissions({
              token: baseToken,
              amount: order.optionAmount
          }),
          nonce: order.nonce,
          deadline: order.deadline
      }),
      // The transfer recipient and amount.
      IPermit2.SignatureTransferDetails({
          to: address(this),
          requestedAmount: order.optionAmount
      }),
      // The owner of the tokens, which must also be
      // the signer of the message, otherwise this call
      // will fail.
      order.maker,
      order.hash,
      PERMIT2_ORDER_TYPE,
      // The packed signature that was the result of signing
      // the EIP712 hash of `permit`.
      order.signature
    );

    _mint(order.taker, order.optionAmount);
   


  }




  function exercise(uint amount) external {

    

  }

  function withdraw(uint amount) external {


  }


  function _transferBaseTokens(address to, uint amount) internal {
    // Transfer base tokens
  }



}