// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IBroker} from "../interface/IBroker.sol";
import {IPermit2} from "../interface/IPermit2.sol";
import {IOption} from "../interface/IOption.sol";

/// @notice handling some permit2-specific encoding
library Permit2Lib {

    function toPermitSingle(IBroker.MatchedOrder memory matchedOrder , bool isMaker) internal view
        returns (IPermit2.PermitSingle memory permitSingle){

        if(isMaker){

        return IPermit2.PermitSingle({
            details : IPermit2.PermitDetails({
                token : IOption(matchedOrder.optionContractAddress).baseToken() ,
                amount : uint160(matchedOrder.makerOptionAmount),
                expiration : matchedOrder.makerDeadline ,
                nonce : matchedOrder.makerNonce
            }) , 
            spender : address(this) ,
            sigDeadline : matchedOrder.makerDeadline
        });

        }    
        
    }

}