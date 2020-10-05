pragma solidity ^0.5.12;

import { BCdpManager } from "../BCdpManager.sol";
import { Math } from "../Math.sol";
import { JarConnector } from "../JarConnector.sol";
import { GovernanceExecutor } from "./GovernanceExecutor.sol";

contract Migrate is Math {

    event NewProposal(uint indexed proposalId, address newOwner);
    event Voted(uint indexed proposalId, uint cdp, uint score);
    event VoteCancelled(uint indexed proposalId, uint cdp, uint score);
    event Queued(uint indexed proposalId);
    event Executed(uint indexed proposalId);

    struct Proposal {
        uint forVotes;
        uint eta;
        address newOwner;
        mapping (uint => bool) voted; // cdp => voted
    }

    uint public constant DELAY = 2 days;

    JarConnector public jarConnector;
    BCdpManager public man;
    GovernanceExecutor public executor;

    Proposal[] public proposals;

    constructor(
        JarConnector jarConnector_,
        BCdpManager man_,
        GovernanceExecutor executor_
    ) public {
        jarConnector = jarConnector_;
        man = man_;
        executor = executor_;
    }

    function propose(address newOwner) external returns (uint) {
        require(jarConnector.round() > 2, "six-months-not-passed");
        require(newOwner != address(0), "newOwner-cannot-be-zero");

        Proposal memory proposal = Proposal({
            forVotes: 0,
            eta: 0,
            newOwner: newOwner
        });

        uint proposalId = sub(proposals.push(proposal), uint(1));
        emit NewProposal(proposalId, newOwner);

        return proposalId;
    }

    function vote(uint proposalId, uint cdp) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.newOwner != address(0), "proposal-not-exist");
        require(! proposal.voted[cdp], "already-voted");
        require(msg.sender == man.owns(cdp), "not-cdp-owner");
        
        uint score = jarConnector.getUserScore(bytes32(cdp));
        proposal.forVotes = add(proposal.forVotes, score);
        proposal.voted[cdp] = true;

        emit Voted(proposalId, cdp, score);
    }

    function cancelVote(uint proposalId, uint cdp) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.newOwner != address(0), "proposal-not-exist");
        require(proposal.voted[cdp], "not-voted");
        require(msg.sender == man.owns(cdp), "not-cdp-owner");

        uint score = jarConnector.getUserScore(bytes32(cdp));
        proposal.forVotes = sub(proposal.forVotes, score);
        proposal.voted[cdp] = false;

        emit VoteCancelled(proposalId, cdp, score);
    }

    function queueProposal(uint proposalId) external {
        uint quorum = add(jarConnector.getGlobalScore() / 2, uint(1)); // 50%
        Proposal storage proposal = proposals[proposalId];
        require(proposal.eta == 0, "already-queued");
        require(proposal.newOwner != address(0), "proposal-not-exist");
        require(proposal.forVotes >= quorum, "quorum-not-passed");

        proposal.eta = now + DELAY;

        emit Queued(proposalId);
    }

    function executeProposal(uint proposalId) external {
        Proposal memory proposal = proposals[proposalId];
        require(proposal.eta > 0, "proposal-not-queued");
        require(now >= proposal.eta, "delay-not-over");

        executor.doTransferAdmin(proposal.newOwner);

        emit Executed(proposalId);
    }
}