pragma solidity ^0.5.16;

import { DSAuth } from "ds-auth/auth.sol";
import { BCdpManager } from "../BCdpManager.sol";
import { Math } from "../Math.sol";
import { Timelock } from "./TimeLock.sol";
import { JarConnector } from "../JarConnector.sol";

contract Migrate is DSAuth, Math {

    struct Proposal {
        uint forVotes;
        State state;
        mapping (uint => bool) voted; // cdp => voted
    }

    enum State { NONE, VOTING, EXECUTED}

    Timelock public timelock;
    JarConnector public jarConnector;
    BCdpManager public man;
    address public newOwner;

    Proposal public proposal;

    constructor(
        Timelock timelock_,
        JarConnector jarConnector_,
        BCdpManager man_,
        address newOwner_
    ) public {
        timelock = timelock_;
        jarConnector = jarConnector_;
        man = man_;
        newOwner = newOwner_;
    }

    function propose() external auth {
        require(proposal.state == State.NONE, "already-proposed");
        require(jarConnector.round() > 2, "six-months-not-passed");
        proposal = Proposal({
            forVotes:0,
            state: State.VOTING
        });
    }

    function vote(uint cdp) external {
        require(proposal.state == State.VOTING, "not-in-voting");
        require(! proposal.voted[cdp], "already-voted");
        require(msg.sender == man.owns(cdp), "not-cdp-owner");
        
        uint score = jarConnector.getUserScore(bytes32(cdp));
        proposal.forVotes = add(proposal.forVotes, score);
        proposal.voted[cdp] = true;
    }

    function cancelVote(uint cdp) external {
        require(proposal.state == State.VOTING, "not-in-voting");
        require(proposal.voted[cdp], "not-voted");
        require(msg.sender == man.owns(cdp), "not-cdp-owner");

        uint score = jarConnector.getUserScore(bytes32(cdp));
        proposal.forVotes = sub(proposal.forVotes, score);
        proposal.voted[cdp] = false;
    }

    function queueProposal() external {
        require(proposal.state == State.VOTING, "not-in-voting");
        uint quorum = add(jarConnector.getGlobalScore() / 2, uint(1));
        require(proposal.forVotes >= quorum, "quorum-not-passed");

        timelock.queueTransaction(address(man), 0, "setOwner(address)", abi.encode(newOwner), 48 hours);
    }

    function executeProposal() external {
        timelock.executeTransaction(address(man), 0, "setOwner(address)", abi.encode(newOwner), 48 hours);
    }
}