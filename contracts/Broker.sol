//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "./security/Ownable.sol";
import {SafeMath} from "./library/SafeMath.sol";
import {IERC20} from "./interface/IERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";


contract Broker {

   /// @notice permit2 address used for token transfers and signature verification

   IPermit2 public immutable permit2;

   constructor(IPermit2 _permit2) {
      permit2 = _permit2;
   }


 struct MatchedOrders {
    uint16 makerFeeRatio;
    uint16 takerFeeRatio;
    uint64 makerOrderID;
    uint64 takerOrderID;
    uint64 makerDeadline;
    uint64 takerDeadline;
    uint256 matchID;
    uint256 makerPermiumRatio;
    uint256 makerOptionRatio;
    uint256 takerPermiumRatio;
    uint256 takerOptionRatio;
    uint256 makerTotalOptionAmount;
    uint256 takerTotalPermiumAmount;
    address optionContractAddress;
    address makerUserAddress;
    address takerUserAddress;
    bytes makerSignature;
    bytes takerSignature;
 }

 struct Order {
    uint256 chainID;
    uint64 deadline;
    uint256 nonce;
    uint256 permiumRatio;
    uint256 optionRatio;
    address optionContractAddress;
 }  



}