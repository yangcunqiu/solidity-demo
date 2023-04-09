// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

enum VoteLimitEnum {
    None, // 无限制, 任何地址都能投票
    Token, // 一个token投一票
    Allocation // 额外指定某些地址能投票
}

struct VoteInfo {
    uint256 id;
    // 投票创建者
    address owner;
    // 投票标题
    string title;
    // 投票主题列表
    Topic[] topics;
    // 投票截止时间
    uint256 deadline;
    // 是否到期
    bool expired;
    // 投票限制
    VoteLimitEnum voteLimit;
    // 额外指定可投票的地址
    address[] allocationAddr;
}

// 主题 struct
struct Topic {
    // 主题名称
    string name;
    // 如果主题是账户的话, 可以有地址
    address addr;
    // 得票数
    uint256 voteCount;
}

/// @title 投票平台
contract Vote {
    // 所有投票列表
    VoteInfo[] public voteInfoList;
    // 委托信息 mapping(VoteInfo.id => mapping(委托人 => 被委托人))
    mapping(uint256 => mapping(address => address)) public delegateMap;
    // 质押以太获取token的比值
    uint8 immutable ratio;
    // 持有token
    mapping(address => uint256) public tokenMap;

    // 合约余额变动事件 tag: 0 收到转账, 1 向别人转出
    event BalanceLog(uint8 tag, address indexed addr, uint256 value);
    // token变动事件 tag: 0 增加, 1 减少
    event TokenLog(uint8 tag, address indexed addr, uint256 value);
    // 创建投票事件
    event Create(uint256 indexed voteId, string indexed title);
    // 委托事件
    event Approve(uint256 indexed voteId, address indexed principal, address indexed respondent);
    // 撤销委托事件
    event Revoke(uint256 indexed voteId, address indexed principal, address indexed respondent);

    constructor(uint8 _ratio) {
        ratio = _ratio;
    }

    receive() external payable {
        emit BalanceLog(0, msg.sender, msg.value);
    }

    // 质押以太币, 获得token 以太:token = 1:100  
    function pledge() external payable {
        emit BalanceLog(0, msg.sender, msg.value);
        uint256 tokenCount = msg.value / 1 ether * ratio;
        tokenMap[msg.sender] += tokenCount;
        emit TokenLog(0, msg.sender, tokenCount);
    }
}