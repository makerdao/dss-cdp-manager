pragma solidity ^0.5.12;

import { BCdpScore } from "./BCdpScore.sol";

contract BCdpFullScore is BCdpScore {

    function inkAsset(bytes32 ilk) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore", "ink", ilk));
    }

    function slashAsset(bytes32 ilk) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore", "slash-art", ilk));
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

    function getSlashScore(uint cdp, bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(user(cdp), slashAsset(ilk), time, spinStart, 0);
    }

    function getSlashGlobalScore(bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(GLOBAL_USER, slashAsset(ilk), time, spinStart, 0);
    }
}
