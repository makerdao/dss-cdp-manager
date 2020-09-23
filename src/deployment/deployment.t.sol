pragma solidity ^0.5.12;

import { BCdpManagerTestBase, Hevm, FakeUser, FakeOSM, BCdpManager, FakeDaiToUsdPriceFeed } from "./../BCdpManager.t.sol";
import { DssDeployTestBase, Vat, Cat, Spotter, DSValue } from "dss-deploy/DssDeploy.t.base.sol";
import { BCdpScore } from "./../BCdpScore.sol";
import { Pool } from "./../pool/Pool.sol";
import { FakeMember } from "./../pool/Pool.t.sol";
import { LiquidationMachine, PriceFeedLike } from "./../LiquidationMachine.sol";


contract PriceFeed is DSValue {
    function read(bytes32 ilk) external view returns(bytes32) {
        ilk; //shh
        return read();
    }
}

contract FakeCat {
    function ilks(bytes32 ilk) external pure returns(uint flip, uint chop, uint dunk) {
        ilk; //shh
        return (0, 1130000000000000000, 0);
    }
}

contract FakeJug {
    function ilks(bytes32 ilk) public view returns(uint duty, uint rho) {
        duty = 1e27;
        rho = now;
        ilk; // shhhh
    }
    function base() public pure returns(uint) {
        return 0;
    }
}

contract FakeEnd {
    FakeCat public cat;
    constructor() public {
        cat = new FakeCat();
    }
}

contract FakeScore {
    function updateScore(uint cdp, bytes32 ilk, int dink, int dart, uint time) external {

    }
}

contract VatDeployer {
    Vat public vat;
    Spotter public spotter;
    PriceFeed public pipETH;
    FakeEnd public end;
    BCdpManager public man;
    Pool public pool;
    FakeOSM public osm;
    FakeMember public member;
    BCdpScore public score;
    FakeDaiToUsdPriceFeed public dai2usdPriceFeed;

    uint public cdpUnsafe;
    uint public cdpUnsafeNext;
    uint public cdpCustom;

    constructor() public {
        vat = new Vat();
        vat.rely(msg.sender);
        //vat.deny(address(this));

        pipETH = new PriceFeed();

        spotter = new Spotter(address(vat));
        spotter.rely(msg.sender);
        //spotter.deny(address(this));

        pipETH.poke(bytes32(uint(300 * 10 ** 18))); // Price 300 DAI = 1 ETH (precision 18)
        osm = new FakeOSM();
        osm.setPrice(uint(300 * 10 ** 18));
        //pipETH.setOwner(msg.sender);
        spotter.file("ETH-A", "pip", address(pipETH)); // Set pip
        spotter.file("par", 1000000000000000000000000000);
        spotter.file("ETH-A", "mat", 1500000000000000000000000000);

        vat.rely(address(spotter));

        end = new FakeEnd();
        //cat.rely(msg.sender);
        //cat.file("ETH-A", "chop", 1130000000000000000000000000);

        // set VAT cfg
        vat.init("ETH-A");
        vat.file("Line", 568000000000000000000000000000000000000000000000000000);
        vat.file("ETH-A", "spot", 260918853648800000000000000000);
        vat.file("ETH-A", "line", 340000000000000000000000000000000000000000000000000000);
        vat.file("ETH-A", "dust", 20000000000000000000000000000000000000000000000);
        //vat.fold("ETH-A", address(0), 1020041883692153436559184034);

        spotter.poke("ETH-A");

        dai2usdPriceFeed = new FakeDaiToUsdPriceFeed();
        pool = new Pool(address(vat), address(0x12345678), address(spotter), address(new FakeJug()), address(dai2usdPriceFeed));
        score = BCdpScore(address(new FakeScore())); //new BCdpScore();
        man = new BCdpManager(address(vat), address(end), address(pool), address(pipETH), address(score));
        //score.setManager(address(man));
        pool.setCdpManager(man);
        pool.setOsm("ETH-A", address(osm));
        address[] memory members = new address[](2);
        member = new FakeMember();
        members[0] = address(member);
        members[1] = 0xf214dDE57f32F3F34492Ba3148641693058D4A9e;
        pool.setMembers(members);
        pool.setIlk("ETH-A", true);
        pool.setProfitParams(94, 100);
        pool.setOwner(msg.sender);
    }

    function poke(int ink, int art) public {
        member.doHope(vat, address(pool));

        pipETH.poke(bytes32(uint(300 * 10 ** 18))); // Price 300 DAI = 1 ETH (precision 18)
        spotter.poke("ETH-A");
        osm.setPrice(uint(300 * 10 ** 18));
        // send ton of gem to holder
        vat.slip("ETH-A", msg.sender, 1e18 * 1e6);
        vat.slip("ETH-A", address(this), 1e18 * 1e20);

        // get tons of dai
        uint cdp = man.open("ETH-A", address(this));
        vat.flux("ETH-A", address(this), man.urns(cdp), 1e7 * 1 ether);
        man.frob(cdp, 1e6 * 1 ether, 1e7 * 10 ether);
        man.move(cdp, address(member), 1e6 * 1 ether * 1e27);
        man.move(cdp, address(0xf214dDE57f32F3F34492Ba3148641693058D4A9e), 1e6 * 1 ether * 1e27);

        cdpUnsafe = man.open("ETH-A", address(this));
        vat.flux("ETH-A", address(this), man.urns(cdpUnsafe), 1e7 * 1 ether);
        man.frob(cdpUnsafe, 1 ether, 100 ether);

        cdpUnsafeNext = man.open("ETH-A", address(this));
        vat.flux("ETH-A", address(this), man.urns(cdpUnsafeNext), 1e7 * 1 ether);
        man.frob(cdpUnsafeNext, 1 ether, 98 ether);

        cdpCustom = man.open("ETH-A", address(this));
        vat.flux("ETH-A", address(this), man.urns(cdpCustom), 1e7 * 1 ether);
        man.frob(cdpCustom, ink, art);

        pipETH.poke(bytes32(uint(149 ether)));
        osm.setPrice(uint(146 ether));
        spotter.poke("ETH-A");
    }
}

