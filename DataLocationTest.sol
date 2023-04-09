// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

contract DataLocationTest {

    // 状态变量
    uint[] stateVar = [1, 4, 5];

    function foo() public {
        // case1: 从storage加载到memory
        uint[] memory y = stateVar;

        // case2: 从memory加载到storage
        y[0] = 12;
        y[1] = 20;
        y[2] = 24;

        // copy y 到 storage
        stateVar = y;

        // case3: 从storage加载到storage
        uint[] storage z = stateVar;

        z[0] = 38;
        z[1] = 89;
        z[2] = 72;

    }
}