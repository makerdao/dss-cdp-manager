pragma solidity ^0.5.12;

import { ScoringMachine } from "../user-rating/contracts/score/ScoringMachine.sol";
import { BCdpManager } from "./BCdpManager.sol";

contract BCdpScore is ScoringMachine {
    BCdpManager public manager;

    modifier onlyManager {
        require(msg.sender == address(manager), "not-manager");
        _;
    }

    function setManager(address newManager) external onlyOwner {
        manager = BCdpManager(newManager);
    }

    function user(uint cdp) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore", cdp));
    }

    function artAsset(bytes32 ilk) public pure returns(bytes32) {
        return keccak256(abi.encodePacked("BCdpScore", "art", ilk));
    }

    function updateScore(uint cdp, bytes32 ilk, int dink, int dart, uint time) external onlyManager {
        dink; // shh compiler warning
        updateScore(user(cdp), artAsset(ilk), dart, time);
    }

    function getArtScore(uint cdp, bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(user(cdp), artAsset(ilk), time, spinStart, 0);
    }

    function getArtGlobalScore(bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(GLOBAL_USER, artAsset(ilk), time, spinStart, 0);
    }
}
