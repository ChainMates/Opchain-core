//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {EuropeanOption} from "./EuropeanOption.sol";
import {AmericanOption} from "./AmericanOption.sol";
import {IERC20} from "./interface/IERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";

contract OptionFactory {

    struct Option {
        address baseToken;
        address quoteToken;
        uint strikePriceRatio;
        uint expirationDate;
        bool isAmerican;
    }

    IPermit2 public immutable permit2;
    address public broker;


    mapping(bytes32 => address) public getOptions;

    constructor(address _broker, IPermit2 _permit2 ) {
        broker = _broker;
        permit2 = _permit2;
    }

    event OptionCreated(
        address indexed baseToken,
        address indexed quoteToken,
        uint strikePriceRatio,
        uint expirationDate,
        bool isAmerican,
        address OptionAddress
    );

    function createOption(
        Option memory option
    ) external returns(address createdOption) {
        require(
            option.baseToken != option.quoteToken,
            "ERROR : identical addresses"
        );
        require(
            option.baseToken != address(0) || option.quoteToken != address(0),
            "ERROR : zero address"
        );

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

        if (option.isAmerican)
            createdOption = address(
                new AmericanOption(
                    option.baseToken,
                    option.quoteToken,
                    option.strikePriceRatio,
                    option.expirationDate,
                    IERC20(option.baseToken).decimals(),
                    permit2 ,
                    broker
                )
            );
        else
            createdOption = address(
                new EuropeanOption(
                    option.baseToken,
                    option.quoteToken,
                    option.strikePriceRatio,
                    option.expirationDate,
                    IERC20(option.baseToken).decimals(),
                    permit2 ,
                    broker
                )
            );

        getOptions[hash] = createdOption;

        emit OptionCreated(
            option.baseToken,
            option.quoteToken,
            option.strikePriceRatio,
            option.expirationDate,
            option.isAmerican,
            createdOption
        );
    }
}
