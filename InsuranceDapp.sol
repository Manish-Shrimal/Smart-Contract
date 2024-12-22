// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract InsuranceManagementSystem {
    // Enum to track policy status
    enum PolicyStatus {
        Active,
        Expired,
        Cancelled
    }

    // Enum to track claim status
    enum ClaimStatus {
        Submitted,
        Approved,
        Rejected,
        Paid
    }

    // Struct to represent an insurance policy
    struct Policy {
        address policyholder;
        address insurer;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 duration;
        PolicyStatus status;
        uint256 lastPremiumPaidTime;
        uint256 totalPremiumsPaid;
    }

    // Struct to represent a claim
    struct Claim {
        uint256 policyId;
        address policyholder;
        uint256 claimAmount;
        string reason;
        ClaimStatus status;
        uint256 submissionTime;
    }

    // Contract owner (primary insurer)
    address public owner;

    // Mapping to store policies
    mapping(uint256 => Policy) public policies;
    
    // Mapping to store claims
    mapping(uint256 => Claim) public claims;

    // Mapping to track authorized insurers
    mapping(address => bool) public authorizedInsurers;

    // Counter for policy and claim IDs
    uint256 public policyCounter;
    uint256 public claimCounter;

    // Premium payment grace period (in seconds)
    uint256 public constant GRACE_PERIOD = 30 days;

    // Events for transparency and logging
    event PolicyIssued(
        uint256 indexed policyId, 
        address indexed policyholder, 
        uint256 premiumAmount, 
        uint256 coverageAmount
    );

    event PremiumPaid(
        uint256 indexed policyId, 
        address indexed policyholder, 
        uint256 amount
    );

    event ClaimSubmitted(
        uint256 indexed claimId, 
        uint256 indexed policyId, 
        uint256 claimAmount
    );

    event ClaimApproved(
        uint256 indexed claimId, 
        uint256 indexed policyId, 
        uint256 approvedAmount
    );

    event ClaimPaid(
        uint256 indexed claimId, 
        address indexed policyholder, 
        uint256 amount
    );

    // Constructor
    constructor() {
        owner = msg.sender;
        authorizedInsurers[msg.sender] = true;
    }

    // Modifier to check if caller is an authorized insurer
    modifier onlyInsurer() {
        require(authorizedInsurers[msg.sender], "Not authorized");
        _;
    }

    // Modifier to check if caller is the policy owner
    modifier onlyPolicyholder(uint256 _policyId) {
        require(policies[_policyId].policyholder == msg.sender, "Not policy owner");
        _;
    }

    // Function to add authorized insurers
    function addInsurer(address _insurer) external {
        require(msg.sender == owner, "Only owner can add insurers");
        authorizedInsurers[_insurer] = true;
    }

    // Function to issue a new insurance policy
    function issuePolicy(
        address _policyholder, 
        uint256 _premiumAmount, 
        uint256 _coverageAmount, 
        uint256 _duration
    ) external onlyInsurer returns (uint256) {
        // Validate inputs
        require(_policyholder != address(0), "Invalid policyholder");
        require(_premiumAmount > 0, "Premium must be greater than 0");
        require(_coverageAmount > 0, "Coverage must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        // Increment policy counter
        policyCounter++;

        // Create new policy
        policies[policyCounter] = Policy({
            policyholder: _policyholder,
            insurer: msg.sender,
            premiumAmount: _premiumAmount,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            duration: _duration,
            status: PolicyStatus.Active,
            lastPremiumPaidTime: block.timestamp,
            totalPremiumsPaid: 0
        });

        // Emit policy issued event
        emit PolicyIssued(policyCounter, _policyholder, _premiumAmount, _coverageAmount);

        return policyCounter;
    }

    // Function to pay premium
    function payPremium(uint256 _policyId) external payable {
        Policy storage policy = policies[_policyId];
        
        // Validate policy and payment
        require(policy.status == PolicyStatus.Active, "Policy not active");
        require(msg.value == policy.premiumAmount, "Incorrect premium amount");
        require(block.timestamp <= policy.startTime + policy.duration, "Policy expired");

        // Update policy details
        policy.lastPremiumPaidTime = block.timestamp;
        policy.totalPremiumsPaid += msg.value;

        // Emit premium paid event
        emit PremiumPaid(_policyId, msg.sender, msg.value);
    }

    // Function to submit a claim
    function submitClaim(
        uint256 _policyId, 
        uint256 _claimAmount, 
        string memory _reason
    ) external {
        Policy storage policy = policies[_policyId];
        
        // Validate claim submission
        require(policy.policyholder == msg.sender, "Not policy owner");
        require(policy.status == PolicyStatus.Active, "Policy not active");
        require(block.timestamp <= policy.startTime + policy.duration, "Policy expired");
        require(_claimAmount <= policy.coverageAmount, "Claim exceeds coverage");

        // Increment claim counter
        claimCounter++;

        // Create new claim
        claims[claimCounter] = Claim({
            policyId: _policyId,
            policyholder: msg.sender,
            claimAmount: _claimAmount,
            reason: _reason,
            status: ClaimStatus.Submitted,
            submissionTime: block.timestamp
        });

        // Emit claim submitted event
        emit ClaimSubmitted(claimCounter, _policyId, _claimAmount);
    }

    // Function to approve a claim
    function approveClaim(uint256 _claimId) external onlyInsurer {
        Claim storage claim = claims[_claimId];
        Policy storage policy = policies[claim.policyId];

        // Validate claim approval
        require(claim.status == ClaimStatus.Submitted, "Claim not in submitted status");
        require(policy.coverageAmount >= claim.claimAmount, "Insufficient coverage");

        // Update claim status
        claim.status = ClaimStatus.Approved;

        // Emit claim approved event
        emit ClaimApproved(_claimId, claim.policyId, claim.claimAmount);
    }

    // Function to pay an approved claim
    function payClaim(uint256 _claimId) external onlyInsurer {
        Claim storage claim = claims[_claimId];
        Policy storage policy = policies[claim.policyId];

        // Validate claim payment
        require(claim.status == ClaimStatus.Approved, "Claim not approved");

        // Update claim status
        claim.status = ClaimStatus.Paid;

        // Transfer funds to policyholder
        payable(claim.policyholder).transfer(claim.claimAmount);

        // Emit claim paid event
        emit ClaimPaid(_claimId, claim.policyholder, claim.claimAmount);
    }

    // Function to check policy status
    function checkPolicyStatus(uint256 _policyId) external view returns (PolicyStatus) {
        Policy storage policy = policies[_policyId];
        
        // Check if policy has expired
        if (block.timestamp > policy.startTime + policy.duration) {
            return PolicyStatus.Expired;
        }

        return policy.status;
    }

    // Function to get policy details
    function getPolicyDetails(uint256 _policyId) external view returns (Policy memory) {
        return policies[_policyId];
    }

    // Function to get claim details
    function getClaimDetails(uint256 _claimId) external view returns (Claim memory) {
        return claims[_claimId];
    }

    // Fallback function to receive Ether
    receive() external payable {}
}