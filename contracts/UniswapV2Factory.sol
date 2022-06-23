pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract LittleMamiV1ERC20 is ERC20Burnable {
    // EIP712Domain
    bytes32 public DOMAIN_SEPARATOR;

    constructor() public ERC20("LittleMami V1", "LM-V1") {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name())),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }
}

contract LittleMamiV1IFO is Ownable, ReentrancyGuard, LittleMamiV1ERC20 {
    event Invest(address indexed investor, uint256 amount);

    constructor() {
        factory = msg.sender;
    }

    address public factory;
    string public ifoName;
    string public logo;
    string public description;
    uint256 public hardcap;
    uint256 public startTime;
    uint256 public endTime;

    uint256 public currentAmount;

    // called once by the factory at time of deployment
    function initialize(
        string memory _name,
        string memory _logo,
        string memory _description,
        uint256 _hardcap,
        uint256 _startTime,
        uint256 _endTime,
        address _owner
    ) external onlyOwner {
        ifoName = _name;
        logo = _logo;
        description = _description;
        hardcap = _hardcap;
        startTime = _startTime;
        endTime = _endTime;
        transferOwnership(_owner);
    }

    function invest() external payable nonReentrant {
        uint256 value = msg.value;
        require(
            currentAmount + value <= hardcap,
            "LittleMami V1 Protocol : CurrentAmount must be less than or equal to hard cap"
        );
        require(
            block.timestamp >= startTime,
            "LittleMami V1 Protocol : IFO has not started"
        );
        require(
            block.timestamp <= endTime,
            "LittleMami V1 Protocol : IFO is over"
        );
        currentAmount += value;
        _mint(msg.sender, value);
        emit Invest(msg.sender, value);
    }

    function edit(
        string calldata _name,
        string calldata _logo,
        string calldata _description,
        uint256 _hardcap,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        require(
            hardcap >= currentAmount,
            "LittleMami V1 Protocol : CurrentAmount Must be less than or equal to hard cap"
        );
        ifoName = _name;
        logo = _logo;
        description = _description;
        hardcap = _hardcap;
        startTime = _startTime;
        endTime = _endTime;
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}

contract LittleMamiV1Factory {
    using Strings for uint256;

    event CreateIFO(address indexed ifo, uint256 id);

    uint256 id;

    function createIFO(
        string calldata _name,
        string calldata _logo,
        string calldata _description,
        uint256 _hardcap,
        uint256 _startTime,
        uint256 _endTime
    ) external payable {
        id++;
        bytes32 salt = keccak256(abi.encodePacked(id.toString()));

        // create ifo contract | create2
        LittleMamiV1IFO ifo = new LittleMamiV1IFO{salt: salt}();

        ifo.initialize(
            _name,
            _logo,
            _description,
            _hardcap,
            _startTime,
            _endTime,
            msg.sender
        );

        emit CreateIFO(address(ifo), id);
    }

    function totalIFO() external view returns (uint256) {
        return id;
    }

    function getIFOAddress(uint256 _id) external view returns (address) {
        require(
            _id <= id && _id != 0,
            "LittleMami V1 Protocol : Not found this id"
        );
        bytes32 salt = keccak256(abi.encodePacked(_id.toString()));
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                salt,
                                keccak256(type(LittleMamiV1IFO).creationCode)
                            )
                        )
                    )
                )
            );
    }
}
