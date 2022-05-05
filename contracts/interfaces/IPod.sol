// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "./IERC4626.sol";

/**
 * @title PoolTogether Pod Vault specification
 * @notice Interface of PoolTogether Pod Vault extension to ERC-4626
 */
interface IPod is IERC4626 {
    /**
     * @dev Emitted when a batch is deposited in the PrizePool
     * @param amount Total amount of underlying assets deposited in the PrizePool
     */
    event BatchFloat(uint256 amount);

    /**
     * @dev Emitted when prize payouts are claimed by a user
     * TODO: currently not being used!
     * @param user The user who claimed the prize
     * @param amount The payout amount
     */
    event Claimed(address indexed user, uint256 amount);

    /**
     * @dev Emitted when prize payouts are claimed by the Pod.
     * @param amount The payout amount
     */
    event PodClaimed(uint256 amount);

    /**
     * @notice Returns the address of the PrizePool that the Pod is bound to.
     * @return The address of the prize pool
     */
    function prizePool() external view returns (address);

    /**
     * @notice Return the price of a single Pod vault share in terms of the underlying asset.
     * @return Pod share price in underlying token units
     */
    function getPricePerShare() external view returns (uint256);

    /**
     * @notice Deposit Pod float balance (underlying assets not deposited into PrizePool yet) in the PrizePool.
     *         Allows batched deposits into the underlying PrizePool.
     *         Should be called periodically.
     * @dev Deposits the current float into the PrizePool.
     *      Emits {BatchFloat} event
     * @return The amount of underlying assets deposited into the PrizePool.
     */
    function batch() external returns (uint256);
}
