pragma solidity ^0.5.12;

import { BCdpScore } from "./BCdpScore.sol";
import { BCdpManager } from "./BCdpManager.sol";

interface GemJoinLike {
    function exit(address, uint) external;
}

interface VatLike {
    function gem(bytes32 ilk, address user) external view returns(uint);
}

contract JarConnector {
    GemJoinLike ethJoin;
    BCdpScore   score;
    BCdpManager man;
    VatLike     vat;
    bytes32     ilk;

    // end of every round
    uint[2] public end;
    // start time of every round
    uint[2] public start;

    uint public round;

    constructor(address _manager, address _ethJoin, bytes32 _ilk, uint[2] memory _duration) public {
        man = BCdpManager(_manager);
        vat = VatLike(address(man.vat()));
        score = BCdpScore(address(man.score()));
        ethJoin = GemJoinLike(_ethJoin);
        ilk = _ilk;

        end[0] = now + _duration[0];
        end[1] = now + _duration[0] + _duration[1];

        round = 0;
    }

    // callable by anyone
    function spin() public {
        if(round == 0) {
            score.spin();
            start[0] = score.start();
            round++;
        }
        if(round == 1 && now > end[0]) {
            score.spin();
            start[1] = score.start();
            round++;
        }
        if(round == 2 && now > end[1]) {
            // score is not counted anymore, and this must be followed by contract upgrade
            score.spin();
            round++;
        }
    }

    // callable by anyone
    function ethExit(uint wad, bytes32 ilk_) public {
        ilk_; // shh compiler wanring
        ethJoin.exit(address(this), wad);
    }

    function ethExit() public {
        ethExit(vat.gem(ilk, address(this)), ilk);
    }

    function getUserScore(bytes32 user) external view returns (uint) {
        if(round == 0) return 0;

        uint cdp = uint(user);
        if(round == 1) return 2 * score.getArtScore(cdp, ilk, now, start[0]);

        uint firstRoundScore = 2 * score.getArtScore(cdp, ilk, start[1], start[0]);
        uint time = now;
        if(round > 2) time = end[1];

        return score.getArtScore(cdp, ilk, time, start[1]) + firstRoundScore;
    }

    function getGlobalScore() external view returns (uint) {
        if(round == 0) return 0;

        if(round == 1) return 2 * score.getArtGlobalScore(ilk, now, start[0]);

        uint firstRoundScore = 2 * score.getArtGlobalScore(ilk, start[1], start[0]);
        uint time = now;
        if(round > 2) time = end[1];

        return score.getArtGlobalScore(ilk, time, start[1]) + firstRoundScore;
    }

    function toUser(bytes32 user) external view returns (address) {
        return man.owns(uint(user));
    }
}
