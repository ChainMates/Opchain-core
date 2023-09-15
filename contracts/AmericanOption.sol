//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
 
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extention/ERC20Permit.sol";
import {IPermit2} from "./interface/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AmericanOption is ERC20 , ERC20Permit {

  struct OptionInfo{
    uint share;
    uint32 stageJoined;
  }

  struct OptionMaker {
    uint totalShare;
    uint collected;
    OptionInfo[] issuances;
  }

 struct Order{
   address owner;
   uint amount;
   IPermit2.Pemit2 permit;
 }

  modifier isExpierd() {
    require(block.timestamp > expirationDate , "ERROR : Option has not expired");
    _;
  }

  using SafeMath for uint256;

 

  string PERMIT2_ORDER_TYPE = "";

  uint[] stageShare;

  address public immutable baseToken ;
  address public immutable quoteToken ;
  uint public immutable strikePriceBaseTokenRatio ;
  uint public immutable strikePriceQuoteTokenRatio ;
  uint public immutable expirationDate ;

  uint8 private immutable baseTokenDecimals; 

  uint totalShare;
  
  bool private _reentrancyGuard;
  IPermit2 public immutable permit2;


  mapping(address => OptionMaker) public optionMakers;

  constructor(address _baseToken, address _quoteToken, uint _strikePriceBaseTokenRatio , uint _strikePriceQuoteTokenRatio, uint _expirationDate , uint8 _baseTokenDecimals, IPermit2 _permit2) ERC20("AmericanOption", "EOPT") ERC20Permit("AmericanOption") {
   
    baseToken = _baseToken;
    quoteToken = _quoteToken;
    strikePriceBaseTokenRatio = _strikePriceBaseTokenRatio;
    strikePriceQuoteTokenRatio = _strikePriceQuoteTokenRatio;
    expirationDate =_expirationDate;
    permit2 = _permit2;
    baseTokenDecimals= _baseTokenDecimals;
  }

  function decimals() override public view returns (uint8) {
      return baseTokenDecimals;
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
    totalShare += order.amount;

    optionMakers[order.owner].totalShare += order.amount;

    optionMakers[order.owner].issuances.push(OptionInfo(
      order.amount , 
      uint32(stageShare.length)
    ));
    
  

  }




  function exercise(Order memory order) external nonReentrant {

    uint amount = order.amount;

    order.amount = order.amount.mul(strikePriceQuoteTokenRatio).div(strikePriceBaseTokenRatio);

    _transferTokens(order);
    
    stageShare.push(order.amount.mul(10 ** decimals()).div(totalSupply()));

    _burn(order.owner, amount);


  }

  function collectQuoteToken(address recipient) external nonReentrant {

   uint collectAmount ;
   
   for (uint i = 0 ; i < optionMakers[msg.sender].issuances.length ; i++  ){
     
     for (uint j = optionMakers[msg.sender].issuances[i].stageJoined ; j< stageShare.length ; j++){

      collectAmount += optionMakers[msg.sender].issuances[i].share.mul(stageShare[j]).div(10 ** decimals());

      optionMakers[msg.sender].issuances[i].share = optionMakers[msg.sender].issuances[i].share.sub(collectAmount.mul(strikePriceBaseTokenRatio).div(strikePriceQuoteTokenRatio));

     }

    collectAmount -= optionMakers[msg.sender].collected;

    IERC20(quoteToken).transfer(recipient, collectAmount);

    optionMakers[msg.sender].collected += collectAmount;

   }
  }

  function collect(address recipient) external nonReentrant isExpierd {

    uint baseTokenAmount = totalSupply().mul(optionMakers[msg.sender].totalShare).div(totalShare);
    IERC20(baseToken).transfer(recipient, baseTokenAmount);

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