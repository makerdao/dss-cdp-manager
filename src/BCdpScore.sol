pragma solidity ^0.5.12;

import {ScoringMachine} from "./ScoringMachine.sol";

contract BCdpScore is ScoringMachine {
    function user(uint cdp) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore",cdp));
    }

    function inkAsset(bytes32 ilk) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore","ink",ilk));
    }

    function artAsset(bytes32 ilk) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore","art",ilk));
    }

    function updateScore(uint cdp, bytes32 ilk, int dink, int dart, uint time) internal {
        updateScore(user(cdp), inkAsset(ilk), dink, time);
        updateScore(user(cdp), artAsset(ilk), dart, time);
    }

    function getInkScore(uint cdp, bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(user(cdp),inkAsset(ilk),time,spinStart,0);
    }

    function getInkGlobalScore(bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(GLOBAL_USER,inkAsset(ilk),time,spinStart,0);
    }

    function getArtScore(uint cdp, bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(user(cdp),artAsset(ilk),time,spinStart,0);
    }

    function getArtGlobalScore(bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(GLOBAL_USER,artAsset(ilk),time,spinStart,0);
    }
}
