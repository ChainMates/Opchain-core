//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IPermit2} from "./interface/IPermit2.sol";
import {IBroker} from "./interface/IBroker.sol";
import {IOption} from "./interface/IOption.sol";
import {IERC20} from "./interface/IERC20.sol";
import {SafeMath} from "./library/SafeMath.sol";
import {OrderBook} from "./OrderBook.sol";
import {ReentrancyGuard} from "solmate/src/utils/ReentrancyGuard.sol";
import "hardhat/console.sol";

/**
 * @title Broker contract for executing matched orders
 * @dev This contract implements the IBroker interface and inherits from the OrderBook contract
 */
contract Broker is OrderBook, IBroker, ReentrancyGuard {
    /// @notice permit2 address used for token transfers and signature verification
    IPermit2 public immutable permit2;
    using SafeMath for uint256;
    /**
     * @dev Constructor for the Broker contract
     * @param _permit2 Address of the permit2 contract
     */
    constructor(IPermit2 _permit2) {
        permit2 = _permit2;
    }

    /**
     * @dev Function for executing a matched order
     * @param matchedOrder Struct containing details of the matched order
     * @param makerPermitSingle Struct containing permit details for the maker
     * @param takerPermitSingle Struct containing permit details for the taker
     */
    function executeOrder(
        MatchedOrder memory matchedOrder,
        IPermit2.PermitSingle calldata makerPermitSingle,
        IPermit2.PermitSingle calldata takerPermitSingle
    ) external nonReentrant {
        require(
            _checkOrderFeasibility(matchedOrder, makerPermitSingle, takerPermitSingle),
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

        permit2.transferFrom(
            matchedOrder.takerAddress,
            matchedOrder.makerAddress,
            uint160(permiumAmount),
            IOption(matchedOrder.optionContractAddress).quoteToken()
        );

        _updateOrderBook(matchedOrder, matchedAmount);
    }

    /**
     * @dev Function for checking the feasibility of the matched order
     * @param _matchedOrder Struct containing details of the matched order
     * @param _makerPermitSingle Struct containing permit details for the maker
     * @param _takerPermitSingle Struct containing permit details for the taker
     * @return bool Returns true if the matched order is feasible, false otherwise
     */
    function _checkOrderFeasibility(
        MatchedOrder memory _matchedOrder,
        IPermit2.PermitSingle calldata _makerPermitSingle,
        IPermit2.PermitSingle calldata _takerPermitSingle
    ) internal returns (bool) {
        bool isMakerOrderFeasible;
        address baseToken = IOption(_matchedOrder.optionContractAddress).baseToken();

        if (
            IERC20(_matchedOrder.optionContractAddress).balanceOf(
                _matchedOrder.makerAddress
            ) >= _matchedOrder.makerOptionAmount
        ) isMakerOrderFeasible = true;
        else
            isMakerOrderFeasible = _ValidateAndPermitOrder(
                _matchedOrder.makerAddress,
                _matchedOrder.optionContractAddress,
                baseToken,
                _matchedOrder.makerOptionAmount,
                _makerPermitSingle,
                _matchedOrder.makerSignature
            );

        uint takerAmount = _matchedOrder
            .takerOptionAmount
            .mul(_matchedOrder.takerPermiumRatio)
            .div(IOption(_matchedOrder.optionContractAddress).strikePriceDenominator());

        address quoteToken = IOption(_matchedOrder.optionContractAddress).quoteToken();

        bool isTakerOrderFeasible = _ValidateAndPermitOrder(
            _matchedOrder.takerAddress,
            address(this),
            quoteToken,
            takerAmount,
            _takerPermitSingle,
            _matchedOrder.takerSignature
        );

        return (isMakerOrderFeasible && isTakerOrderFeasible);
    }

    /**
     * @dev Function for checking the validity of the matched orders
     * @param _matchedOrder Struct containing details of the matched order
     * @return bool Returns true if the matched orders are valid, false otherwise
     */
    function _checkOrdersValidity(MatchedOrder memory _matchedOrder)
        internal
        view
        returns (bool)
    {
        bytes32 makerOrderHash = _hash(
            _matchedOrder.makerAddress,
            Order({
                orderID: _matchedOrder.makerOrderID,
                isMaker: true,
                optionAmount: _matchedOrder.makerOptionAmount,
                permiumRatio: _matchedOrder.makerPermiumRatio,
                deadline: _matchedOrder.makerDeadline,
                nonce: _matchedOrder.makerNonce,
                signature: _matchedOrder.makerSignature,
                optionContractAddress: _matchedOrder.optionContractAddress
            })
        );

        bytes32 takerOrderHash = _hash(
            _matchedOrder.takerAddress,
            Order({
                orderID: _matchedOrder.takerOrderID,
                isMaker: false,
                optionAmount: _matchedOrder.takerOptionAmount,
                permiumRatio: _matchedOrder.takerPermiumRatio,
                deadline: _matchedOrder.takerDeadline,
                nonce: _matchedOrder.takerNonce,
                signature: _matchedOrder.takerSignature,
                optionContractAddress: _matchedOrder.optionContractAddress
            })
        );

        bool isOrdersExpired =
            (_matchedOrder.makerDeadline < block.timestamp) ||
            (_matchedOrder.takerDeadline < block.timestamp);
        bool isOrdersValid =
            (orderBook[_matchedOrder.makerOrderID] == makerOrderHash &&
                orderBook[_matchedOrder.takerOrderID] == takerOrderHash);

        console.logBytes32(makerOrderHash);
        console.logBytes32(takerOrderHash);
        console.logBytes32(orderBook[_matchedOrder.makerOrderID]);
        console.logBytes32(orderBook[_matchedOrder.takerOrderID]);

        console.log(isOrdersExpired, isOrdersValid);

        return (!isOrdersExpired && isOrdersValid);
    }

    /**
     * @dev Function for checking the fairness of the matched orders
     * @param _matchedOrder Struct containing details of the matched order
     * @return bool Returns true if the matched orders are fair, false otherwise
     */
    function _checkOrdersFairness(MatchedOrder memory _matchedOrder)
        internal
        pure
        returns (bool)
    {
        return (
            (_matchedOrder.makerPermiumRatio <= _matchedOrder.takerPermiumRatio) ||
            (_matchedOrder.makerOptionAmount == _matchedOrder.takerOptionAmount)
        );
    }

    /**
     * @dev Function for validating and permitting an order
     * @param _owner Address of the owner of the order
     * @param _spender Address of the spender of the order
     * @param _token Address of the token used in the order
     * @param _amount Amount of the token used in the order
     * @param _permitSingle Struct containing permit details
     * @param _signature Signature of the permit
     * @return bool Returns true if the order is valid, false otherwise
     */
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
        (uint160 amount, uint48 expiration,) = permit2.allowance(_owner , _token , _spender);


        if (userBalance >= _amount) {
            if (amount >= _amount && expiration > block.timestamp) isTransactionValid = true;
            else {
                permit2.permit(_owner, _permitSingle, _signature);
                (amount, expiration, ) = permit2.allowance(_owner , _token , _spender);
                if (amount >= _amount && expiration > block.timestamp) isTransactionValid = true;
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

            if(matchedOrder.takerOptionAmount == matchedAmount){
             orderBook[matchedOrder.takerOrderID] = bytes32(0);
             emit orderDeleted(matchedOrder.takerOrderID);
            }else{

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
            }
 
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
