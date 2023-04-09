// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

/// @title 实现REC-20规范的合约
contract METH {
    /// @notice token名称
    string public name;
    /// @notice token简称
    string public symbol;
    /// @dev token精度
    uint8 public decimals;
    /// @notice token发行总量
    uint256 public totalSupply;

    /// @notice token已发行总量
    uint256 issuedTotal;
    uint256 factor = 10e18;

    /// @dev 保存每个地址内的token数量
    mapping(address => uint256) tokenMap;
    /// @dev 保存每个地址对其他地址的授权额度
    mapping(address => mapping(address => uint256)) approveMap;

    /// @notice token被转移时触发事件(包括转移金额为0)
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    /// @notice 授权触发事件
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor() {
        name = "My of ETH";
        symbol = "METH";
        decimals = 1;
        totalSupply = factor * 10 ** uint256(decimals);
    } 

    /// @notice 查询地址token数量
    /// @param _owner : 地址
    /// return token数量
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return tokenMap[_owner];
    }

    /// @notice 调用者 向另一个地址转账
    /// @param _to : 转账接收地址
    /// @param _value : 转账金额
    /// return 是否成功
    function transfer(address _to, uint256 _value) public returns (bool success) {
        return transferFrom(msg.sender, _to, _value);
    }

    /// @notice 从一个地址转账到另一个地址
    /// @param _from : 转账发起地址
    /// @param _to : 转账接收地址
    /// @param _value : 转账金额
    /// return 是否成功
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // 判断是否是当前调用者的一个转账
        if (msg.sender != _from) {
            // _from: 授权地址 msg.sender: 被授权地址
            // 判断调用者地址的被授权额度是否满足转账金额要求
            require(approveMap[_from][msg.sender] >= _value, "remaining not enough");
            // 判断_from地址余额是否充足
            require(tokenMap[_from] >= _value, "amount not enough");
            // 减少_from地址对调用者地址的授权额度
            approveMap[_from][msg.sender] -= _value;
        }

        return safeTransfer(_from, _to, _value);
    }

    /// @notice 调用者 向另一个地址授权额度
    /// @param _spender : 被授权地址
    /// @param _value : 授权额度
    /// return 是否成功
    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0), "error: address is 0x0");
        approveMap[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /// @notice 查询 授权地址 对 被授权地址 的额度
    /// @param _owner : 授权地址
    /// @param _spender : 被授权地址
    /// return 额度
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return approveMap[_owner][_spender];
    }

    /// @dev 合约转账
    /// @param from : 转账发起地址
    /// @param to : 转账接收地址
    /// @param value : 转账金额
    /// return 是否成功
    function safeTransfer(address from, address to, uint256 value) private returns(bool) {
        require(to != address(0), "error: address is 0x0");
        require(value > 0, "error: amount is zero");
        // 判断溢出
        require(tokenMap[to] + value >= tokenMap[to], "error: overflows");
        // 判断金额是否满足
        require(tokenMap[from] >= value, "amount not enough");
        tokenMap[from] -= value;
        tokenMap[to] += value;
        emit Transfer(from, to, value);
        return true;
    }


    /// @notice 质押eth
    /// @dev 质押eth, 增加token
    /// return 是否成功
    /// return token数量
    function pledge() public payable returns(bool success, uint256 value) {
        tokenMap[msg.sender] += msg.value;
        issuedTotal += msg.value;
        return (true, msg.value);
    }
    
    /// @notice 赎回
    /// @dev 赎回eth, 减少token
    /// return 是否成功
    /// return 赎回金额 wei
    function ransom(uint256 value) public returns(bool success, uint256 amount) {
        require(tokenMap[msg.sender] >= value, "amount not enough");
        tokenMap[msg.sender] -= value;
        payable(msg.sender).transfer(value);
        issuedTotal -= value;
        return (true, value);
    }

    function getIssuedTotal() public view returns(uint256) {
        return issuedTotal;
    }
}