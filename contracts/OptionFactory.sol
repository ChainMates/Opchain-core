//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {EuropeanOption} from "./EuropeanOption.sol"; // European option contract

import {AmericanOption} from "./AmericanOption.sol"; // American option contract 

import {IERC20} from "./interface/IERC20.sol"; // ERC20 interface

import {IPermit2} from "./interface/IPermit2.sol"; // Permit2 interface

/// @title OptionFactory contract
/// @author @hdldr
/// @notice Creates customizable European and American options
contract OptionFactory {

  struct Option {
    address baseToken; // Token for buying option
    address quoteToken; // Token used to pay premium
    uint strikePriceRatio; // Multiplier for strike price 
    uint expirationDate; // Expiry date
    bool isAmerican; // Option style
  }

  IPermit2 public immutable permit2; // Permit2 contract

  address public broker; // Broker address

  mapping(bytes32 => address) public getOptions; // Existing options

  /// @param _broker Broker address
  /// @param _permit2 Permit2 contract
  constructor(address _broker, IPermit2 _permit2) {
    broker = _broker;
    permit2 = _permit2;
  }

  /// @notice Emitted when new option created
  /// @param baseToken Option base token
  /// @param quoteToken Quote token for premium
  /// @param strikePriceRatio Strike price multiplier 
  /// @param expirationDate Expiry date
  /// @param isAmerican Option style
  /// @param optionAddress Created option address
  event OptionCreated(
    address indexed baseToken,
    address indexed quoteToken,
    uint strikePriceRatio,
    uint expirationDate, 
    bool isAmerican,
    address optionAddress
  );

  /// @notice Create new option contract
  /// @param option Option parameters
  /// @return optionAddress Created option address
    function createOption(
        Option memory option
    ) external returns (address optionAddress) {
    // Input validation
        require(
            option.baseToken != option.quoteToken,
            "ERROR : identical addresses"
        );
        require(
            option.baseToken != address(0) || option.quoteToken != address(0),
            "ERROR : zero address"
        );
        // Compute option hash
        bytes32 hash = keccak256(
            abi.encode(
                option.baseToken,
                option.quoteToken,
                option.strikePriceRatio,
                option.expirationDate,
                option.isAmerican
            )
        );

        require(getOptions[hash] == address(0), "ERROR: option already exists");

        // Deploy new contract
        if (option.isAmerican)
            optionAddress = address(
                new AmericanOption(
                    option.baseToken,
                    option.quoteToken,
                    option.strikePriceRatio,
                    option.expirationDate,
                    IERC20(option.baseToken).decimals(),
                    permit2,
                    broker
                )
            );
        else
            optionAddress = address(
                new EuropeanOption(
                    option.baseToken,
                    option.quoteToken,
                    option.strikePriceRatio,
                    option.expirationDate,
                    IERC20(option.baseToken).decimals(),
                    permit2,
                    broker
                )
            );

        getOptions[hash] = optionAddress;

        // Emit event
        emit OptionCreated(
            option.baseToken,
            option.quoteToken,
            option.strikePriceRatio,
            option.expirationDate,
            option.isAmerican,
            optionAddress
        );

        return optionAddress;
    }
}

