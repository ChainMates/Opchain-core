//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
 
import {ERC20} from "./ERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";


contract EuropeanOption is ERC20  {

  struct OptionMaker {
    uint balance;
    uint shares; 
  }

struct IssuanceOrder{
    address maker;
    address taker;
    IPermit2.Pemit2 permit;
}

struct ExerciseOrder{
  address owner;
  IPermit2.Pemit2 permit;
}

  string PERMIT2_ORDER_TYPE = "";

  address public immutable baseToken ;
  address public immutable quoteToken ;
  uint public immutable strikePrice ;
  uint public immutable expirationDate ;
  
  bool private _reentrancyGuard;
  IPermit2 public immutable permit2;


  mapping(address => OptionMaker) public optionMakers;

  constructor(address _baseToken, address _quoteToken, uint _strikePrice, uint _expirationDate , uint8 baseTokenDecimals , IPermit2 _permit2) ERC20("EuropeanOption", "EOPT" , baseTokenDecimals) {
   
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

  function issuance(IssuanceOrder memory order) external nonReentrant {

    require(order.permit.amount != 0, 'ERROR: optionAmount cannot be zero');

    _transferTokens(order.permit , order.maker);

    _mint(order.taker, order.permit.amount);
   


  }




  function exercise(ExerciseOrder memory order) external {

    _burn(order.owner, order.permit.amount);

    _transferTokens(order.permit, order.owner);



  }

  function withdraw(uint amount) external {


  }


   function _transferTokens(IPermit2.Pemit2 memory order , address signer) internal {

    // Transfer tokens from the caller to ourselves.
    permit2.permitWitnessTransferFrom(
      // The permit message.
      IPermit2.PermitTransferFrom({
          permitted: IPermit2.TokenPermissions({
              token: order.token,
              amount: order.amount
          }),
          nonce: order.nonce,
          deadline: order.deadline
      }),
      // The transfer recipient and amount.
      IPermit2.SignatureTransferDetails({
          to: address(this),
          requestedAmount: order.amount
      }),
      // The owner of the tokens, which must also be
      // the signer of the message, otherwise this call
      // will fail.
      signer,
      order.hash,
      PERMIT2_ORDER_TYPE,
      // The packed signature that was the result of signing
      // the EIP712 hash of `permit`.
      order.signature
    );
    }



}