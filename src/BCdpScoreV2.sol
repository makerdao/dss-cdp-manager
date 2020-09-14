pragma solidity ^0.5.12;

import { BCdpScore } from "./BCdpScore.sol";

contract BCdpScoreV2 is BCdpScore {

    function inkAsset(bytes32 ilk) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore", "ink", ilk));
    }

    // @override
    function updateScore(uint cdp, bytes32 ilk, int dink, int dart, uint time) external onlyManager {
        updateScore(user(cdp), inkAsset(ilk), dink, time);
        updateScore(user(cdp), artAsset(ilk), dart, time);
    }

    function getInkScore(uint cdp, bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(user(cdp), inkAsset(ilk), time, spinStart, 0);
    }

    function getInkGlobalScore(bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(GLOBAL_USER, inkAsset(ilk), time, spinStart, 0);
    }
}
