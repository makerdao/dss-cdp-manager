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

    function slashScore(uint maliciousCdp) external {
        address urn = manager.urns(maliciousCdp);
        bytes32 ilk = manager.ilks(maliciousCdp);

        (, uint realArt) = manager.vat().urns(ilk, urn);

        bytes32 maliciousUser = user(maliciousCdp);
        bytes32 asset = artAsset(ilk);

        uint calculatedArt = getCurrentBalance(maliciousUser, asset);
        require(realArt < calculatedArt, "slashScore-cdp-is-ok");
        int dart = int(realArt) - int(calculatedArt);

        uint time = sub(now, 30 days);
        if(time < start) time = start;

        updateScore(maliciousUser, asset, dart, time);
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
