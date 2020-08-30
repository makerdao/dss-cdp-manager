pragma solidity ^0.5.12;

import {ScoringMachine} from "../user-rating/contracts/ScoringMachine.sol";

contract BCdpScore is ScoringMachine {
    address public manager;

    modifier onlyManager {
        require(msg.sender == manager, "not-manager");
        _;
    }

    function setManager(address newManager) external onlyOwner {
        manager = newManager;
    }

    function user(uint cdp) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore",cdp));
    }

    function inkAsset(bytes32 ilk) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore","ink",ilk));
    }

    function artAsset(bytes32 ilk) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore","art",ilk));
    }

    function slashAsset(bytes32 ilk) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore","slash-art",ilk));
    }

    function updateScore(uint cdp, bytes32 ilk, int dink, int dart, uint time) external onlyManager {
        updateScore(user(cdp), inkAsset(ilk), dink, time);
        updateScore(user(cdp), artAsset(ilk), dart, time);
    }

    function slashScore(uint cdp, bytes32 ilk, int dart, uint time) external onlyOwner {
        updateScore(user(cdp), slashAsset(ilk), dart, time);
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

    function getSlashScore(uint cdp, bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(user(cdp),slashAsset(ilk),time,spinStart,0);
    }

    function getSlashGlobalScore(bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(GLOBAL_USER,slashAsset(ilk),time,spinStart,0);
    }
}
