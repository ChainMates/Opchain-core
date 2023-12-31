//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IPermit2} from "./IPermit2.sol";

interface IBroker {
    struct MatchedOrder {
        uint256 matchID;
        uint64 makerOrderID;
        uint64 takerOrderID;
        address makerAddress;
        address takerAddress;
        uint256 makerPermiumRatio;
        uint256 makerOptionAmount;
        uint256 takerPermiumRatio;
        uint256 takerOptionAmount;
        uint48 makerDeadline;
        uint48 takerDeadline;
        uint48 makerNonce;
        uint48 takerNonce;
        bytes makerSignature;
        bytes takerSignature;
        address optionContractAddress;
    }

    function executeOrder(MatchedOrder memory matchedOrder , IPermit2.PermitSingle calldata makerPermitSingle ,IPermit2.PermitSingle calldata takerPermitSingle
) external;
}
