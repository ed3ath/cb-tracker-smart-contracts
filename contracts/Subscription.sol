// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Subscription is Initializable, UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20;

    // state variables
    address public treasury;
    IERC20 public paymentToken;
    uint256 public subscriptionFee;

    // mappings
    mapping(string => uint64) private subscribers;

    // events 
    event NewSubscription (
        string user,
        uint64 timestamp
    );

    // modifiers
    modifier ownerOnly() {
        _isOwner();
        _;
    }

    // private functions
    function _isOwner() private view {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Owner only");
    }

    function _authorizeUpgrade(address) internal view override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Owner only");
	}

    // public functions

    function initialize(
        address _treasury,
        IERC20 _paymentToken,
        uint256 _subscriptionFee
    ) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        treasury = _treasury;
        paymentToken = _paymentToken;
        subscriptionFee = _subscriptionFee;
    }
    

    function setTreasury(address _treasury) public ownerOnly {
        treasury = _treasury;
    }

    function setPaymentToken(IERC20 _paymentToken) public ownerOnly {
        paymentToken = _paymentToken;
    }

    function setSubscriptionFee(uint256 _subscriptionFee) public ownerOnly {
        subscriptionFee = _subscriptionFee;
    }

    function subscribe(string memory _user) public nonReentrant {
        require(paymentToken.balanceOf(msg.sender) >= subscriptionFee, "Not enough token.");
        require(uint64(block.timestamp) >= subscribers[_user], "User is currently subscribed.");
        paymentToken.transferFrom(msg.sender, treasury, subscriptionFee);
        subscribers[_user] = uint64(uint256(86400).mul(30).add(block.timestamp));
        emit NewSubscription(_user, uint64(block.timestamp));
    }

    function isSubscribed(string memory _user) public view returns(bool) {
        return subscribers[_user] > uint64(block.timestamp);
    }
}