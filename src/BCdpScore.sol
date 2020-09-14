pragma solidity ^0.5.12;

import { ScoringMachine } from "../user-rating/contracts/score/ScoringMachine.sol";
import { BCdpManager } from "./BCdpManager.sol";

contract ScoreConnectorLike {
    function left(uint cdp) public returns (uint);
}

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

    function slashScore(uint maliciousCdp) external {
        address urn = manager.urns(maliciousCdp);
        bytes32 ilk = manager.ilks(maliciousCdp);

        (, uint realArt) = manager.vat().urns(ilk, urn);

        bytes32 maliciousUser = user(maliciousCdp);
        bytes32 asset = artAsset(ilk);

        uint left = ScoreConnectorLike(address(manager)).left(maliciousCdp);
        uint time = 0;
        int dart = 0;

        uint calculatedArt = getCurrentBalance(maliciousUser, asset);
        if(left > 0) {
            time = left > start ? left : start;
            dart = -int(calculatedArt);
        } else {
            require(realArt < calculatedArt, "slashScore-cdp-is-ok");
            dart = int(realArt) - int(calculatedArt);
            time = sub(now, 30 days);
            if(time < start) time = start;
        }
        
        updateScore(maliciousUser, asset, dart, time);
    }

    function getArtScore(uint cdp, bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(user(cdp), artAsset(ilk), time, spinStart, 0);
    }

    function getArtGlobalScore(bytes32 ilk, uint time, uint spinStart) public view returns(uint) {
        return getScore(GLOBAL_USER, artAsset(ilk), time, spinStart, 0);
    }
}
