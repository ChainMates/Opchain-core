//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IPermit2} from "./interface/IPermit2.sol";
import {IERC20} from "./interface/IERC20.sol";
import {SafeMath} from "./library/SafeMath.sol";

contract Broker {

    /// @notice permit2 address used for token transfers and signature verification
    IPermit2 public immutable permit2;

    constructor(IPermit2 _permit2) {
        permit2 = _permit2;
    }



    struct MatchedOrders {
        uint256 matchID;
        uint64 makerOrderID;
        uint64 takerOrderID;
        address makerUserAddress;
        address takerUserAddress;
        uint256 makerPermiumRatio;
        uint256 makerOptionAmount;
        uint256 takerPermiumRatio;
        uint256 takerOptionAmount;
        uint64 makerDeadline;
        uint64 takerDeadline;
        uint256 makerNonce;
        uint256 takerNonce;
        bytes makerSignature;
        bytes takerSignature;
        address optionContractAddress;
    }

    struct Order {
        uint256 orderID;
        uint64 deadline;
        uint256 nonce;
        uint256 permiumRatio;
        uint256 optionAmount;
        address optionContractAddress;
    }
}
