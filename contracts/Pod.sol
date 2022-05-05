// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@pooltogether/v4-core/contracts/interfaces/IPrizePool.sol";
import "@pooltogether/v4-core/contracts/interfaces/ITicket.sol";
import "@pooltogether/owner-manager-contracts/contracts/Ownable.sol";
import "@pooltogether/v4-core/contracts/interfaces/IPrizeDistributor.sol";

import "./interfaces/IPod.sol";

/**
 * @title PoolTogether Pod Vault -  Reduce User Gas Costs and Increase Odds of Winning via Collective Deposits.
 * @notice  Pod Vaults increase collective odds of winning and reduce gas costs by batching deposits into the underlying PrizePool.
 *          Implements ERC-4626 as defined in https://eips.ethereum.org/EIPS/eip-4626
 *          Converts deposits into shares in the Pod Vault. The vault deposits the underlying asset tokens in the prize
 *          pool it is bound to and holds thetickets minted by the prize pool.
 */
contract Pod is IPod, ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;
    using Address for address;

    /**
     * Global variables:
     * __________________
     */

    /// @notice Underlying prize pool
    IPrizePool public _prizePool;

    /// @notice Prize distributor
    IPrizeDistributor public _prizeDistributor;

    /// @notice Underlying ERC20 asset tokens
    ///         See {IERC4626-asset}
    /// @dev EIP-4626 requires that the underlying token implements metadata extensions to ERC-20
    IERC20Metadata public _asset;

    /// @notice Underlying PrizePool Ticket
    ITicket public ticket;

    /**
     * Initialize:
     * __________________
     */

    /**
     * @notice Constructor
     * @param owner_ Owner address
     * @param prizePool_ The PrizePool this Pod Vault is bound to
     * @param prizePool_ The PrizeDistributor to claim prize payouts from
     * @param name_ Name of vault share token
     * @param symbol_ Symbol of vault share token
     */
    constructor(
        address owner_,
        IPrizePool prizePool_,
        IPrizeDistributor prizeDistributor_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) Ownable(owner_) {
        require(address(owner_) != address(0), "Pod:owner-not-zero-address");
        require(address(prizePool_) != address(0), "Pod:prize-pool-not-zero-address");
        require(
            address(prizePool_.getToken()) != address(0),
            "Pod:prize-pool-token-not-zero-address"
        );
        require(
            address(prizePool_.getTicket()) != address(0),
            "Pod:prize-pool-ticket-not-zero-address"
        );
        require(address(prizeDistributor_) != address(0), "Pod:prize-distributor-not-zero-address");

        _prizePool = prizePool_;
        _prizeDistributor = prizeDistributor_;

        // Store the underlying PrizePool's underlying asset token and its ticket.
        // The underlying token is this vault's underlying asset as well.
        // The ticket represents ownership of asset that the PrizePool is holding on the vault's behalf.
        _asset = IERC20Metadata(prizePool_.getToken());
        ticket = ITicket(prizePool_.getTicket());
    }

    /**
     * @notice Returns the number of decimals used
     * @dev Unless overridden, same as the number of decimals used by the underlying token.
     */
    function decimals() public view virtual override returns (uint8) {
        return _asset.decimals();
    }

    /**
     * ERC-4626 methods:
     * __________________
     */

    /**
     * Assets totals and share conversions:
     */

    /**
     * @inheritdoc IERC4626
     */
    function asset() public view virtual override returns (address assetTokenAddress) {
        assetTokenAddress = address(_asset);
    }

    /**
     * @inheritdoc IERC4626
     */
    function totalAssets() public view virtual override returns (uint256) {
        return _asset.balanceOf(address(this)) + ticket.balanceOf(address(this));
    }

    /**
     * @inheritdoc IERC4626
     */
    function convertToShares(uint256 assets) public view virtual override returns (uint256 shares) {
        uint256 supply = totalSupply();

        // calculate shares
        if (supply == 0) {
            shares = assets;
        } else {
            shares = (assets * supply) / balance();
        }
    }

    /**
     * @inheritdoc IERC4626
     */
    function convertToAssets(uint256 shares) public view virtual override returns (uint256 assets) {
        uint256 supply = totalSupply();

        // Check totalSupply to precent div by 0
        if (supply > 0) {
            assets = (balance() * shares) / supply;
        } else {
            assets = shares;
        }
    }

    /**
     * Deposits, Mints:
     */

    /**
     * @inheritdoc IERC4626
     * @custom:devdetails Unless overridden, returns `type(uint256).max`
     */
    function maxDeposit(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @inheritdoc IERC4626
     * @custom:devdetails Unless overridden, returns result of {convertToShares}
     */
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        return convertToShares(assets);
    }

    /**
     * @inheritdoc IERC4626
     */
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        nonReentrant
        returns (uint256 shares)
    {
        // Calculate amount of Pod shares corresponding to assets underlying tokens
        shares = previewDeposit(assets);
        // Deposit assets and mint shares
        _deposit(assets, shares, receiver);
    }

    /**
     * @inheritdoc IERC4626
     * @custom:devdetails Unless overridden, returns `type(uint256).max`
     */
    function maxMint(address) public view virtual override returns (uint256 maxShares) {
        return type(uint256).max;
    }

    /**
     * @inheritdoc IERC4626
     * @custom:devdetails Unless overridden,, returns result of {convertToAssets}
     * TODO: EIP-4626 specified this method should round up
     */
    function previewMint(uint256 shares) public view virtual override returns (uint256 assets) {
        // TODO
        // previewMint supposed to round up but convert to assets rounds down!
        return convertToAssets(shares);
    }

    /**
     * @inheritdoc IERC4626
     */
    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        nonReentrant
        returns (uint256 assets)
    {
        // Calculate amount of assets corresponding to requested amount of shares
        assets = previewMint(shares);
        // Deposit assets and mint shares
        _deposit(assets, shares, receiver);
    }

    /**
     * Withdrawals, Redeems:
     */

    /**
     * @inheritdoc IERC4626
     * @custom:devdetails Unless overridden, returns result of {convertToAssets} when passed the `owner` share balance
     */
    function maxWithdraw(address owner) public view virtual override returns (uint256 maxAssets) {
        maxAssets = convertToAssets(balanceOf(owner));
    }

    /**
     * @inheritdoc IERC4626
     * @custom:devdetails Unless overridden, returns result of {convertToShares} when passed the amount `assets`
     * TODO: EIP-4626 specifies that previewWithdraw should round up
     */
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256 shares) {
        // TODO
        // previewWithdraw should round up but convertToShares rounds up!
        return convertToShares(assets);
    }

    /**
     * @inheritdoc IERC4626
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override nonReentrant returns (uint256 shares) {
        // Calculate amount of shares to burn from requested amount of assets
        shares = previewWithdraw(assets);
        _withdraw(assets, shares, receiver, owner);
    }

    /**
     * @inheritdoc IERC4626
     * @custom:devdetails Unless overridden, returns `owner` share balance
     */
    function maxRedeem(address owner) public view virtual override returns (uint256 maxShares) {
        maxShares = balanceOf(owner);
    }

    /**
     * @inheritdoc IERC4626
     * @custom:devdetails Unless overridden, returns result of {convertToAssets}
     */
    function previewRedeem(uint256 shares) public view virtual override returns (uint256 assets) {
        assets = convertToAssets(shares);
    }

    /**
     * @inheritdoc IERC4626
     * @custom:devdetails First withdraw from the 'float' i.e. the funds that have not yet been
     * deposited into the underlying PrizePool.
     */

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256 assets) {
        // Calculate amount of assets corresponding to the amount of shares requested to be redeemed
        assets = previewRedeem(shares);
        // Withdraw assets and burn shares
        _withdraw(assets, shares, receiver, owner);
    }

    /**
     *  IPod Methods:
     * ______________
     */

    /// @inheritdoc IPod
    function prizePool() external view override returns (address) {
        return address(_prizePool);
    }

    /// @inheritdoc IPod
    function getPricePerShare() external view override returns (uint256) {
        return convertToAssets(1);
    }

    /**
     * @inheritdoc IPod
     */
    // TODO Pods v3 doc: Claim current POOL rewards
    function batch() external override returns (uint256) {
        // Pod asset float balance
        uint256 floatBalance = _podAssetBalance();

        // Approve PrizePool
        _asset.safeApprove(address(_prizePool), floatBalance);

        // Deposit into PrizePool
        _prizePool.depositTo(address(this), floatBalance);

        // emit BatchFloat event
        emit BatchFloat(floatBalance);

        return floatBalance;
    }

    /**
     * @notice Claim prize payouts from PrizeDistributor
     * @dev Claim underlying assets prize payouts for the Pod from PrizeDistributor.
     * @return uint256 Claimed prize payouts amount
     */
    function drop() external returns (uint256) {
        // TODO stub, not implemented
        // Claim prizes from PrizeDistributor
        // _prizeDistributor.claim(address(this));
        // Run batch to eliminate sandwich attack
        // and to reduce Pod float
        // uint256 float = batch();
        // emit PodClaimed(amount);
    }

    /**
     * Other Views:
     * ____________
     */

    /**
     * @notice Calculate the Pod's total balance by adding the total balance of underlying
     *         assets and PrizePool tickets.
     * @dev The Pod's total true balance is the sum of assets and tickets balances -- which are equal
     *      in value.
     * @return uint256 The sum of the Pod vault's total asset and ticket balances
     */
    function balance() public view returns (uint256) {
        return _podAssetBalance() + _podTicketBalance();
    }

    /**
     * Internal Methods:
     * __________________
     */

    /**
     * @notice The Pod's current underlying asset balance.
     * @dev Get the Pod's current underlying asset token balance by calling the asset contract's
     *      `balanceOf` method.
     * @return uint256 The Pod's current underlying asset balance
     */
    function _podAssetBalance() internal view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    /**
     * @notice The Pod's current underlying PrizePool ticket balance.
     * @dev Get the Pod's current underlying PrizePool ticket balance by calling the ticket contract's
     *      `balanceOf` method.
     * @return uint256 The Pod's current underlying Ticket balance
     */
    function _podTicketBalance() internal view returns (uint256) {
        return ticket.balanceOf(address(this));
    }

    /**
     * @dev Internal function to deposit `assets` underlying assets tokens into Pod and issue `shares` pod shares to `receiver`.
     * @param assets Amount of underlying tokens to deposit
     * @param shares Amount of Pod shares to mint
     * @param receiver Address to issue minted Pod shares to
     */
    function _deposit(
        uint256 assets,
        uint256 shares,
        address receiver
    ) internal {
        // Check amounts
        require(assets > 0, "Pod:zero-assets");
        require(shares > 0, "Pod:zero-shares");

        // Transer assets from msg.sender
        _asset.safeTransferFrom(msg.sender, address(this), assets);
        // Mint shares to receiver
        _mint(receiver, shares);

        // Emit Deposit event
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @dev Internal function to burn `shares` pod shares issued to `owner` and
     *      withdraw `assets` underlying assets tokens by transferring to `receiver`.
     * @param assets Amount of underlying tokens to withdraw
     * @param shares Amount of Pod shares to burn
     * @param receiver Address to transfer underlying assets to
     * @param owner Address of owner of the Pod shares
     */
    function _withdraw(
        uint256 assets,
        uint256 shares,
        address receiver,
        address owner
    ) internal {
        // Check amounts
        require(assets > 0, "Pod:zero-assets");
        require(shares > 0, "Pod:zero-shares");

        // Check balances or allowances
        require(balanceOf(owner) >= shares, "Pod:insufficient-shares");
        if (msg.sender != owner) {
            // Check caller allowance
            require(allowance(owner, msg.sender) >= shares, "Pod:insufficient-shares-allowance");
        }

        // Burn Pod shares
        _burn(owner, shares);
        // Decrease caller's allowance after burn
        if (msg.sender != owner) {
            // Note: decreaseAllowance checks caller allowance as well
            decreaseAllowance(msg.sender, shares);
        }

        // Next, need to check if float balance i.e. underlying assets balance not yet deposited
        // covers the assets to be withdrawn. If not, need to withdraw the difference from the PrizePool

        // Get float balance
        uint256 floatBalance = _podAssetBalance();

        // check if float balance covers withdrawal assets amount
        if (assets > floatBalance) {
            // Withdrawal exceeds float balance
            // so withdraw difference from PrizePool

            // calculate assets amount to withdraw from PrizePool
            uint256 withdrawAssets = assets - floatBalance;

            // withdraw from PrizePool
            _prizePool.withdrawFrom(address(this), withdrawAssets);
        }

        // TODO
        // Any Pod withdrawal fees?
        // Need to consider awards distribution and Pod's TWAB

        // Transfer assets to designated receiver
        _asset.safeTransfer(receiver, assets);

        // Emit Withdraw event
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}
