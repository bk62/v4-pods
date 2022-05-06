// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./Pod.sol";

/**
 * @title PodFactory - Clones Pod instances
 * @notice Simple, cheap and immutable Pod instances factory through cloning.
 * @dev Uses OpenZeppleing Clones which implements EIP-1167
 */
contract PodFactory {
    /**
     * @notice Contract template for deploying proxied Pods
     */
    Pod public podInstance;

    /**
     * Events:
     * _______
     */

    /**
     * @dev Emitted when a new Pod is created.
     */
    event PodCreated(Pod indexed pod);

    /**
     * @notice Initialized the PodFactory with a Pod instance.
     */
    constructor() {
        // Pod instance
        podInstance = new Pod();
    }

    /**
     *
     * @param prizePool_ The PrizePool this Pod Vault is bound to
     * @param prizeDistributor_ The PrizeDistributor to claim prize payouts from
     * @param manager_ Owner address
     */
    function create(
        IPrizePool prizePool_,
        IPrizeDistributor prizeDistributor_,
        address manager_
    ) external returns (address pod) {
        require(address(manager_) != address(0), "PodFactory:manager-not-zero-address");

        // Deploy pod
        Pod _pod = Pod(Clones.clone(address(podInstance)));

        // Init pod
        _pod.initialize(prizePool_, prizeDistributor_);

        // Pod set manager
        _pod.setManager(manager_);

        // Set msg.sender as pod owner
        _pod.transferOwnership(msg.sender);

        // emit event
        emit PodCreated(_pod);

        // return addr
        return address(_pod);
    }
}
