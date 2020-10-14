pragma solidity ^0.5.12;

import { DSAuth } from "ds-auth/auth.sol";
import { BCdpManager } from "../BCdpManager.sol";
import { Math } from "../Math.sol";

contract GovernanceExecutor is DSAuth, Math {

    BCdpManager public man;
    uint public delay;
    mapping(address => uint) public requests;
    address public governance;

    event RequestPoolUpgrade(address indexed pool);
    event PoolUpgraded(address indexed pool);

    constructor(address man_, uint delay_) public {
        man = BCdpManager(man_);
        delay = delay_;
    }

    /**
     * @dev Sets governance address
     * @param governance_ Address of the governance
     */
    function setGovernance(address governance_) external auth {
        require(governance == address(0), "governance-already-set");
        governance = governance_;
    }

    /**
     * @dev Transfer admin of BCdpManager
     * @param owner New admin address
     */
    function doTransferAdmin(address owner) external {
        require(msg.sender == governance, "unauthorized");
        man.setOwner(owner);
    }

    /**
     * @dev Request pool contract upgrade
     * @param pool Address of new pool contract
     */
    function reqUpgradePool(address pool) external auth {
        requests[pool] = now;
        emit RequestPoolUpgrade(pool);
    }

    /**
     * @dev Drop upgrade pool request
     * @param pool Address of pool contract
     */
    function dropUpgradePool(address pool) external auth {
        delete requests[pool];
    }

    /**
     * @dev Execute pool contract upgrade after delay
     * @param pool Address of the new pool contract
     */
    function execUpgradePool(address pool) external {
        uint reqTime = requests[pool];
        require(reqTime != 0, "request-not-valid");
        require(now >= add(reqTime, delay), "delay-not-over");
        
        delete requests[pool];
        man.setPoolContract(pool);
        emit PoolUpgraded(pool);
    }
}