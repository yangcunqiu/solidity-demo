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
    mapping(uint256 => Topic) topics;
    // 投票自增id
    uint256 topicIndex;
    // 投票持续时间
    uint256 duration;
    // 投票截止时间 0 表示不限
    uint256 deadline;
    // 投票限制
    VoteLimitEnum voteLimit;
    // 额外指定可投票的地址  voteLimit = Allocation才有用
    address[] allocationAddrs;
    // 投票是否开始 默认没开始
    bool started; 
}

// 主题 struct
struct Topic {
    // 主题名称
    string name;
    // 得票数
    uint256 voteCount;
}

/// @title 投票平台
contract Vote {
    // 所有投票列表
    mapping(uint256 => VoteInfo) public voteInfoMap;
    // 投票自增id
    uint256 voteIndex;
    // 委托信息 mapping(VoteInfo.id => mapping(委托人 => 被委托人))
    mapping(uint256 => mapping(address => address)) public delegateMap;
    // 质押以太获取token的比值
    uint8 immutable ratio;
    // 持有token
    mapping(address => uint256) public tokenMap;
    // 记录投票地址记录
    mapping(uint256 => mapping(address => bool)) public voteAddrMap;
    // 记录投票主题地址记录
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public voteTopicAddrMap;
    // 记录地址投票主题记录
    mapping(address => mapping(uint256 => mapping(uint256 => bool))) public addrVoteTopicMap;

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

    // 校验谁能创建投票
    modifier CreateVotePower() {
        // 必须有token才能创建投票
        require(tokenMap[msg.sender] > 0, "token is zero");
        _;
    }

    // 校验投票是否存在
    modifier voteExist(uint256 _voteInfoId) {
        require(_voteInfoId <= voteIndex, "vote is not exist");
        _;
    }

    // 校验主题是否存在
    modifier topicExist(uint256 _voteInfoId, uint256 _topicId) {
        require(_topicId <= voteInfoMap[_voteInfoId].topicIndex, "topic is not exist");
        _;
    }

    // 校验谁能操作这个投票
    modifier voteOperatePower(uint256 _voteInfoId) {
        require(voteInfoMap[_voteInfoId].owner == msg.sender, "no operation permission");
        _;
    }

    // 校验投票是否过期
    modifier voteDeadline(uint256 _voteInfoId) {
        require(voteInfoMap[_voteInfoId].deadline == 0 || block.timestamp <= voteInfoMap[_voteInfoId].deadline, "vote is expired");
        _;
    }

    // 校验投票是否可用
    modifier voteStarted(uint256 _voteInfoId) {
        require(voteInfoMap[_voteInfoId].started, "vote is not start");
        _;
    }

    // 校验投票是否不可用
    modifier voteNotStarted(uint256 _voteInfoId) {
        require(!voteInfoMap[_voteInfoId].started, "vote is starting");
        _;
    }

    // 质押以太币, 获得token 以太:token = 1:100  
    function pledge() external payable {
        emit BalanceLog(0, msg.sender, msg.value);
        uint256 tokenCount = msg.value / 1 ether * ratio;
        tokenMap[msg.sender] += tokenCount;
        emit TokenLog(0, msg.sender, tokenCount);
    }

    // 创建一个投票
    function createVote(string memory _title, uint256 _duration, VoteLimitEnum _voteLimit, address[] memory _allocationAddrs) 
        CreateVotePower 
        external 
        returns(uint256 voteInfoId)
    {   
        VoteInfo storage voteInfo = voteInfoMap[voteIndex];
        voteInfo.id = voteIndex;
        voteInfo.owner = msg.sender;
        voteInfo.title = _title;
        voteInfo.duration = _duration;
        voteInfo.voteLimit = _voteLimit;
        voteInfo.allocationAddrs = _allocationAddrs;
        voteInfo.started = false;
        return voteIndex++;
    }

    // 为投票添加主题
    function addTopicList(uint256 _voteInfoId, string[] memory _nameList) 
        voteExist(_voteInfoId) 
        voteOperatePower(_voteInfoId)
        voteNotStarted(_voteInfoId)
        external 
     {
        VoteInfo storage voteInfo = voteInfoMap[_voteInfoId];
        for (uint256 i = 0; i < _nameList.length; i++) {
            Topic memory t = Topic({
                name: _nameList[i],
                voteCount: 0
            });

            voteInfo.topics[voteInfo.topicIndex] = t;
            voteInfo.topicIndex++;
        }
    }

    // 开始投票
    function startVote(uint256 _voteInfoId) voteExist(_voteInfoId) voteOperatePower(_voteInfoId) voteDeadline(_voteInfoId) public {
        VoteInfo storage voteInfo = voteInfoMap[_voteInfoId];
        // 是否已经开始
        require(!voteInfo.started, "vote is starting");
        // 是否有主题
        require(voteInfo.topicIndex > 0, "vote not topic");
        voteInfo.deadline = voteInfo.duration == 0 ? 0 : block.timestamp + voteInfo.duration;
        voteInfo.started = true;
    }

    // 投票
    function vote(uint256 _voteInfoId, uint256 _topicId) 
        voteExist(_voteInfoId) 
        topicExist(_voteInfoId, _topicId) 
        voteDeadline(_voteInfoId)
        voteStarted(_voteInfoId)
        external 
    {
        // 校验是否已经投过票 只能投一次 
        require(!voteAddrMap[_voteInfoId][msg.sender], "address is voted");
        if (voteInfoMap[_voteInfoId].voteLimit == VoteLimitEnum.Token) {
            // 有token才能投票
            require(tokenMap[msg.sender] > 0, "token is zero");
        } else if (voteInfoMap[_voteInfoId].voteLimit == VoteLimitEnum.Allocation) {
            // 额外指定地址
            require(containAddr(msg.sender, voteInfoMap[_voteInfoId].allocationAddrs), "not allocation address");
        }

        // 记录
        voteAddrMap[_voteInfoId][msg.sender] = true;
        
        // 票数+1
        voteInfoMap[_voteInfoId].topics[_topicId].voteCount++;
        // 投票记录
        voteTopicAddrMap[_voteInfoId][_topicId][msg.sender] = true;
        addrVoteTopicMap[msg.sender][_voteInfoId][_topicId] = true;
    }

    function containAddr(address addr, address[] memory addrList) private pure returns(bool isContain) {
        for (uint256 i = 0; i < addrList.length; i++) {
            if (addr == addrList[i]) {
                return true;
            }
        }
    }

    // 获取投票主题
    function getTopicListByVoteId(uint256 _voteInfoId) voteExist(_voteInfoId) external view returns(Topic[] memory) {
        VoteInfo storage voteInfo = voteInfoMap[_voteInfoId];
        Topic[] memory topicArr = new Topic[](voteInfo.topicIndex);
        for (uint256 i = 0; i < voteInfo.topicIndex; i++) {
            topicArr[i] = voteInfo.topics[i];
        }
        return topicArr;
    }
}