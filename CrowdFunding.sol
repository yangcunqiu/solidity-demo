// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

/// @title 众筹合约
/// @notice xx众筹合约, 达到众筹目标后合约关闭, 不再接收以太币. 到了截止日期众筹目标没有达成, 允许资助者取回资助金额
contract CrowdFunding {
    /// @notice 截止时间, 如果到了截止日期众筹目标没有达成, 允许资助者取回资助金额
    uint256 public immutable deadline;
    /// @notice 众筹合约是否可用, false时合约不可用, 不再接受以太币
    bool public available = true;
    /// @notice 受益人 不可修改. 众筹目标达成后, 众筹资金将全部发送给受益人地址
    address payable public immutable beneficiary;
    /// @notice 预计募集资金 wei 不可修改
    uint256 public immutable fundingGoal;
    /// @notice 合约当前募集到的金额
    uint256 public fundingAmount;
    /// @notice 资助者信息
    mapping(address => uint256) public funders;
    /// @dev 记录资助者在funders中是否存在
    mapping(address => bool) funderInsertFlag;
    /// @dev 记录资助者列表
    address[] funderList;

    /// @notice 当前合约金额变动都会触发此事件
    event balanceLog(string menthod, string tag, address from, address to, uint256 amount);

    /// @dev 通过构造函数在合约部署时设置 受益人 众筹金额.
    constructor(address payable _beneficiary, uint256 _fundingGoal, uint256 _duration) {
        beneficiary = _beneficiary;
        fundingGoal = _fundingGoal;
        deadline = block.timestamp + _duration;
    }

    function funding() external payable{
        emit balanceLog("funding", "add", msg.sender, address(this), msg.value);
        // 判断当前合约是否不可用
        require(available, "fundingGoal reached, CrowdFunding is close");
        require(block.timestamp < deadline, "arrived deadline");
        if (msg.value <= 0) {
            return;
        }
        require(fundingAmount + msg.value > fundingAmount, "overflow error");
        
        // 记录资助者
        funders[msg.sender] += msg.value;
        if (!funderInsertFlag[msg.sender]) {
            funderInsertFlag[msg.sender] = true;
            funderList.push(msg.sender);
        }

        fundingAmount += msg.value;
        if (fundingAmount >= fundingGoal) {
            // 达到目标, 合约关闭
            available = false;
            // 发送全部以太币给受益者
            beneficiary.transfer(address(this).balance);
            emit balanceLog("withdraw", "sub", address(this), beneficiary, address(this).balance);
        }
    }

    function withdraw() external {
        require(available, "fundingGoal reached, CrowdFunding is close");
        require(block.timestamp >= deadline, "unarrived deadline");
        if (!funderInsertFlag[msg.sender]) {
            return;
        }
        // 返回资助者金额
        payable(msg.sender).transfer(funders[msg.sender]);
        // 资助者记录置为0
        funders[msg.sender] = 0;
        emit balanceLog("withdraw", "sub", address(this), msg.sender, funders[msg.sender]);
    }

    function getFunderCount() external view returns(uint256) {
        return funderList.length;
    }

    function getFunderList() external view returns(address[] memory) {
        return funderList;
    }
}