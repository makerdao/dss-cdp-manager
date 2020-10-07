pragma solidity ^0.5.12;

import { BCdpManagerTestBase, FakeUser, BCdpScoreLike } from "../BCdpManager.t.sol";
import { JarConnector } from "../JarConnector.sol";
import { Migrate } from "./Migrate.sol";
import { GovernanceExecutor } from "./GovernanceExecutor.sol";

contract MigrateTest is BCdpManagerTestBase {

    Migrate migrate;
    JarConnector jarConnector;
    GovernanceExecutor executor;
    FakeUser[] users;
    uint[] cdps; // users cdps

    function setUp() public {
        super.setUp();
        timeReset();
        uint[2] memory durations;
        durations[0] = 30 days;
        durations[1] = 5 * 30 days;

        address[] memory gemJoins = new address[](1);
        gemJoins[0] = address(ethJoin);

        bytes32[] memory ilks = new bytes32[](1);
        ilks[0] = "ETH";

        executor = new GovernanceExecutor(address(manager), 2 days);
        jarConnector = new JarConnector(address(manager), gemJoins, ilks, durations);
        score.transferOwnership(address(jarConnector));
        jarConnector.spin();

        migrate = new Migrate(jarConnector, manager, executor);
        executor.setGovernance(address(migrate));

        (users, cdps) = createUsers(10);
        
    }

    function testValidateSetup() public {
        assertEq(executor.governance(), address(migrate));
        assertEq(address(migrate.executor()), address(executor));
        assertEq(jarConnector.round(), 1);
        assertEq(score.owner(), address(jarConnector));
    }

    function testFailProposeWhenZeroOwner() public {
        migrate.propose(address(0));
    }

    function testFailProposeWhenRoundOne() public {
        assertEq(jarConnector.round(), 1);
        FakeUser user = new FakeUser();
        migrate.propose(address(user));
    }

    function testFailProposeWhenRoundTwo() public {
        assertEq(jarConnector.round(), 1);

        forwardToRoundTwo();
        assertEq(jarConnector.round(), 2);

        FakeUser user = new FakeUser();
        migrate.propose(address(user));
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

    function testUsersVotingPower() public {
        forwardTimeSixMonths();

        uint[] memory usersScore = new uint[](10);

        // Ensure each user has different voting power
        for(uint i = 0; i < 10; i++) {
            uint us = jarConnector.getUserScore(bytes32(cdps[i]));
            for(uint j = 0; j < usersScore.length; j++) {
                assertTrue(us != usersScore[j]);
            }
            usersScore[i] = us;
        }
    }

    function testVote() public {
        forwardTimeSixMonths();

        FakeUser user = new FakeUser();
        uint proposalId = migrate.propose(address(user));

        (uint forVotes, ,) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);

        uint userTotalScore = 0;
        for(uint i = 0; i < 10; i++) {
            users[i].doVote(migrate, proposalId, cdps[i]);
            uint userScore = jarConnector.getUserScore(bytes32(cdps[i]));
            userTotalScore += userScore;
        }

        (forVotes, ,) = migrate.proposals(proposalId);
        assertEq(forVotes, userTotalScore);
    }

    function testFailVotingForNonExistingProposal() public {
        forwardTimeSixMonths();

        FakeUser user = new FakeUser();
        uint proposalId = migrate.propose(address(user));

        (uint forVotes, ,address newOwner) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);
        assertEq(newOwner, address(user));

        uint nonExistingProposalId = 1;
        users[0].doVote(migrate, nonExistingProposalId, cdps[0]);
    }

    function testCancelVote() public {
        forwardTimeSixMonths();

        FakeUser user = new FakeUser();
        uint proposalId = migrate.propose(address(user));

        (uint forVotes, ,) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);

        // all 10 votes
        uint totalVotes;
        for(uint i = 0; i < 10; i++) {
            users[i].doVote(migrate, proposalId, cdps[i]);
            uint userScore = jarConnector.getUserScore(bytes32(cdps[i]));
            totalVotes += userScore;
        }

        (forVotes, ,) = migrate.proposals(proposalId);
        assertTrue(forVotes > 0);

        // first 4 cancel their vote
        uint cancelledVotes;
        for(uint i = 0; i < 4; i++) {
            users[i].doCancelVote(migrate, proposalId, cdps[i]);
            uint userScore = jarConnector.getUserScore(bytes32(cdps[i]));
            cancelledVotes += userScore;
        }

        (forVotes, ,) = migrate.proposals(proposalId);
        assertEq(forVotes, totalVotes - cancelledVotes);
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

    function testFailCancelVoteWhenNotVoted() public {
        forwardTimeSixMonths();

        FakeUser user = new FakeUser();
        uint proposalId = migrate.propose(address(user));

        (uint forVotes, ,) = migrate.proposals(proposalId);
        assertEq(forVotes, 0);

        // user1 vote
        users[0].doVote(migrate, proposalId, cdps[0]);

        // must fail when user2 try to cancel his vote (he not voted)
        users[1].doCancelVote(migrate, proposalId, cdps[1]);
    }

    function testFailQueueWhenNoProposal() public {
        migrate.queueProposal(0);
    }

    function testFailExecuteWhenNoProposal() public {
        manager.setOwner(address(executor));
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

    function testFailQueueAndExecuteBeforeDelay() public {
        manager.setOwner(address(executor));
        forwardTimeSixMonths();

        FakeUser user = new FakeUser();
        uint proposalId = migrate.propose(address(user));

        // only 6 users vote
        for(uint i = 0; i < 6; i++) {
            users[i].doVote(migrate, proposalId, cdps[i]);
        }

        migrate.queueProposal(proposalId);

        // must fail
        migrate.executeProposal(proposalId);
    }

    function testSuccessExecute() public {
        manager.setOwner(address(executor));
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

        manager.setOwner(address(executor));

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

    function forwardToRoundTwo() public {
        assertEq(jarConnector.round(), 1);
        forwardTime(30 days); // 1 month

        jarConnector.spin();
        assertEq(jarConnector.round(), 2);
    }

    function forwardTimeSixMonths() public {
        forwardToRoundTwo();
        
        forwardTime(5 * 30 days); // 5 months
        jarConnector.spin();

        assertEq(jarConnector.round(), 3);
    }
}