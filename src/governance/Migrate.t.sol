pragma solidity ^0.5.16;

import { BCdpManagerTestBase, FakeUser } from "../BCdpManager.t.sol";
import { JarConnector } from "../JarConnector.sol";
import { Timelock } from "./Timelock.sol";
import { Migrate } from "./Migrate.sol";

contract MigrateTest is BCdpManagerTestBase {

    Migrate migrate;
    Timelock timelock;
    JarConnector jarConnector;
    FakeUser[] users;

    function setUp() public {
        super.setUp();
        timeReset();
        uint[2] memory durations;
        durations[0] = 30 days;
        durations[1] = 5 * 30 days;

        jarConnector = new JarConnector(address(manager), address(ethJoin), "ETH", durations);
        migrate = new Migrate(jarConnector, manager);
        timelock = new Timelock(address(migrate), 2 days);
        migrate.setTimelock(timelock);

        users = createUsers(10);
        
    }

    function testFailSetTimelock() public {
        Timelock fakeTimelock = new Timelock(address(migrate), 2 days);
        migrate.setTimelock(fakeTimelock);
    }

    function testFailNewProposalBeforeSixMonths() public {
        
    }

    function testNewProposal() public {
        
    }

    function testAllowMultipleProposal() public {

    }

    function testVote() public {

    }

    function testCancelVote() public {

    }

    function testFailCannotVoteAgain() public {

    }

    function testFailQueueWhenNoProposal() public {
        migrate.queueProposal(0);
    }

    function testFailExecuteWhenNoProposal() public {
        migrate.executeProposal(0);
    }

    function testFailQueueWhenQuorumNotReached() public {

    }

    function testUpgradeContractsAndMigrate() public {

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

    function createUsers(uint number) public returns (FakeUser[] memory users_) {
        users_ = new FakeUser[](number);
        for(uint i = 0; i < number; i++) {
            users_[i] = createFakeUser();
        }
    }

    function createFakeUser() public returns (FakeUser) {
        FakeUser user = new FakeUser();
        uint cdp = openCdp(10 ether, 100 ether);
        manager.give(cdp, address(user));

        forwardTime(10);
        return user;
    }

    function reachMigration() public {

    }
}