//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
 
import {ERC20} from "./ERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";
import {SafeMath} from "./library/safeMath.sol";

contract EuropeanOption is ERC20  {

  struct OptionMaker {
    uint collected;
    uint shares;
    uint32 joinedExercise; 
  }

 struct Order{
   address owner;
   uint amount;
   IPermit2.Pemit2 permit;
 }

  using SafeMath for uint256;

 

  string PERMIT2_ORDER_TYPE = "";

  uint[] exerciseShare;

  address public immutable baseToken ;
  address public immutable quoteToken ;
  uint public immutable strikePriceBaseTokenRatio ;
  uint public immutable strikePriceQuoteTokenRatio ;
  uint public immutable expirationDate ;
  
  bool private _reentrancyGuard;
  IPermit2 public immutable permit2;


  mapping(address => OptionMaker) public optionMakers;

  constructor(address _baseToken, address _quoteToken, uint _strikePriceBaseTokenRatio , uint _strikePriceQuoteTokenRatio, uint _expirationDate , uint8 baseTokenDecimals , IPermit2 _permit2) ERC20("EuropeanOption", "EOPT" , baseTokenDecimals) {
   
    baseToken = _baseToken;
    quoteToken = _quoteToken;
    strikePriceBaseTokenRatio = _strikePriceBaseTokenRatio;
    strikePriceQuoteTokenRatio = _strikePriceQuoteTokenRatio;
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

  function issuance(Order memory order , address taker) external nonReentrant {

    require(order.amount != 0, 'ERROR: optionAmount cannot be zero');

    _transferTokens(order);

    _mint(taker, order.amount);
   


  }




  function exercise(Order memory order) external nonReentrant {

    uint amount = order.amount;

    order.amount = order.amount.mul(strikePriceQuoteTokenRatio).div(strikePriceBaseTokenRatio);

    _transferTokens(order);
    
    exerciseShare.push(order.amount.mul(amount).div(totalSupply));

    _burn(order.owner, amount);


  }

  function collect(uint amount) external nonReentrant {
   


  }


   function _transferTokens(Order memory order) internal {

    // Transfer tokens from the caller to ourselves.
    permit2.permitWitnessTransferFrom(
      // The permit message.
      IPermit2.PermitTransferFrom({
          permitted: IPermit2.TokenPermissions({
              token: order.permit.token,
              amount: order.permit.amount
          }),
          nonce: order.permit.nonce,
          deadline: order.permit.deadline
      }),
      // The transfer recipient and amount.
      IPermit2.SignatureTransferDetails({
          to: address(this),
          requestedAmount: order.amount
      }),
      // The owner of the tokens, which must also be
      // the signer of the message, otherwise this call
      // will fail.
      order.owner,
      order.permit.hash,
      PERMIT2_ORDER_TYPE,
      // The packed signature that was the result of signing
      // the EIP712 hash of `permit`.
      order.permit.signature
    );
    }



}