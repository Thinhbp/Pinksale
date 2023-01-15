// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


import "./libraries/FullMath.sol";
import "./structs/PrivateSaleStructs.sol";

contract PrivateSale is Ownable, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;



    struct InvestInfo {
        address user;
        uint256 totalInvestment;
        bool refund;
    }


    mapping(address => bool) public adminAccounts;
    mapping(address => bool) public superAccounts;
    uint256 public privateSaleState; // 1 running||available, 2 finalize, 3 cancel



    modifier onlyWhitelistAdmin() {
        require(adminAccounts[msg.sender], "Only Admin");
        _;
    }

    modifier onlySuperAccount() {
        require(superAccounts[msg.sender], "Only Super");
        _;
    }

    function whiteListAdmins(address _user, bool _whiteList) public onlySuperAccount {
        adminAccounts[_user] = _whiteList;
    }

    modifier onlyRunning() {
        require(privateSaleState == 1, "Not available pool");
        _;
    }

    EnumerableSet.AddressSet private _investedUsers;

    mapping(address => InvestInfo) public investInfos; // user => amounts


    address payable public fundAddress;
    uint256 public fundPercent = 500;

    uint256 public constant ZOOM = 10_000;
    uint256 public penaltyFeePercent = 1000;
    address public signer;


    address public currency;
    uint256 public privateSaleType; //0 public, 1 whitelist, 2 public anti bot
    address public holdingToken;
    uint256 public holdingAmount;

    uint256 public softCap;
    uint256 public hardCap;
    uint256 public minInvest;
    uint256 public maxInvest;
    uint256 public startTime;
    uint256 public endTime;

    uint256 public tgeDate; // claim Date
    uint256 public tgeBps; // tge percent
    uint256 public cycle; // period after tge
    uint256 public cycleBps; // cycle percent

    uint256 public raisedAmount;
    uint256 public unlockedAmount;


    event Contribute(
        address indexed sender,
        uint256 indexed amount
    );

    event Finalize(
        address indexed sender,
        uint256 indexed state
    );

    event Cancel(
        address indexed sender,
        uint256 indexed state
    );

    event SetWhitelistUsers(
        address indexed sender,
        uint256 indexed state
    );

    event RemoveWhitelistUsers(
        address indexed sender,
        uint256 indexed state
    );


    event VestingClaim(
        uint256 indexed amounts,
        uint256 indexed remaimAmounts,
        uint256 claimAt
    );

    constructor(
        PrivateSaleStructs.DeployInfo memory _deployInfo,
        PrivateSaleStructs.PrivateSaleInfo memory _privateSaleInfo,
        PrivateSaleStructs.VestingInfo memory _vestingInfo

    ) {
        require(_privateSaleInfo.softCap > 0 && _privateSaleInfo.hardCap > 0 && _privateSaleInfo.softCap < _privateSaleInfo.hardCap, 'Invalid Cap');
        require(_privateSaleInfo.minInvest > 0 && _privateSaleInfo.maxInvest > 0 && _privateSaleInfo.minInvest < _privateSaleInfo.maxInvest, 'Invalid Buy Info');
        require(_privateSaleInfo.startTime > 0 && _privateSaleInfo.startTime < _privateSaleInfo.endTime, 'Invalid Time');
        require(_vestingInfo.cycle > 0, 'Invalid Cycle Time');
        require(_vestingInfo.tgeBps > 0 && _vestingInfo.cycleBps > 0 && _vestingInfo.tgeBps.add(_vestingInfo.cycleBps) <= ZOOM, 'Invalid Vesting Percent');


        currency = _privateSaleInfo.currency;
        privateSaleType = _privateSaleInfo.isWhitelist ? 1 : 0;
        softCap = _privateSaleInfo.softCap;
        hardCap = _privateSaleInfo.hardCap;
        minInvest = _privateSaleInfo.minInvest;
        maxInvest = _privateSaleInfo.maxInvest;
        startTime = _privateSaleInfo.startTime;
        endTime = _privateSaleInfo.endTime;

        tgeBps = _vestingInfo.tgeBps;
        cycle = _vestingInfo.cycle;
        cycleBps = _vestingInfo.cycleBps;

        privateSaleState = 1;
        fundAddress = _deployInfo.fundAddress;
        fundPercent = _deployInfo.fundPercent;
        penaltyFeePercent = _deployInfo.penaltyFeePercent;


        signer = _deployInfo.signer;
        superAccounts[_deployInfo.superAccount] = true;

        adminAccounts[_deployInfo.deployer] = true;
        adminAccounts[_deployInfo.superAccount] = true;

        transferOwnership(_deployInfo.deployer);
    }

    function setSigner(address _signer) public onlySuperAccount {
        require(_signer != address(0) && _signer != address(this), "Invalid address");
        signer = _signer;
    }

    function setPenaltyPercent(uint256 _penaltyFeePercent) public onlySuperAccount {
        penaltyFeePercent = _penaltyFeePercent;
    }

    function setFundAddress(
        address payable _fundAddress
    ) external whenNotPaused onlySuperAccount {
        require(_fundAddress != address(0) && _fundAddress != address(this), "Invalid address");
        fundAddress = _fundAddress;
    }

    function emergencyWithdrawPool(address _token, uint256 _amount) external onlySuperAccount {
        require(_amount > 0, 'Invalid amount');
        if (_token == address(0)) {
            payable(_msgSender()).transfer(_amount);
        }
        else {
            IERC20 token = IERC20(_token);
            token.safeTransfer(_msgSender(), _amount);
        }
    }

    function setWhitelistPool(uint256 _wlPool, address _holdingToken, uint256 _amount) external onlyWhitelistAdmin {
        require(_wlPool < 2 ||
            (_wlPool == 2 && _holdingToken != address(0) && IERC20(_holdingToken).totalSupply() > 0 && _amount > 0), 'Invalid setting');
        holdingToken = _holdingToken;
        holdingAmount = _amount;
        privateSaleType = _wlPool;
    }


    function contribute(uint256 _amount, bytes calldata _sig) external payable whenNotPaused onlyRunning {
        require(startTime <= block.timestamp && endTime >= block.timestamp, 'Invalid time');
        address user = _msgSender();

        if (privateSaleType == 1) {
            bytes32 message = prefixed(keccak256(abi.encodePacked(
                    _msgSender(),
                    address(this)
                )));
            require(recoverSigner(message, _sig) == signer, 'Not In Whitelist');
        } else if (privateSaleType == 2) {
            require(IERC20(holdingToken).balanceOf(user) >= holdingAmount, 'Insufficient holding');
        }
        InvestInfo storage joinInfo = investInfos[user];
        require(joinInfo.totalInvestment.add(_amount) >= minInvest && joinInfo.totalInvestment.add(_amount) <= maxInvest, 'Invalid amount');
        require(raisedAmount.add(_amount) <= hardCap, 'Meet hard cap');


        joinInfo.totalInvestment = joinInfo.totalInvestment.add(_amount);
        joinInfo.refund = false;
        joinInfo.user = user;

        raisedAmount = raisedAmount.add(_amount);
        _investedUsers.add(user);

        if (currency == address(0)) {
            require(msg.value >= _amount, 'Invalid Amount');
        } else {
            IERC20(currency).safeTransferFrom(_msgSender(), address(this), _amount);
        }

        emit Contribute(user, _amount);

    }


    function finalize() external onlyWhitelistAdmin onlyRunning {
        require(block.timestamp > startTime, 'Not start');
        require(fundAddress != address(0), 'Invalid fund');

        if (block.timestamp < endTime) {
            require(raisedAmount >= hardCap, 'Cant finalize');
        }
        if (block.timestamp >= endTime) {
            require(raisedAmount >= softCap, 'Not meet soft cap');
        }
        privateSaleState = 2;
        tgeDate = block.timestamp;
        emit Finalize(_msgSender(), privateSaleState);
    }

    function cancel() external onlyWhitelistAdmin onlyRunning {
        privateSaleState = 3;
        emit Cancel(_msgSender(), privateSaleState);
    }

    function withdrawContribute() external whenNotPaused {
        InvestInfo storage joinInfo = investInfos[_msgSender()];
        require((privateSaleState == 3) || (raisedAmount < softCap && block.timestamp > endTime));
        require(joinInfo.refund == false, 'Refunded');
        require(joinInfo.totalInvestment > 0, 'Not Invest');

        uint256 totalWithdraw = joinInfo.totalInvestment;
        joinInfo.refund = true;
        joinInfo.totalInvestment = 0;
        _investedUsers.remove(_msgSender());


        raisedAmount = raisedAmount.sub(totalWithdraw);


        if (currency == address(0)) {
            payable(_msgSender()).transfer(totalWithdraw);
        } else {
            IERC20 currencyTokenErc20 = IERC20(currency);
            require(currencyTokenErc20.balanceOf(address(this)) >= totalWithdraw, 'Insufficient Balance');
            currencyTokenErc20.safeTransfer(_msgSender(), totalWithdraw);
        }
    }

    function emergencyWithdrawContribute() external whenNotPaused onlyRunning {
        InvestInfo storage joinInfo = investInfos[_msgSender()];
        require(startTime <= block.timestamp && endTime >= block.timestamp, 'Invalid time');
        require(joinInfo.refund == false, 'Refunded');
        require(joinInfo.totalInvestment > 0, 'Not contribute');

        uint256 totalPenaltyFees = joinInfo.totalInvestment.mul(penaltyFeePercent).div(ZOOM);

        uint256 totalWithdrawTokens = joinInfo.totalInvestment.sub(totalPenaltyFees);

        raisedAmount = raisedAmount.sub(joinInfo.totalInvestment);


        joinInfo.refund = true;
        joinInfo.totalInvestment = 0;
        _investedUsers.remove(_msgSender());

        require(totalWithdrawTokens > 0, 'Invalid withdraw amount');

        if (currency == address(0)) {
            if (totalWithdrawTokens > 0) {
                payable(_msgSender()).transfer(totalWithdrawTokens);
            }

            if (totalPenaltyFees > 0) {
                payable(fundAddress).transfer(totalPenaltyFees);
            }

        } else {
            IERC20 currencyTokenErc20 = IERC20(currency);

            if (totalWithdrawTokens > 0) {
                currencyTokenErc20.safeTransfer(_msgSender(), totalWithdrawTokens);
            }

            if (totalPenaltyFees > 0) {
                currencyTokenErc20.safeTransfer(fundAddress, totalPenaltyFees);
            }
        }
    }


    function claimFund() external whenNotPaused onlyWhitelistAdmin {
        require(privateSaleState == 2, 'Not Final');
        require(tgeDate <= block.timestamp, 'Cant claim at this time');
        _vestingUnlock();
    }


    function _vestingUnlock() internal {
        uint256 withdrawable = _withdrawableTokens();
        uint256 newTotalUnlockAmount = unlockedAmount + withdrawable;
        require(
            withdrawable > 0 && newTotalUnlockAmount <= raisedAmount,
            "Nothing to unlock"
        );

        uint256 totalFee = 0;

        if (fundPercent > 0) {
            totalFee = withdrawable.mul(fundPercent).div(ZOOM);
        }
        withdrawable = withdrawable.sub(totalFee);

        unlockedAmount = newTotalUnlockAmount;

        if (currency == address(0)) {
            if (totalFee > 0) {
                payable(fundAddress).transfer(totalFee);
            }
            if (withdrawable > 0) {
                payable(owner()).transfer(withdrawable);
            }
            payable(owner()).transfer(withdrawable);
        } else {
            IERC20 currencyTokenErc20 = IERC20(currency);
            if (totalFee > 0) {
                currencyTokenErc20.safeTransfer(fundAddress, totalFee);
            }
            if (withdrawable > 0) {
                currencyTokenErc20.safeTransfer(owner(), withdrawable);
            }

        }


        emit VestingClaim(
            withdrawable,
            raisedAmount - unlockedAmount,
            block.timestamp
        );
    }

    function withdrawableTokens()
    external
    view
    returns (uint256)
    {
        return _withdrawableTokens();
    }

    function _withdrawableTokens()
    internal
    view
    returns (uint256)
    {
        if (raisedAmount == 0) return 0;
        if (unlockedAmount >= raisedAmount) return 0;
        if (block.timestamp < tgeDate || tgeDate == 0) return 0;

        uint256 currentTotal = 0;
        if (tgeBps == 0) {
            currentTotal = raisedAmount;
        } else {
            if (cycle == 0) return 0;
            uint256 tgeReleaseAmount = FullMath.mulDiv(
                raisedAmount,
                tgeBps,
                ZOOM
            );
            uint256 cycleReleaseAmount = FullMath.mulDiv(
                raisedAmount,
                cycleBps,
                ZOOM
            );

            if (block.timestamp >= tgeDate) {
                currentTotal =
                (((block.timestamp - tgeDate) / cycle) *
                cycleReleaseAmount) +
                tgeReleaseAmount;
                // Truncation is expected here
            }

        }

        uint256 withdrawable = 0;
        if (currentTotal > raisedAmount) {
            withdrawable = raisedAmount - unlockedAmount;
        } else {
            withdrawable = currentTotal - unlockedAmount;
        }
        return withdrawable;
    }


    function allInvestorCount() public view returns (uint256) {
        return _investedUsers.length();
    }


    function getInvestors(uint256 start, uint256 end)
    external
    view
    returns (InvestInfo[] memory)
    {
        uint256 totalUsers = _investedUsers.length();
        if (totalUsers == 0) {
            return new InvestInfo[](0);
        }

        if (end > totalUsers) {
            end = totalUsers;
        }

        if (end < start) {
            return new InvestInfo[](0);
        }

        uint256 length = end - start;
        InvestInfo[] memory result = new InvestInfo[](length);
        uint256 index = 0;
        for (uint256 i = start; i < end; i++) {
            result[index] = investInfos[_investedUsers.at(i)];
            index++;
        }
        return result;
    }


    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
        keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
    }

    function recoverSigner(bytes32 message, bytes memory sig)
    internal
    pure
    returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    function splitSignature(bytes memory sig)
    internal
    pure
    returns (
        uint8,
        bytes32,
        bytes32
    )
    {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
        // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
        // second 32 bytes
            s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

}