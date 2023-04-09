// SPDX-License-Identifier: MIT

// 与npm版本规范相同, 既不允许低于0.7.0 版本的编译器编译， 也不允许高于（包含） 0.8.0 版本的编译器编译
pragma solidity ^0.7.0;

/// @title helloworld
/// @author cqyang
/// @notice 测试用, 返回"hello world"
/// @dev 测试用
contract HelloWorldContract {

    /// @dev 状态变量
    string internal str = "hello world!";

    /**
     @notice hello函数
     @dev hello函数 会返回状态变量str
     @return string str
    */
    function helloWorld() external view returns(string memory) {
        return str;
    }
}