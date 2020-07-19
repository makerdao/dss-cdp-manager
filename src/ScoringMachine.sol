pragma solidity ^0.5.12;


import { DSAuth } from "ds-auth/auth.sol";
import { Math } from "./Math.sol";

// TODO - safe math, auth
contract ScoringMachine is DSAuth, Math {
    // get out of the user rating system - TODO - move to scoring machine
    mapping (uint => bool) public out;

    struct Out {
        uint cdp;
        uint time;
    }

    Out[] public quitters;

    function quitBScore(uint cdp) internal {
        quitters.push(Out({cdp:cdp, time:now}));
        out[cdp] = true;
    }

    struct Info {
        // total score so far
        uint score;

        // current ink
        uint ink;

        // time when last score update was made
        uint last;
    }

    struct Round {
        // global data
        uint start;
        uint end;

        Info global; // global data
        mapping(uint => Info) cdp; // per cdp data
    }

    uint                   public round;
    mapping(uint => Round) roundData;

    function spin(uint start, uint end) external auth { // start a new round
        round++;

        roundData[round].start = start;
        roundData[round].end = end;
    }

    function infoScore(Info storage info, uint start, uint time) internal view returns(uint) {
        uint last = info.last;
        if(last == 0) last = start;

        return add(info.score, mul(info.ink, sub(time,last)));
    }

    function updateInfo(Info storage info, int dink, uint time, uint start) internal {
        uint last = info.last;
        if(last == 0) last = start;

        info.score = infoScore(info, start, time);
        info.ink = add(info.ink, dink);
        info.last = time;
    }

    function updateScore(uint cdp, int dink, uint time) internal {
        if(out[cdp]) return;

        uint start = roundData[round].start;
        uint end   = roundData[round].end;

        // check that round started
        if(time < start) return;
        if(time > end)   return;

        Info storage global = roundData[round].global;
        Info storage local  = roundData[round].cdp[cdp];

        updateInfo(global, dink, time, start);
        updateInfo(local, dink, time, start);
    }

    function getScore(uint cdp, uint roundNum, uint time) external view returns(uint cdpScore, uint score) {
        uint start = roundData[roundNum].start;
        uint end   = roundData[roundNum].end;

        // check that round started
        if(time < start) return (0, 0);
        if(time > end)   time = end;

        Info storage global = roundData[roundNum].global;
        Info storage local  = roundData[roundNum].cdp[cdp];


        cdpScore = infoScore(local, start, time);
        score    = infoScore(global, start, time);
    }
}
