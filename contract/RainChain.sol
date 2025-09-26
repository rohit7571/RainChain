// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title RainChain
 * @dev A decentralized water resource management and rainfall prediction system
 * @author RainChain Team
 */
contract RainChain {
    
    // Struct to store rainfall data
    struct RainfallData {
        uint256 timestamp;
        uint256 amount; // in millimeters * 100 (to handle decimals)
        string location;
        address reporter;
        bool verified;
        uint256 rewardClaimed;
    }
    
    // Struct to store water resource information
    struct WaterResource {
        string name;
        string resourceType; // "reservoir", "lake", "river", "groundwater"
        uint256 currentLevel; // in percentage * 100
        uint256 capacity; // in liters
        uint256 lastUpdated;
        address manager;
        bool active;
    }
    
    // State variables
    mapping(uint256 => RainfallData) public rainfallRecords;
    mapping(uint256 => WaterResource) public waterResources;
    mapping(address => uint256) public userRewards;
    mapping(address => bool) public authorizedReporters;
    
    uint256 public totalRainfallRecords;
    uint256 public totalWaterResources;
    uint256 public rewardPool;
    
    address public owner;
    uint256 public constant REPORTER_REWARD = 10 ether; // 10 tokens for verified reports
    uint256 public constant MIN_REPORT_INTERVAL = 1 hours;
    
    // Events
    event RainfallReported(uint256 indexed recordId, string location, uint256 amount, address reporter);
    event RainfallVerified(uint256 indexed recordId, address verifier);
    event WaterResourceAdded(uint256 indexed resourceId, string name, string resourceType);
    event WaterLevelUpdated(uint256 indexed resourceId, uint256 newLevel, address updater);
    event RewardClaimed(address indexed user, uint256 amount);
    event ReporterAuthorized(address indexed reporter, address authorizer);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyAuthorizedReporter() {
        require(authorizedReporters[msg.sender], "Not an authorized reporter");
        _;
    }
    
    modifier resourceExists(uint256 _resourceId) {
        require(_resourceId < totalWaterResources, "Water resource does not exist");
        require(waterResources[_resourceId].active, "Water resource is inactive");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        authorizedReporters[msg.sender] = true;
        rewardPool = 1000000 ether; // Initial reward pool
    }
    
    /**
     * @dev Core Function 1: Report rainfall data
     * @param _amount Rainfall amount in millimeters * 100
     * @param _location Location where rainfall was measured
     */
    function reportRainfall(uint256 _amount, string memory _location) external onlyAuthorizedReporter {
        require(bytes(_location).length > 0, "Location cannot be empty");
        require(_amount > 0, "Rainfall amount must be greater than 0");
        
        // Create new rainfall record
        RainfallData storage newRecord = rainfallRecords[totalRainfallRecords];
        newRecord.timestamp = block.timestamp;
        newRecord.amount = _amount;
        newRecord.location = _location;
        newRecord.reporter = msg.sender;
        newRecord.verified = false;
        newRecord.rewardClaimed = 0;
        
        emit RainfallReported(totalRainfallRecords, _location, _amount, msg.sender);
        totalRainfallRecords++;
    }
    
    /**
     * @dev Core Function 2: Add and manage water resources
     * @param _name Name of the water resource
     * @param _resourceType Type of water resource
     * @param _capacity Total capacity in liters
     * @param _currentLevel Current water level in percentage * 100
     */
    function addWaterResource(
        string memory _name,
        string memory _resourceType,
        uint256 _capacity,
        uint256 _currentLevel
    ) external onlyAuthorizedReporter {
        require(bytes(_name).length > 0, "Resource name cannot be empty");
        require(bytes(_resourceType).length > 0, "Resource type cannot be empty");
        require(_capacity > 0, "Capacity must be greater than 0");
        require(_currentLevel <= 10000, "Current level cannot exceed 100%");
        
        WaterResource storage newResource = waterResources[totalWaterResources];
        newResource.name = _name;
        newResource.resourceType = _resourceType;
        newResource.currentLevel = _currentLevel;
        newResource.capacity = _capacity;
        newResource.lastUpdated = block.timestamp;
        newResource.manager = msg.sender;
        newResource.active = true;
        
        emit WaterResourceAdded(totalWaterResources, _name, _resourceType);
        totalWaterResources++;
    }
    
    /**
     * @dev Core Function 3: Claim rewards and verify data
     * @param _recordId ID of the rainfall record to verify and claim reward
     */
    function verifyAndClaimReward(uint256 _recordId) external {
        require(_recordId < totalRainfallRecords, "Invalid record ID");
        require(msg.sender == owner || authorizedReporters[msg.sender], "Not authorized to verify");
        
        RainfallData storage record = rainfallRecords[_recordId];
        require(!record.verified, "Record already verified");
        require(block.timestamp >= record.timestamp + MIN_REPORT_INTERVAL, "Verification period not met");
        
        // Verify the record
        record.verified = true;
        record.rewardClaimed = REPORTER_REWARD;
        
        // Add reward to reporter's balance
        userRewards[record.reporter] += REPORTER_REWARD;
        
        // Reduce reward pool
        require(rewardPool >= REPORTER_REWARD, "Insufficient reward pool");
        rewardPool -= REPORTER_REWARD;
        
        emit RainfallVerified(_recordId, msg.sender);
    }
    
    // Additional utility functions
    
    /**
     * @dev Update water resource level
     * @param _resourceId ID of the water resource
     * @param _newLevel New water level in percentage * 100
     */
    function updateWaterLevel(uint256 _resourceId, uint256 _newLevel) 
        external 
        resourceExists(_resourceId) 
    {
        require(_newLevel <= 10000, "Level cannot exceed 100%");
        require(
            msg.sender == waterResources[_resourceId].manager || 
            msg.sender == owner || 
            authorizedReporters[msg.sender],
            "Not authorized to update this resource"
        );
        
        waterResources[_resourceId].currentLevel = _newLevel;
        waterResources[_resourceId].lastUpdated = block.timestamp;
        
        emit WaterLevelUpdated(_resourceId, _newLevel, msg.sender);
    }
    
    /**
     * @dev Claim accumulated rewards
     */
    function claimRewards() external {
        uint256 reward = userRewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        
        userRewards[msg.sender] = 0;
        
        // In a real implementation, this would transfer tokens
        // For now, we just emit an event
        emit RewardClaimed(msg.sender, reward);
    }
    
    /**
     * @dev Authorize a new reporter
     * @param _reporter Address to authorize as reporter
     */
    function authorizeReporter(address _reporter) external onlyOwner {
        require(_reporter != address(0), "Invalid reporter address");
        authorizedReporters[_reporter] = true;
        emit ReporterAuthorized(_reporter, msg.sender);
    }
    
    /**
     * @dev Get rainfall data for a specific record
     * @param _recordId ID of the rainfall record
     */
    function getRainfallData(uint256 _recordId) external view returns (
        uint256 timestamp,
        uint256 amount,
        string memory location,
        address reporter,
        bool verified,
        uint256 rewardClaimed
    ) {
        require(_recordId < totalRainfallRecords, "Invalid record ID");
        RainfallData memory record = rainfallRecords[_recordId];
        return (
            record.timestamp,
            record.amount,
            record.location,
            record.reporter,
            record.verified,
            record.rewardClaimed
        );
    }
    
    /**
     * @dev Get water resource information
     * @param _resourceId ID of the water resource
     */
    function getWaterResource(uint256 _resourceId) external view returns (
        string memory name,
        string memory resourceType,
        uint256 currentLevel,
        uint256 capacity,
        uint256 lastUpdated,
        address manager,
        bool active
    ) {
        require(_resourceId < totalWaterResources, "Invalid resource ID");
        WaterResource memory resource = waterResources[_resourceId];
        return (
            resource.name,
            resource.resourceType,
            resource.currentLevel,
            resource.capacity,
            resource.lastUpdated,
            resource.manager,
            resource.active
        );
    }
    
    /**
     * @dev Get user's current reward balance
     * @param _user Address of the user
     */
    function getUserRewards(address _user) external view returns (uint256) {
        return userRewards[_user];
    }
    
    /**
     * @dev Check if address is authorized reporter
     * @param _reporter Address to check
     */
    function isAuthorizedReporter(address _reporter) external view returns (bool) {
        return authorizedReporters[_reporter];
    }
}
