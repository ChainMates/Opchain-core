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

contract Broker is OrderBook, IBroker, ReentrancyGuard {
    /// @notice permit2 address used for token transfers and signature verification
    IPermit2 public immutable permit2;
    using SafeMath for uint256;
    using Permit2Lib for MatchedOrder;

    constructor(IPermit2 _permit2) {
        permit2 = _permit2;
    }

    function executeOrder(
        MatchedOrder memory matchedOrder
    ) external nonReentrant {
        require(
            _checkOrderFeasibility(matchedOrder),
            "ERROR : low balance or allowance error"
        );

        require(_checkOrdersValidity(matchedOrder), "ERROR : validation error");

        require(_checkOrdersFairness(matchedOrder), "ERROR : fairness error");

        uint matchedAmount = min(
            matchedOrder.makerOptionAmount,
            matchedOrder.takerOptionAmount
        );
        uint permiumAmount = matchedAmount
            .mul(matchedOrder.makerPermiumRatio)
            .div(
                IOption(matchedOrder.optionContractAddress)
                    .strikePriceDenominator()
            );

        if (
            IERC20(matchedOrder.optionContractAddress).balanceOf(
                matchedOrder.makerAddress
            ) >= matchedAmount
        )
            IOption(matchedOrder.optionContractAddress).brokerSwap(
                matchedOrder.makerAddress,
                matchedOrder.takerAddress,
                matchedAmount
            );
        else
            IOption(matchedOrder.optionContractAddress).issue(
                matchedOrder.makerAddress,
                matchedOrder.takerAddress,
                matchedAmount
            );

        IERC20(IOption(matchedOrder.optionContractAddress).baseToken())
            .transferFrom(
                matchedOrder.takerAddress,
                matchedOrder.makerAddress,
                permiumAmount
            );

        _updateOrderBook(matchedOrder, matchedAmount);
    }

    function _checkOrderFeasibility(
        MatchedOrder memory _matchedOrder
    ) internal returns (bool) {
        bool isMakerOrderFeasible;

        if (
            IERC20(_matchedOrder.optionContractAddress).balanceOf(
                _matchedOrder.makerAddress
            ) >= _matchedOrder.makerOptionAmount
        ) isMakerOrderFeasible = true;
        else
            isMakerOrderFeasible = _ValidateAndPermitOrder(
                _matchedOrder.makerAddress,
                _matchedOrder.optionContractAddress,
                IOption(_matchedOrder.optionContractAddress).baseToken(),
                _matchedOrder.makerOptionAmount,
                _matchedOrder.toPermitSingle(true),
                _matchedOrder.makerSignature
            );

        uint takerAmount = _matchedOrder
            .takerOptionAmount
            .mul(_matchedOrder.takerPermiumRatio)
            .div(
                IOption(_matchedOrder.optionContractAddress)
                    .strikePriceDenominator()
            );
        bool isTakerOrderFeasible = _ValidateAndPermitOrder(
            _matchedOrder.takerAddress,
            address(this),
            IOption(_matchedOrder.optionContractAddress).quoteToken(),
            takerAmount,
            _matchedOrder.toPermitSingle(false),
            _matchedOrder.takerSignature
        );

        return (isMakerOrderFeasible && isTakerOrderFeasible);
    }

    function _checkOrdersValidity(
        MatchedOrder memory _matchedOrder
    ) internal view returns (bool) {
        bytes32 makerOrderHash = _hash(
            _matchedOrder.makerAddress,
            Order(
                _matchedOrder.makerOrderID,
                true,
                _matchedOrder.makerOptionAmount,
                _matchedOrder.makerPermiumRatio,
                _matchedOrder.makerDeadline,
                _matchedOrder.makerNonce,
                _matchedOrder.makerSignature,
                _matchedOrder.optionContractAddress
            )
        );

        bytes32 takerOrderHash = _hash(
            _matchedOrder.takerAddress,
            Order(
                _matchedOrder.takerOrderID,
                false,
                _matchedOrder.takerOptionAmount,
                _matchedOrder.takerPermiumRatio,
                _matchedOrder.takerDeadline,
                _matchedOrder.takerNonce,
                _matchedOrder.takerSignature,
                _matchedOrder.optionContractAddress
            )
        );

        bool isOrdersExpired = (_matchedOrder.makerDeadline <
            block.timestamp) || (_matchedOrder.takerDeadline < block.timestamp);
        bool isOrdersValid = (orderBook[_matchedOrder.makerOrderID] ==
            makerOrderHash &&
            orderBook[_matchedOrder.takerOrderID] == takerOrderHash);

        return (!isOrdersExpired && isOrdersValid);
    }

    function _checkOrdersFairness(
        MatchedOrder memory _matchedOrder
    ) internal pure returns (bool) {
        return ((_matchedOrder.makerPermiumRatio <=
            _matchedOrder.takerPermiumRatio) ||
            (_matchedOrder.makerOptionAmount ==
                _matchedOrder.takerOptionAmount));
    }

    function _ValidateAndPermitOrder(
        address _owner,
        address _spender,
        address _token,
        uint256 _amount,
        IPermit2.PermitSingle memory _permitSingle,
        bytes memory _signature
    ) internal returns (bool) {
        bool isTransactionValid;
        uint256 userBalance = IERC20(_token).balanceOf(_owner);
        uint256 userAllowance = IERC20(_token).allowance(_owner, _spender);

        if (userBalance >= _amount) {
            if (userAllowance >= _amount) isTransactionValid = true;
            else {
                permit2.permit(_owner, _permitSingle, _signature);
                userAllowance = IERC20(_token).allowance(_owner, address(this));
                if (userAllowance >= _amount) isTransactionValid = true;
            }
        }
        return isTransactionValid;
    }

    function _updateOrderBook(
        MatchedOrder memory matchedOrder,
        uint matchedAmount
    ) internal {
        if (matchedOrder.makerOptionAmount == matchedAmount) {
            orderBook[matchedOrder.makerOrderID] = bytes32(0);
            emit orderDeleted(matchedOrder.makerOrderID);

            orderBook[matchedOrder.takerOrderID] = keccak256(
                abi.encode(
                    matchedOrder.takerAddress,
                    matchedOrder.takerOrderID,
                    false,
                    (matchedOrder.takerOptionAmount - matchedAmount),
                    matchedOrder.takerPermiumRatio,
                    matchedOrder.takerDeadline,
                    matchedOrder.takerNonce,
                    matchedOrder.takerSignature,
                    matchedOrder.optionContractAddress
                )
            );
            emit orderUpdated(
                matchedOrder.takerAddress,
                Order(
                    matchedOrder.takerOrderID,
                    false,
                    (matchedOrder.takerOptionAmount - matchedAmount),
                    matchedOrder.takerPermiumRatio,
                    matchedOrder.takerDeadline,
                    matchedOrder.takerNonce,
                    matchedOrder.takerSignature,
                    matchedOrder.optionContractAddress
                )
            );
        } else {
            orderBook[matchedOrder.makerOrderID] = keccak256(
                abi.encode(
                    matchedOrder.makerAddress,
                    matchedOrder.makerOrderID,
                    true,
                    (matchedOrder.makerOptionAmount - matchedAmount),
                    matchedOrder.makerPermiumRatio,
                    matchedOrder.makerDeadline,
                    matchedOrder.makerNonce,
                    matchedOrder.makerSignature,
                    matchedOrder.optionContractAddress
                )
            );
            emit orderUpdated(
                matchedOrder.makerAddress,
                Order(
                    matchedOrder.makerOrderID,
                    true,
                    (matchedOrder.makerOptionAmount - matchedAmount),
                    matchedOrder.makerPermiumRatio,
                    matchedOrder.makerDeadline,
                    matchedOrder.makerNonce,
                    matchedOrder.makerSignature,
                    matchedOrder.optionContractAddress
                )
            );

            orderBook[matchedOrder.takerOrderID] = bytes32(0);
            emit orderDeleted(matchedOrder.takerOrderID);
        }
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a <= b ? a : b;
    }
}
