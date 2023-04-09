// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

/// @title 多签钱包
/// @dev 接收多个owner签名的钱包, 除了存钱外其他操作都需要由owner触发, 所有交易必须获取>=x数量的签名才能完成
contract MultiSignWallet {

    /// @dev owner
    address[] public owners;
    /// @dev 是否是owner
    mapping(address => bool) public isOwner;
    /// @dev 最少达到requireCount个签名才能完成交易
    uint256 public requireCount;
    /// @dev 交易对象
    struct Transaction {
        /// @dev 交易id
        uint256 txId;
        address from;
        address to;
        uint256 amount;
        bytes data;
        bool complete;
    }
    /// @dev 交易列表
    Transaction[] public txs;
    /// @dev 记录交易被哪些地址批准过
    mapping(uint256 => mapping(address => bool)) public txApproved;

    event Deposit(address indexed from, uint256 amount);
    event Submit(uint256 indexed txId);
    event Approve(address indexed owner, uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);

    // 函数修改器 指定在某个函数上, 作用类似于java的切面
    modifier onlyOwner() {
        require(isOwner[msg.sender], "only owner");
        // 开始执行函数本身, 类似于gin中的c.next
        _;
    }

    modifier isExist(uint256 txId) {
        require(txId < txs.length, "transaction not exist");
        _;
    }

    modifier notApprove(uint256 txId) {
        require(!txApproved[txId][msg.sender], "transaction approved");
        _;
    }

    modifier isApproved(uint256 txId) {
        require(txApproved[txId][msg.sender], "transaction not approve");
        _;
    }

    modifier notCompleted(uint256 txId) {
        require(!txs[txId].complete, "transaction completed");
        _;
    }


    /// @dev 构造函数构建owners和requireCount
    constructor(address[] memory _owners, uint256 _requireCount) {
        require(_owners.length > 0, "owner not empty");
        require(_requireCount > 0 && _requireCount <= _owners.length, "illegal _requireCount");

        // 校验owner        
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "illegal owner address");
            // 一开始所有的owner都应该是false, 循环中出现true说明肯定是重复的
            require(!isOwner[owner], "repetition owner address");
            isOwner[owner] = true;
            owners.push(owner);
        }

        requireCount = _requireCount;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function getBalance() external view returns(uint256) {
        return address(this).balance;
    }
    
    // 发起交易
    function submit(address _to, uint256 _amount, bytes calldata _data) external onlyOwner returns(uint256 txId) {
        txId = txs.length;
        txs.push(
            Transaction({txId: txId, from: address(this), to: _to, amount: _amount, data: _data, complete: false})
        );
        emit Submit(txId);
    }

    // 授权交易
    function approve(uint256 _txId) external onlyOwner isExist(_txId) notCompleted(_txId) notApprove(_txId) {
        txApproved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    // 撤销授权
    function revoke(uint256 _txId) external onlyOwner isExist(_txId) notCompleted(_txId) isApproved(_txId) {
        txApproved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

    // 执行交易
    function execute(uint256 _txId) external onlyOwner isExist(_txId) notCompleted(_txId) {
        require(getTxApprovedCount(_txId) >= requireCount, "tx not satisfy requireCount");
        // 取出交易
        Transaction storage tx_ = txs[_txId];
        tx_.complete = true;
        (bool success,) = tx_.to.call{value: tx_.amount}(tx_.data);
        require(success, "tx execute fail");
        emit Execute(_txId);
    }

    // 查询交易已被授权的数量
    function getTxApprovedCount(uint256 _txId) public view returns(uint256 count) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (txApproved[_txId][owners[i]]) {
                count += 1;
            }
        }
    }
}