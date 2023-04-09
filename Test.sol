// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

contract Test {
    

    function getE() external payable returns(uint256) {
        uint256 w = msg.value;

        uint256 e = w / 10e8;

        return e;
    }

}