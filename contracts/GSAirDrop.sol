// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


import "./libraries/FullMath.sol";
import "./structs/AirDropStructs.sol";


contract GSAirDrop is Ownable, Pausable {
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;



    struct Allocation {
        address user;
        uint256 amount;
        uint256 unlockedAmount; // claimed Amount
    }


    mapping(address => bool) public wlAdmins;
    mapping(address => bool) public superAccounts;


    modifier onlyWhitelistAdmin() {
        require(wlAdmins[msg.sender], "Only Admin");
        _;
    }

    modifier onlySuperAccount() {
        require(superAccounts[msg.sender], "Only Super");
        _;
    }

    function whiteListAdmins(address _user, bool _whiteList) public onlySuperAccount {
        wlAdmins[_user] = _whiteList;
    }

    uint256 currentIndex = 0;
    mapping(uint256 => EnumerableSet.AddressSet) private _allocationUsers;

    //    EnumerableSet.AddressSet private _allocationUsers; //set of user address
    mapping(address => Allocation) public allocationInfos; // user => amounts
    bool public ensureExactAmount = true;
    uint256 public tgeDate; // claim Date
    uint256 public tgeBps; // tge percent
    uint256 public cycle; // period after tge
    uint256 public cycleBps; // cycle percent
    uint256 public airDropState; // 1 start, 2 cancel
    IERC20 public airDropToken;
    address payable public fundAddress;
    uint256 public fundPercent;

    uint256 public constant ZOOM = 10_000;
    uint256 public totalAllocationTokens;
    uint256 public userClaimedTokens;


    event SetAllocations(
        uint256 indexed totalAllocations,
        address indexed sender,
        uint256 indexed state
    );

    event RemoveAllocations(
        uint256 indexed totalAllocations,
        address indexed sender,
        uint256 indexed state
    );

    event SetEnableExactAmount(
        bool indexed status,
        address indexed sender
    );

    event StartAirDrop(
        uint256 indexed totalAllocations,
        address indexed sender,
        uint256 indexed state
    );

    event CancelAirDrop(
        uint256 indexed totalAllocations,
        address indexed sender,
        uint256 indexed state
    );

    event SetVesting(
        uint256 indexed cycle,
        uint256 indexed tgeBps,
        uint256 indexed cycleBps,
        address sender
    );

    event AirDropVestingClaim(
        address indexed user,
        uint256 indexed amounts,
        uint256 indexed remaimAmounts,
        uint256 claimAt
    );

    constructor(IERC20 _airDropToken,
        address payable _fundAddress,
        uint256 _fundPercent,
        address _superAccount,
        address _deployer
    ) {
        require(address(_airDropToken) != address(0) && address(_airDropToken) != address(this), "Invalid address");
        require(_fundPercent <= ZOOM, 'Invalid Fund Percent');

        airDropToken = _airDropToken;
        fundAddress = _fundAddress;
        fundPercent = _fundPercent;

        superAccounts[_superAccount] = true;

        wlAdmins[_deployer] = true;
        wlAdmins[_superAccount] = true;

        transferOwnership(_deployer);


    }

    function setFundAddress(
        address payable _fundAddress
    ) external whenNotPaused onlySuperAccount {
        require(_fundAddress != address(0) && _fundAddress != address(this), "Invalid address");
        fundAddress = _fundAddress;
    }

    //TODO: calculate here
    function setAllocations(
        address[] calldata _users,
        uint256[] calldata _amounts
    ) external whenNotPaused onlyWhitelistAdmin {
        require(_users.length == _amounts.length, "Length mismatched");
        require(airDropState == 0, "Airdrop started");
        for (uint256 i = 0; i < _users.length; i++) {
            uint256 preAmount = allocationInfos[_users[i]].amount;
            if (_amounts[i] > 0) {
                _allocationUsers[currentIndex].add(_users[i]);
                allocationInfos[_users[i]].user = _users[i];
                allocationInfos[_users[i]].amount = _amounts[i];
                allocationInfos[_users[i]].unlockedAmount = 0;
            } else {
                delete allocationInfos[_users[i]];
                _allocationUsers[currentIndex].remove(_users[i]);
            }
            if (preAmount < _amounts[i]) {
                totalAllocationTokens = totalAllocationTokens.add(_amounts[i].sub(preAmount));
            } else {
                totalAllocationTokens = totalAllocationTokens.sub(preAmount.sub(_amounts[i]));
            }

        }
        emit SetAllocations(_allocationUsers[currentIndex].length(), _msgSender(), airDropState);

    }

    function removeAllAllocations() external whenNotPaused onlyWhitelistAdmin {
        require(airDropState == 0, "Airdrop started");
        uint256 totalUsers = _allocationUsers[currentIndex].length();

        if (totalUsers > 0) {
            for (uint256 i = 0; i < totalUsers; i++) {
                address user = _allocationUsers[currentIndex].at(i);
                delete allocationInfos[user];
            }
        }
        currentIndex = currentIndex + 1;
        totalAllocationTokens = 0;
        emit RemoveAllocations(_allocationUsers[currentIndex].length(), _msgSender(), airDropState);
    }

    function setEnableExactAmount(
        bool status
    ) external whenNotPaused onlyWhitelistAdmin {
        require(ensureExactAmount != status, "No need to update");
        ensureExactAmount = status;
        emit SetEnableExactAmount(status, _msgSender());
    }

    function startAirDrop(uint256 _tgeDate) external whenNotPaused onlyWhitelistAdmin {
        require(airDropState == 0, "Cant start airdrop");
        require(_tgeDate > 0, "Invalid TGE Date");
        airDropState = 1;
        tgeDate = _tgeDate;

        uint256 fundTokens = totalAllocationTokens.mul(fundPercent).div(ZOOM);
        require(airDropToken.balanceOf(_msgSender()) >= totalAllocationTokens + fundTokens, 'Insufficient Balance');
        require(airDropToken.allowance(_msgSender(), address(this)) >= totalAllocationTokens + fundTokens, 'Insufficient Allowance');

        if (totalAllocationTokens > 0) {
            airDropToken.safeTransferFrom(_msgSender(), address(this), totalAllocationTokens);
        }

        if (fundTokens > 0) {
            airDropToken.safeTransferFrom(_msgSender(), fundAddress, fundTokens);
        }
        emit StartAirDrop(_allocationUsers[currentIndex].length(), _msgSender(), airDropState);

    }

    function cancelAirdrop() external whenNotPaused onlyWhitelistAdmin {
        require(airDropState == 0, "Cant cancel airdrop");
        airDropState = 2;
        emit CancelAirDrop(_allocationUsers[currentIndex].length(), _msgSender(), airDropState);

    }

    function setVesting(
        uint256 _tgeBps,
        uint256 _cycle,
        uint256 _cycleBps
    ) external whenNotPaused onlyWhitelistAdmin {
        require(airDropState == 0, "Cant set vesting");
        require((_tgeBps == 0) || (_tgeBps > 0 && _cycleBps > 0 && _cycle > 0), 'Invalid Vesting');
        require(_tgeBps + _cycleBps <= ZOOM, 'Exceed percent');

        tgeBps = _tgeBps;
        cycle = _cycle;
        cycleBps = _cycleBps;
        emit SetVesting(_cycle, _tgeBps, _cycleBps, _msgSender());
    }


    function claimAirdrop() external whenNotPaused {
        Allocation storage userAllocation = allocationInfos[_msgSender()];
        require(userAllocation.user == _msgSender(), "You are not the owner of this airdrop");
        require(airDropState == 1, 'Not Start Yet');
        _vestingUnlock(userAllocation);

    }


    function _vestingUnlock(Allocation storage userAllocation) internal {
        uint256 withdrawable = _withdrawableTokens(userAllocation);
        uint256 newTotalUnlockAmount = userAllocation.unlockedAmount + withdrawable;
        require(
            withdrawable > 0 && newTotalUnlockAmount <= userAllocation.amount,
            "Nothing to unlock"
        );
        userAllocation.unlockedAmount = newTotalUnlockAmount;
        userClaimedTokens = userClaimedTokens.add(withdrawable);
        function(
            IERC20,
            address,
            uint256
        ) transfer = ensureExactAmount
        ? _safeTransferFromEnsureExactAmount
        : _safeTransferFrom;


        transfer(airDropToken, userAllocation.user, withdrawable);


        emit AirDropVestingClaim(
            userAllocation.user,
            withdrawable,
            userAllocation.amount - userAllocation.unlockedAmount,
            block.timestamp
        );
    }

    function withdrawableTokens(address _user)
    external
    view
    returns (uint256)
    {
        Allocation memory userAllocation = allocationInfos[_user];
        return _withdrawableTokens(userAllocation);
    }

    function _withdrawableTokens(Allocation memory userAllocation)
    internal
    view
    returns (uint256)
    {
        if (userAllocation.amount == 0) return 0;
        if (userAllocation.unlockedAmount >= userAllocation.amount) return 0;
        if (block.timestamp < tgeDate || tgeDate == 0) return 0;

        uint256 currentTotal = 0;
        if (tgeBps == 0) {
            currentTotal = userAllocation.amount;
        } else {
            if (cycle == 0) return 0;
            uint256 tgeReleaseAmount = FullMath.mulDiv(
                userAllocation.amount,
                tgeBps,
                ZOOM
            );
            uint256 cycleReleaseAmount = FullMath.mulDiv(
                userAllocation.amount,
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
        if (currentTotal > userAllocation.amount) {
            withdrawable = userAllocation.amount - userAllocation.unlockedAmount;
        } else {
            withdrawable = currentTotal - userAllocation.unlockedAmount;
        }
        return withdrawable;
    }


    function allAllocationCount() public view returns (uint256) {
        return _allocationUsers[currentIndex].length();
    }


    function getAllocations(uint256 start, uint256 end)
    external
    view
    returns (Allocation[] memory)
    {
        uint256 totalUsers = _allocationUsers[currentIndex].length();
        if (totalUsers == 0) {
            return new Allocation[](0);
        }

        if (end > totalUsers) {
            end = totalUsers;
        }

        if (end < start) {
            return new Allocation[](0);
        }

        uint256 length = end - start;
        Allocation[] memory allocations = new Allocation[](length);
        uint256 index = 0;
        for (uint256 i = start; i < end; i++) {
            allocations[index] = allocationInfos[_allocationUsers[currentIndex].at(i)];
            index++;
        }
        return allocations;
    }


    function _safeTransferFromEnsureExactAmount(
        IERC20 token,
        address to,
        uint256 amount
    ) private {
        uint256 balanceBefore = token.balanceOf(to);
        token.safeTransfer(to, amount);
        require(
            token.balanceOf(to) - balanceBefore == (address(this) != to ? amount : 0), // if from is the same as to, the final balance should be the same as before the transfer
            "Not enough tokens were transfered, check tax and fee options or try setting ensureExactAmount to false"
        );
    }

    function _safeTransferFrom(
        IERC20 token,
        address to,
        uint256 amount
    ) private {
        token.safeTransfer(to, amount);
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

    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
        _unpause();
    }
}