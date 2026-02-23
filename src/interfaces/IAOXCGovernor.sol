// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCGovernor
 * @author AOXC Protocol
 * @notice Interface for the AOXC Governance system.
 * @dev Standardized interface to allow interaction between the Governor and other ecosystem contracts.
 */
interface IAOXCGovernor {
    
    // --- Data Structures ---

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    struct ProposalCore {
        uint256 voteStart;
        uint256 voteEnd;
        bool executed;
        bool canceled;
    }

    // --- Events ---

    event ProposalCreated(
        uint256 indexed proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );

    event VoteCast(
        address indexed voter, 
        uint256 proposalId, 
        uint8 support, 
        uint256 weight, 
        string reason
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);

    // --- Read Functions ---

    /**
     * @notice Returns the current state of a proposal.
     */
    function state(uint256 proposalId) external view returns (ProposalState);

    /**
     * @notice Returns the voting power of an account at a specific block time.
     */
    function getVotes(address account, uint256 timepoint) external view returns (uint256);

    /**
     * @notice Returns the quorum required for a proposal to pass at a specific timepoint.
     */
    function quorum(uint256 timepoint) external view returns (uint256);

    /**
     * @notice Returns the delay (in blocks/seconds) before voting starts after a proposal is created.
     */
    function votingDelay() external view returns (uint256);

    /**
     * @notice Returns the duration of the voting period.
     */
    function votingPeriod() external view returns (uint256);

    /**
     * @notice Returns the threshold of votes required to create a proposal.
     */
    function proposalThreshold() external view returns (uint256);

    // --- Logic Functions ---

    /**
     * @notice Creates a new proposal.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId);

    /**
     * @notice Executes a successful and queued proposal.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256 proposalId);

    /**
     * @notice Casts a vote on a proposal.
     * @param support 0 = Against, 1 = For, 2 = Abstain.
     */
    function castVote(uint256 proposalId, uint8 support) external returns (uint256 balance);

    /**
     * @notice Casts a vote with a reason (useful for off-chain indexing and transparency).
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external returns (uint256 balance);
}
