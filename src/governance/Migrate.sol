pragma solidity ^0.5.16;

import { BCdpManager } from "../BCdpManager.sol";
import { Math } from "../Math.sol";
import { Timelock } from "./Timelock.sol";
import { JarConnector } from "../JarConnector.sol";

contract Migrate is Math {

    struct Proposal {
        uint forVotes;
        address newOwner;
        mapping (uint => bool) voted; // cdp => voted
    }

    Timelock public timelock;
    JarConnector public jarConnector;
    BCdpManager public man;

    Proposal[] public proposals;

    constructor(
        JarConnector jarConnector_,
        BCdpManager man_
    ) public {
        jarConnector = jarConnector_;
        man = man_;
    }

    function setTimelock(Timelock timelock_) external {
        require(timelock == Timelock(0), "timelock-already-set");
        timelock = timelock_;
    }

    function propose(address newOwner) external {
        require(jarConnector.round() > 2, "six-months-not-passed");
        require(newOwner != address(0), "newOwner-cannot-be-zero");
        Proposal memory proposal = Proposal({
            forVotes:0,
            newOwner: newOwner
        });
        proposals.push(proposal);
    }

    function vote(uint proposalId, uint cdp) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.newOwner != address(0), "proposal-not-exist");
        require(! proposal.voted[cdp], "already-voted");
        require(msg.sender == man.owns(cdp), "not-cdp-owner");
        
        uint score = jarConnector.getUserScore(bytes32(cdp));
        proposal.forVotes = add(proposal.forVotes, score);
        proposal.voted[cdp] = true;
    }

    function cancelVote(uint proposalId, uint cdp) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.newOwner != address(0), "proposal-not-exist");
        require(proposal.voted[cdp], "not-voted");
        require(msg.sender == man.owns(cdp), "not-cdp-owner");

        uint score = jarConnector.getUserScore(bytes32(cdp));
        proposal.forVotes = sub(proposal.forVotes, score);
        proposal.voted[cdp] = false;
    }

    function queueProposal(uint proposalId) external {
        uint quorum = add(jarConnector.getGlobalScore() / 2, uint(1));
        Proposal memory proposal = proposals[proposalId];
        require(proposal.newOwner != address(0), "proposal-not-exist");
        require(proposal.forVotes >= quorum, "quorum-not-passed");

        timelock.queueTransaction(address(man), 0, "setOwner(address)", abi.encode(proposal.newOwner), 2 days);
    }

    function executeProposal(uint proposalId) external {
        Proposal memory proposal = proposals[proposalId];
        timelock.executeTransaction(address(man), 0, "setOwner(address)", abi.encode(proposal.newOwner), 2 days);
    }
}