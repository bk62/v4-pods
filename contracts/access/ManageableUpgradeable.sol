// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Abstract Manageable contract
 * @dev Adds manageable to OpenZeppelin contracts-upgradeable's OwnableUpgradeable abstract contract.
 *      Almost exactly the same as pooltogether/owner-manager-contracts Manageable contract.
 */
abstract contract ManageableUpgradeable is OwnableUpgradeable {
    address private _manager;

    /**
     * @dev Emitted when `_manager` has been changed.
     * @param previousManager previous `_manager` address.
     * @param newManager new `_manager` address.
     */
    event ManagerTransferred(address indexed previousManager, address indexed newManager);

    /* ============== Initialize =========== */
    /**
     * @dev Initializes the contract by calling OwnerUpgradeable's initializer.
     */
    function __ManageableUpgradeable_init() internal onlyInitializing {
        __Ownable_init();
    }

    function __ManageableUpgradeable_init_unchained() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    /* ============ External Functions ============ */

    /**
     * @notice Gets current `_manager`.
     * @return Current `_manager` address.
     */
    function manager() public view virtual returns (address) {
        return _manager;
    }

    /**
     * @notice Set or change of manager.
     * @dev Throws if called by any account other than the owner.
     * @param _newManager New _manager address.
     * @return Boolean to indicate if the operation was successful or not.
     */
    function setManager(address _newManager) external onlyOwner returns (bool) {
        return _setManager(_newManager);
    }

    /* ============ Internal Functions ============ */

    /**
     * @notice Set or change of manager.
     * @param _newManager New _manager address.
     * @return Boolean to indicate if the operation was successful or not.
     */
    function _setManager(address _newManager) private returns (bool) {
        address _previousManager = _manager;

        require(_newManager != _previousManager, "ManageableUpgradeable/existing-manager-address");

        _manager = _newManager;

        emit ManagerTransferred(_previousManager, _newManager);
        return true;
    }

    /* ============ Modifier Functions ============ */

    /**
     * @dev Throws if called by any account other than the manager.
     */
    modifier onlyManager() {
        require(manager() == msg.sender, "ManageableUpgradeable/caller-not-manager");
        _;
    }

    /**
     * @dev Throws if called by any account other than the manager or the owner.
     */
    modifier onlyManagerOrOwner() {
        require(
            manager() == msg.sender || owner() == msg.sender,
            "ManageableUpgradeable/caller-not-manager-or-owner"
        );
        _;
    }
}
