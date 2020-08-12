pragma solidity ^0.5.12;


import { DSAuth } from "ds-auth/auth.sol";
import { Math } from "./Math.sol";

contract ScoringMachine is DSAuth, Math {
    struct AssetScore {
        // total score so far
        uint score;

        // current balance
        uint balance;

        // time when last update was
        uint last;
    }

    // user is bytes32 (will be the sha3 of address or cdp number)
    mapping(bytes32 => mapping(bytes32 => AssetScore[])) public checkpoints;

    mapping(bytes32 => mapping(bytes32 => AssetScore)) public userScore;

    bytes32 constant public GLOBAL_USER = bytes32(0x0);

    uint public start; // start time of the campaign;

    function spin() external auth { // start a new round
        start = now;
    }

    function assetScore(AssetScore storage score, uint time, uint spinStart) internal view returns(uint) {
        uint last = score.last;
        uint currentScore = score.score;
        if(last < spinStart) {
            last = spinStart;
            currentScore = 0;
        }

        return _calcNewScore(currentScore, score.balance, time, last);
    }

    function _calcNewScore(uint currentScore, uint balance, uint time, uint last) private view returns (uint) {
        MathError err; uint deltaTime; uint newScore; uint totalScore;
        (err, deltaTime) = sub_(time,last);
        if(err == MathError.ERROR) return 0;

        (err, newScore) = mul_(balance, deltaTime);
        if(err == MathError.ERROR) return 0;

        (err, totalScore) = add_(currentScore, newScore);
        if(err == MathError.ERROR) return 0;

        return totalScore;
    }

    function addCheckpoint(bytes32 user, bytes32 asset) internal {
        checkpoints[user][asset].push(userScore[user][asset]);
    }

    function updateAssetScore(bytes32 user, bytes32 asset, int dbalance, uint time) internal {
        AssetScore storage score = userScore[user][asset];

        if(score.last < start) addCheckpoint(user,asset);

        score.score = assetScore(score, time, start);
        (MathError err, uint balance) = add_(score.balance, dbalance);
        if(MathError.ERROR == err) {
            score.score = 0;
            score.balance = 0;
        } else {
            score.balance = balance;
        }
        
        score.last = time;
    }

    function updateScore(bytes32 user, bytes32 asset, int dbalance, uint time) internal {
        updateAssetScore(user,asset,dbalance,time);
        updateAssetScore(GLOBAL_USER,asset,dbalance,time);
    }

    function getScore(bytes32 user, bytes32 asset, uint time, uint spinStart, uint checkPointHint) public view returns(uint score) {
        if(time >= userScore[user][asset].last) return assetScore(userScore[user][asset],time,spinStart);

        // else - check the checkpoints
        uint checkpointsLen = checkpoints[user][asset].length;
        if(checkpointsLen == 0) return 0;

        // hint is invalid
        if(checkpoints[user][asset][checkPointHint].last < time) checkPointHint = checkpointsLen - 1;

        for(uint i = checkPointHint ; ; i--){
            if(checkpoints[user][asset][i].last <= time) return assetScore(checkpoints[user][asset][i],time,spinStart);
        }

        // this supposed to be unreachable
        return 0;
    }
}
