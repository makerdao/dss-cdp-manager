pragma solidity ^0.5.12;

import { BCdpScore } from "./BCdpScore.sol";
import { BCdpManager } from "./BCdpManager.sol";
import { Math } from "./Math.sol";

contract JarConnector is Math {
    BCdpScore   public score;
    BCdpManager public man;
    bytes32[]   public ilks;
    // ilk => supported
    mapping(bytes32 => bool) public milks;

    // end of every round
    uint[2] public end;
    // start time of every round
    uint[2] public start;

    uint public round;

    constructor(
        bytes32[] memory _ilks,
        uint[2] memory _duration
    ) public {
        ilks = _ilks;

        for(uint i = 0; i < _ilks.length; i++) {
            milks[_ilks[i]] = true;
        }

        end[0] = now + _duration[0];
        end[1] = now + _duration[0] + _duration[1];

        round = 0;
    }

    function setManager(address _manager) public {
        require(man == BCdpManager(0), "manager-already-set");
        man = BCdpManager(_manager);
        score = BCdpScore(address(man.score()));
    }

    // callable by anyone
    function spin() public {
        if(round == 0) {
            round++;
            score.spin();
            start[0] = score.start();
        }
        if(round == 1 && now > end[0]) {
            round++;
            score.spin();
            start[1] = score.start();
        }
        if(round == 2 && now > end[1]) {
            round++;        
            // score is not counted anymore, and this must be followed by contract upgrade
            score.spin();
        }
    }

    function getUserScore(bytes32 user) external view returns (uint) {
        if(round == 0) return 0;

        uint cdp = uint(user);
        bytes32 ilk = man.ilks(cdp);

        // Should return 0 score for unsupported ilk
        if( ! milks[ilk]) return 0;

        if(round == 1) return 2 * score.getArtScore(cdp, ilk, now, start[0]);

        uint firstRoundScore = 2 * score.getArtScore(cdp, ilk, start[1], start[0]);
        uint time = now;
        if(round > 2) time = end[1];

        return add(score.getArtScore(cdp, ilk, time, start[1]), firstRoundScore);
    }

    function getGlobalScore() external view returns (uint) {
        if(round == 0) return 0;

        if(round == 1) return 2 * getArtGlobalScore(now, start[0]);

        uint firstRoundScore = 2 * getArtGlobalScore(start[1], start[0]);
        uint time = now;
        if(round > 2) time = end[1];

        return add(getArtGlobalScore(time, start[1]), firstRoundScore);
    }

    function getGlobalScore(bytes32 ilk) external view returns (uint) {
        if(round == 0) return 0;

        if(round == 1) return 2 * score.getArtGlobalScore(ilk, now, start[0]);

        uint firstRoundScore = 2 * score.getArtGlobalScore(ilk, start[1], start[0]);
        uint time = now;
        if(round > 2) time = end[1];

        return add(score.getArtGlobalScore(ilk, time, start[1]), firstRoundScore);
    }

    function getArtGlobalScore(uint time, uint spinStart) internal view returns (uint totalScore) {
        for(uint i = 0; i < ilks.length; i++) {
            totalScore = add(totalScore, score.getArtGlobalScore(ilks[i], time, spinStart));
        }
    }

    function toUser(bytes32 user) external view returns (address) {
        return man.owns(uint(user));
    }
}
