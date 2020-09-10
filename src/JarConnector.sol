pragma solidity ^0.5.12;

import { BCdpScore } from "./BCdpScore.sol";
import { BCdpManager } from "./BCdpManager.sol";

interface GemJoinLike {
    function exit(address, uint) external;
}

interface VatLike {
    function gem(bytes32 ilk, address user) external view returns(uint);
}

contract JarConnector {
    GemJoinLike ethJoin;
    BCdpScore   score;
    BCdpManager man;
    VatLike     vat;
    bytes32     ilk;

    constructor(address _manager, address _ethJoin, bytes32 _ilk) public {
        man = BCdpManager(_manager);
        vat = VatLike(address(man.vat()));
        score = BCdpScore(address(man.score()));
        ethJoin = GemJoinLike(_ethJoin);
        ilk = _ilk;
    }

    // callable by anyone
    function ethExit(uint wad, bytes32 ilk_) public {
        ilk_; // shh compiler wanring
        ethJoin.exit(address(this),wad);
    }

    function ethExit() public {
        ethExit(vat.gem(ilk, address(this)), ilk);
    }

    function getUserScore(bytes32 user) external view returns (uint) {
        uint cdp = uint(user);
        return score.getArtScore(cdp, ilk, now, score.start());
    }

    function getGlobalScore() external view returns (uint) {
        return score.getArtGlobalScore(ilk, now, score.start());
    }

    function toUser(bytes32 user) external view returns (address) {
        return man.owns(uint(user));
    }
}
