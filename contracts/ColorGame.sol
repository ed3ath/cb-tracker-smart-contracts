// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./lib/Random.sol";
import "./SeedManager.sol";

contract ColorGame is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeMath for uint256;
    using SafeMath for uint64;
    using SafeERC20Upgradeable for IERC20;

    bytes32 public constant GAME_MASTER = keccak256("GAME_MASTER");
    uint256 internal constant COLOR_GAME_RANDOM_SEED =
        uint256(keccak256("COLOR_GAME_RANDOM_SEED"));

    uint256 public constant COLOR_RED = 1;
    uint256 public constant COLOR_ORANGE = 2;
    uint256 public constant COLOR_YELLOW = 3;
    uint256 public constant COLOR_GREEN = 4;
    uint256 public constant COLOR_BLUE = 5;
    uint256 public constant COLOR_INDIGO = 6;

    // state variables
    address public treasury;
    IERC20 public paymentToken;
    SeedManager public seedManager;
    uint64 public roundDuration;

    CountersUpgradeable.Counter private roundCounter;

    // mappings
    mapping(uint256 => uint256) public roundPrizepool;
    mapping(uint256 => uint256) public roundColors;
    mapping(uint256 => uint64) public roundEndtime;
    mapping(uint256 => bool) public roundDisabled;
    mapping(uint256 => mapping(address => uint256)) private roundColorBets; // round => user => color
    mapping(uint256 => mapping(address => uint256)) private roundAmountBets; // round => user => amount

    // events
    event RoundBetPlaced(
        uint256 indexed round,
        address indexed user,
        uint256 color,
        uint256 amount,
        uint64 timestamp
    );

    event RoundStarted(uint256 indexed round, uint64 timestamp);

    event RoundEnded(
        uint256 indexed round,
        uint256 winningColor,
        uint64 timestamp
    );

    // modifiers
    modifier ownerOnly() {
        _isOwner();
        _;
    }
    modifier gameMasterOnly() {
        _isGameMaster();
        _;
    }

    // private functions
    function _isOwner() private view {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Owner only");
    }

    function _isGameMaster() private view {
        require(hasRole(GAME_MASTER, msg.sender), "Game master only");
    }

    function _authorizeUpgrade(address) internal view override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Owner only");
    }

    // public functions

    function initialize(
        address _treasury,
        IERC20 _paymentToken,
        SeedManager _seedManager,
        uint64 _roundDuration
    ) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GAME_MASTER, msg.sender);

        treasury = _treasury;
        paymentToken = _paymentToken;
        seedManager = _seedManager;
        roundDuration = _roundDuration;

        roundCounter.increment();
        seedManager.requestSingleSeed(
            address(this),
            Random.combineSeeds(COLOR_GAME_RANDOM_SEED, roundCounter.current())
        );
    }

    function setTreasury(address _treasury) public ownerOnly {
        treasury = _treasury;
    }

    function setPaymentToken(IERC20 _paymentToken) public ownerOnly {
        paymentToken = _paymentToken;
    }

    function getCurrentRound() public view returns(uint256) {
        return roundCounter.current();
    }

    function getUserRoundBet(address user) public view returns(uint256, uint256) {
        return (roundColorBets[roundCounter.current()][user], roundAmountBets[roundCounter.current()][user]);
    }

    function bet(uint256 _color, uint256 _amount) public nonReentrant {
        require(!roundDisabled[roundCounter.current()], "E2000");
        require(
            roundEndtime[roundCounter.current()].add(roundDuration) <=
                block.timestamp,
            "E2001"
        );
        require(_color >= 1 && _color <= 6, "E2002");
        require(_amount > 0, "E2003");
        require(
            roundColorBets[roundCounter.current()][msg.sender] == 0 &&
                roundAmountBets[roundCounter.current()][msg.sender] == 0,
            "E2004"
        );
        roundColorBets[roundCounter.current()][msg.sender] = _color;
        roundAmountBets[roundCounter.current()][msg.sender] = _amount;
        emit RoundBetPlaced(
            roundCounter.current(),
            msg.sender,
            _color,
            _amount,
            uint64(block.timestamp)
        );
    }

    function pickRandomColor() public nonReentrant gameMasterOnly {
        roundDisabled[roundCounter.current()] = true;
        uint256 seed = seedManager.popSingleSeed(
            address(this),
            Random.combineSeeds(COLOR_GAME_RANDOM_SEED, roundCounter.current()),
            true,
            true
        );
        roundColors[roundCounter.current()] =
            (Random.combineSeeds(seed, uint256(block.timestamp)) %
            6).add(1);
        emit RoundEnded(
            roundCounter.current(),
            roundColors[roundCounter.current()],
            uint64(block.timestamp)
        );
    }
}
