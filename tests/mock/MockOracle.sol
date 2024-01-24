// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IMockOracle {
    function getPrice_e36(address _token) external view returns (uint price);
}

contract MockOracle is IMockOracle {
    uint public price;

    constructor(uint _price) {
        price = _price;
    }

    function getPrice_e36(address) external view returns (uint) {
        return price;
    }
}

contract MockInvalidOracle is IMockOracle {
    function getPrice_e36(address) external pure returns (uint) {
        revert();
    }
}