contract UserDeployment {
    address constant VAT = 0xbA987bDB501d131f766fEe8180Da5d81b34b69d9;
    address constant END = 0x24728AcF2E2C403F5d2db4Df6834B8998e56aA5F;
    address constant POOL = address(0x0);
    address constant REAL = 0x75dD74e8afE8110C8320eD397CcCff3B8134d981;

    address public manager;

    constructor() public {
        BCdpScore score = new BCdpScore();
        BCdpManager man = new BCdpManager(VAT, END, POOL, REAL, address(score));
        score.setManager(address(man));
        score.spin();

        manager = address(man);
    }
}


contract DeploymentTest is BCdpManagerTestBase {
    uint currTime;
    FakeMember member;
    FakeMember[] members;
    FakeMember nonMember;
    address constant JAR = address(0x1234567890);

    VatDeployer deployer;

    function setUp() public {
        super.setUp();

        currTime = now;
        hevm.warp(currTime);

        address[] memory memoryMembers = new address[](4);
        for(uint i = 0 ; i < 5 ; i++) {
            FakeMember m = new FakeMember();
            seedMember(m);
            m.doHope(vat, address(pool));

            if(i < 4) {
                members.push(m);
                memoryMembers[i] = address(m);
            }
            else nonMember = m;
        }

        pool.setMembers(memoryMembers);

        member = members[0];


    }

    function getMembers() internal view returns(address[] memory) {
        address[] memory memoryMembers = new address[](members.length);
        for(uint i = 0 ; i < members.length ; i++) {
            memoryMembers[i] = address(members[i]);
        }

        return memoryMembers;
    }

    function testDeployer() public {

        deployer = new VatDeployer();

        deployer.poke(1 ether, 20 ether);
        deployer.poke(2 ether, 30 ether);

        assertTrue(deployer.vat().gem("ETH-A", address(this)) >= 1e18 * 1e6);
        assertEq(deployer.vat().live(), 1);

        uint cdp1 = deployer.cdpUnsafe();
        uint cdp2 = deployer.cdpUnsafeNext();
        uint cdp3 = deployer.cdpCustom();

        address urn = deployer.man().urns(cdp3);
        (uint ink, uint art) = deployer.vat().urns("ETH-A", urn);
        assertEq(ink, 2 ether);
        assertEq(art, 30 ether);

        uint dartX;
        (dartX,,) = deployer.pool().topAmount(cdp1);
        assertTrue(dartX > 0);
        (dartX,,) = deployer.pool().topAmount(cdp2);
        assertTrue(dartX > 0);

        FakeMember m = deployer.member();
        Pool p = deployer.pool();
        Vat v = deployer.vat();

        m.doHope(vat, address(p));
        m.doDeposit(p, 1e22 * 1e27);
        assertEq(p.rad(address(m)), 1e22 * 1e27);
        m.doTopup(p, cdp1);
        m.doBite(p, cdp1, 100 ether, 0);

        assertEq(v.gem("ETH-A", address(m)), 712885906040268456);

        m.doTopup(p, cdp2);
    }

    function openCdp(uint ink, uint art) internal returns(uint){
        uint cdp = manager.open("ETH", address(this));

        weth.mint(ink);
        weth.approve(address(ethJoin), ink);
        ethJoin.join(manager.urns(cdp), ink);

        manager.frob(cdp, int(ink), int(art));

        return cdp;
    }

    function seedMember(FakeMember m) internal {
        uint cdp = openCdp(1e3 ether, 1e3 ether);
        manager.move(cdp, address(m), 1e3 ether * RAY);
    }

    function timeReset() internal {
        currTime = now;
        hevm.warp(currTime);
    }

    function forwardTime(uint deltaInSec) internal {
        currTime += deltaInSec;
        hevm.warp(currTime);
    }
}
