pragma solidity ^0.5.16;

import { BCdpManagerTestBase, FakeUser, BCdpScoreLike } from "../BCdpManager.t.sol";
import { JarConnector } from "../JarConnector.sol";
import { Timelock } from "./Timelock.sol";
import { Migrate } from "./Migrate.sol";

contract MigrateTest is BCdpManagerTestBase {

    Migrate migrate;
    Timelock timelock;
    JarConnector jarConnector;
    FakeUser[] users;
    uint[] cdps; // users cdps

    function setUp() public {
        super.setUp();
        timeReset();
        uint[2] memory durations;
        durations[0] = 30 days;
        durations[1] = 5 * 30 days;

        jarConnector = new JarConnector(address(manager), address(ethJoin), "ETH", durations);
        score.transferOwnership(address(jarConnector));
        jarConnector.spin();

        migrate = new Migrate(jarConnector, manager);
        timelock = new Timelock(address(migrate), 2 days);
        migrate.setTimelock(timelock);

        (users, cdps) = createUsers(10);
        
    }

    function testValidateSetup() public {
        assertEq(address(migrate.timelock()), address(timelock));
        assertEq(timelock.admin(), address(migrate));
        assertEq(timelock.delay(), 2 days);
    }

    function testFailSetTimelock() public {
        Timelock fakeTimelock = new Timelock(address(migrate), 2 days);
        migrate.setTimelock(fakeTimelock);
    }

    function testFailNewProposalBeforeSixMonths() public {
        FakeUser user = new FakeUser();
        migrate.propose(address(user));
    }

    function testNewProposal() public {
        forwardTimeSixMonths();

        FakeUser user = new FakeUser();
        migrate.propose(address(user));

        (uint forVotes, , address owner) = migrate.proposals(0);
        assertEq(forVotes, 0);
        assertEq(owner, address(user));
    }

    function testAllowMultipleProposal() public {
        forwardTimeSixMonths();

        // first proposal
        FakeUser user1 = new FakeUser();
        uint proposalId = migrate.propose(address(user1));

        (uint forVotes, , address owner) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);
        assertEq(owner, address(user1));

        // second proposal
        FakeUser user2 = new FakeUser();
        proposalId = migrate.propose(address(user2));

        (forVotes, , owner) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);
        assertEq(owner, address(user2));
    }

    function testVote() public {
        forwardTimeSixMonths();

        FakeUser user = new FakeUser();
        uint proposalId = migrate.propose(address(user));

        (uint forVotes, ,) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);

        for(uint i = 0; i < 10; i++) {
            users[i].doVote(migrate, proposalId, cdps[i]);
        }

        (forVotes, ,) = migrate.proposals(proposalId);
        assertTrue(forVotes > 0);
    }

    function testCancelVote() public {
        forwardTimeSixMonths();

        FakeUser user = new FakeUser();
        uint proposalId = migrate.propose(address(user));

        (uint forVotes, ,) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);

        for(uint i = 0; i < 10; i++) {
            users[i].doVote(migrate, proposalId, cdps[i]);
        }

        (forVotes, ,) = migrate.proposals(proposalId);
        assertTrue(forVotes > 0);

        for(uint i = 0; i < 10; i++) {
            users[i].doCancelVote(migrate, proposalId, cdps[i]);
        }

        (forVotes, ,) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);
    }

    function testFailCannotVoteAgain() public {
        forwardTimeSixMonths();

        FakeUser user = new FakeUser();
        uint proposalId = migrate.propose(address(user));

        (uint forVotes, ,) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);

        users[0].doVote(migrate, proposalId, cdps[0]);
        users[0].doVote(migrate, proposalId, cdps[0]);
    }

    function testFailQueueWhenNoProposal() public {
        migrate.queueProposal(0);
    }

    function testFailExecuteWhenNoProposal() public {
        migrate.executeProposal(0);
    }

    function testFailQueueWhenQuorumNotReached() public {
        forwardTimeSixMonths();

        uint globalScore = jarConnector.getGlobalScore();
        assertTrue(globalScore > 0);
        uint quorumScore = (globalScore / 2) + 1;

        FakeUser user = new FakeUser();
        uint proposalId = migrate.propose(address(user));

        (uint forVotes, ,) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);

        // only 3 users vote
        uint userTotalScore;
        for(uint i = 0; i < 3; i++) {
            users[i].doVote(migrate, proposalId, cdps[i]);
            uint userScore = jarConnector.getUserScore(bytes32(cdps[i]));
            userTotalScore += userScore;
        }

        (forVotes, ,) = migrate.proposals(proposalId);
        assertTrue(forVotes > 0);
        
        assertTrue(userTotalScore < quorumScore);

        migrate.queueProposal(proposalId);
    }

    function testSuccessfulQueue() public {
        manager.setOwner(address(timelock));
        forwardTimeSixMonths();

        uint globalScore = jarConnector.getGlobalScore();
        assertTrue(globalScore > 0);
        uint quorumScore = (globalScore / 2) + 1;

        FakeUser user = new FakeUser();
        uint proposalId = migrate.propose(address(user));

        (uint forVotes, uint eta,) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);
        assertEq(eta, 0);

        // only 6 users vote
        uint userTotalScore;
        for(uint i = 0; i < 6; i++) {
            users[i].doVote(migrate, proposalId, cdps[i]);
            uint userScore = jarConnector.getUserScore(bytes32(cdps[i]));
            userTotalScore += userScore;
        }

        (forVotes, eta,) = migrate.proposals(proposalId);
        assertTrue(forVotes > 0);
        assertTrue(forVotes > quorumScore);
        assertTrue(userTotalScore > quorumScore);
        assertEq(eta, 0);

        migrate.queueProposal(proposalId);
        (, eta,) = migrate.proposals(proposalId);
        assertEq(eta, now + 2 days);
    }

    function testFailQueueAgain() public {
        manager.setOwner(address(timelock));
        forwardTimeSixMonths();

        FakeUser user = new FakeUser();
        uint proposalId = migrate.propose(address(user));

        // only 6 users vote
        for(uint i = 0; i < 6; i++) {
            users[i].doVote(migrate, proposalId, cdps[i]);
        }

        migrate.queueProposal(proposalId);

        // must fail
        migrate.queueProposal(proposalId);
    }

    function testSuccessExecute() public {
        manager.setOwner(address(timelock));
        forwardTimeSixMonths();

        FakeUser newOwner = new FakeUser();
        uint proposalId = migrate.propose(address(newOwner));

        // only 6 users vote
        for(uint i = 0; i < 6; i++) {
            users[i].doVote(migrate, proposalId, cdps[i]);
        }

        migrate.queueProposal(proposalId);

        forwardTime(2 days);

        migrate.executeProposal(proposalId);

        assertEq(manager.owner(), address(newOwner));
    }

    function testUpgradeContractsAndMigrate() public {
        pool = deployNewPoolContract();
        score = deployNewScoreContract();

        manager.setPoolContract(address(pool));
        manager.setScoreContract(BCdpScoreLike(address(score)));

        manager.setOwner(address(timelock));

        forwardTimeSixMonths();

        FakeUser newOwner = new FakeUser();
        uint proposalId = migrate.propose(address(newOwner));

        // only 6 users vote
        for(uint i = 0; i < 6; i++) {
            users[i].doVote(migrate, proposalId, cdps[i]);
        }

        migrate.queueProposal(proposalId);

        forwardTime(2 days);

        migrate.executeProposal(proposalId);

        assertEq(manager.owner(), address(newOwner));

    }

    // Helper functions
    function openCdp(uint ink, uint art) internal returns(uint){
        uint cdp = manager.open("ETH", address(this));

        weth.mint(ink);
        weth.approve(address(ethJoin), ink);
        ethJoin.join(manager.urns(cdp), ink);

        manager.frob(cdp, int(ink), int(art));

        return cdp;
    }

    function createUsers(uint number) public returns (FakeUser[] memory users_, uint[] memory cdps_) {
        users_ = new FakeUser[](number);
        cdps_ = new uint[](number);
        for(uint i = 0; i < number; i++) {
            (users_[i], cdps_[i]) = createFakeUser();
        }
    }

    function createFakeUser() public returns (FakeUser, uint) {
        FakeUser user = new FakeUser();
        uint cdp = openCdp(10 ether, 100 ether);
        manager.give(cdp, address(user));

        forwardTime(10);
        return (user, cdp);
    }

    function forwardTimeSixMonths() public {
        assertEq(jarConnector.round(), 1);
        forwardTime(30 days); // 1 month

        jarConnector.spin();
        assertEq(jarConnector.round(), 2);
        
        forwardTime(5 * 30 days); // 5 months
        jarConnector.spin();

        assertEq(jarConnector.round(), 3);
    }
}