//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IPermit2} from "./interface/IPermit2.sol";
import {Permit2Lib} from "./library/Permit2Lib.sol";
import {IBroker} from "./interface/IBroker.sol";
import {IOption} from "./interface/IOption.sol";
import {IERC20} from "./interface/IERC20.sol";
import {SafeMath} from "./library/SafeMath.sol";
import {OrderBook} from "./OrderBook.sol";
import {ReentrancyGuard} from "solmate/src/utils/ReentrancyGuard.sol";

contract Broker is OrderBook , IBroker , ReentrancyGuard {
    /// @notice permit2 address used for token transfers and signature verification
    IPermit2 public immutable permit2;
    using SafeMath for uint256;
    using Permit2Lib for MatchedOrder;

    constructor(IPermit2 _permit2) {
        permit2 = _permit2;
    }



    function executeOrder(MatchedOrder memory matchedOrder) external nonReentrant {
     
        require(_checkOrderFeasibility(matchedOrder) , "ERROR : low balance or allowance");

        require(_checkOrdersValidity(matchedOrder) , "ERROR : orders not valid");



    } 


    function _checkOrderFeasibility(MatchedOrder memory matchedOrder) internal returns (bool) {

        bool isMakerOrderFeasible;

        if (IOption(matchedOrder.optionContractAddress).balanceOf(matchedOrder.makerAddress) >= matchedOrder.makerOptionAmount) 
            isMakerOrderFeasible = true;
        else
         isMakerOrderFeasible = _ValidateAndPermitOrder(matchedOrder.makerAddress, IOption(matchedOrder.optionContractAddress).baseToken() ,matchedOrder.makerOptionAmount , matchedOrder.toPermitSingle(true) , matchedOrder.makerSignature);
              
        uint takerAmount = matchedOrder.takerOptionAmount.mul(matchedOrder.takerPermiumRatio).div(IOption(matchedOrder.optionContractAddress).strikePriceDenominator());
        bool isTakerOrderFeasible = _ValidateAndPermitOrder(matchedOrder.takerAddress, IOption(matchedOrder.optionContractAddress).quoteToken() , takerAmount , matchedOrder.toPermitSingle(false) , matchedOrder.takerSignature);
        
        return (isMakerOrderFeasible && isTakerOrderFeasible);

    }

    function _checkOrdersValidity(MatchedOrder memory matchedOrder) internal view returns(bool){

        bytes32 makerOrderHash = _hash(
            matchedOrder.makerAddress, Order(
            matchedOrder.makerOrderID,
            true,
            matchedOrder.makerOptionAmount,
            matchedOrder.makerPermiumRatio,
            matchedOrder.makerDeadline,
            matchedOrder.makerNonce,
            matchedOrder.makerSignature,
            matchedOrder.optionContractAddress
        ));

        bytes32 takerOrderHash = _hash(
            matchedOrder.takerAddress, Order(
            matchedOrder.takerOrderID,
            false,
            matchedOrder.takerOptionAmount,
            matchedOrder.takerPermiumRatio,
            matchedOrder.takerDeadline,
            matchedOrder.takerNonce,
            matchedOrder.takerSignature,
            matchedOrder.optionContractAddress
        ));

        bool isOrdersExpired = (matchedOrder.makerDeadline < block.timestamp) || (matchedOrder.takerDeadline < block.timestamp);
        bool isOrdersValid = (orderBook[matchedOrder.makerOrderID] == makerOrderHash && orderBook[matchedOrder.takerOrderID] == takerOrderHash );

        return (!isOrdersExpired && isOrdersValid);
    }


    function _ValidateAndPermitOrder(
        address _owner,
        address _token,
        uint256 _amount,
        IPermit2.PermitSingle memory _permitSingle,
        bytes memory _signature
    ) internal returns (bool) {
        bool isTransactionValid;
        uint256 userBalance = IERC20(_token).balanceOf(_owner);
        uint256 userAllowance = IERC20(_token).allowance(
            _owner,
            address(this)
        );


        if (userBalance >= _amount) {
            if(userAllowance >= _amount)
            isTransactionValid = true;
            else {
            permit2.permit(_owner, _permitSingle, _signature);   
            userAllowance = IERC20(_token).allowance(_owner, address(this));
            if(userAllowance >= _amount)
            isTransactionValid = true;    
            }
        }
        return isTransactionValid;
    }

}
