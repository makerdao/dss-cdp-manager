pragma solidity ^0.5.12;

contract BCdpScoreLike {
    function updateScore(uint cdp, bytes32 ilk, int dink, int dart, uint time) external;
}

contract BCdpScoreConnector {
    BCdpScoreLike public score;
    mapping(uint => uint) public out;

    constructor(BCdpScoreLike score_) public {
        score = score_;
    }

    function setScoreContract(BCdpScoreLike bcdpScore) internal {
        score = bcdpScore;
    }

    function updateScore(uint cdp, bytes32 ilk, int dink, int dart, uint time) internal {
        if(out[cdp] == 0) score.updateScore(cdp,ilk,dink,dart,time);
    }

    function quitScore(uint cdp) internal {
        if(out[cdp] == 0) out[cdp] = now;
    }
}
