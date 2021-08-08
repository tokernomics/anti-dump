// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

import "../libraries/SafeMath.sol";
import "./ERC20.sol";
import "./Adminable.sol";
import "./AntiDump.sol";

/**
 * This is an alpha-v1 of an AntiDump tracking contract to be used with ERC20 and BEP20 tokens.
 *
 * Using 5 cooldown stages a contract can perform cooldown AntiDump tokenomics using:
 * (cooldwnTrigger)percent: The percent at which the cooldown stage is triggered
 * cooldownTime: The timestamp or relative time for the cooldown
 * cooldownStrike: The punishment during cooldown. This could be an absolute or relative percentage, or something else entirely.
 *
 *
 * In the next versions I will work on a more gas efficient way of performing this.  If you have any suggestions please
 * leave them at the repo at https://github.com/tokernomics
 *
 * First used in https://only1baby.com
 *
 * This plugin demostrates one way  to use the AntiDump features, but there is some flexibility in it's usage.
 * We will be trying out other patterns in future projects.
 *
 *
 * By: Tokernomics
 * Date: 2021-08-05
 * Please do not delete this header
 */
abstract contract AntiDumpPlugin is ERC20, Adminable, AntiDump {
    using SafeMath for uint256;

    // Tracking the last time someone bought
    mapping(address => uint256) public lastBought;
    // Tracking the last time someone sold
    mapping(address => uint256) public lastSold;

    constructor() public {
        // Setup the AntiDump stages (stage, percent, time, strike as absolute percent)
        _setCooldownStageInfo(0,  0, 6 hours,    0);   // base 12%  (6 hour wait to allow reset max holdings)
        _setCooldownStageInfo(4, 75, 6 hours,   800); // base 12% +  8% = 20%
        _setCooldownStageInfo(3, 50, 3 days,   1300); // base 12% + 13% = 25%
        _setCooldownStageInfo(2, 25, 1 weeks,   2800); // base 12% + 28% = 30%
        _setCooldownStageInfo(1, 15, 1 weeks,   8300); // base 12% + 83% = 95% (essentially can't sell below 15% without waiting)
    }

    // This is the main function that needs to be called to apply the cooldown logic
    // Mode 0: Do nothing
    // Mode 1: Add amount to balance for _updateHolding
    // Mode 2: Substract amount from balance for _updateHolding
    function _applyCooldownAndGetFee(
        uint8 mode,
        address user,
        uint256 amount
    ) internal returns (uint256 fee) {
        // Update user holding with balance before this transaction's results
        if (_canResetCooldown(user)) {
            // Reset if we're out of the cooldown period
            _setCooldown(user, 0, IERC20(this).balanceOf(user));
        }

        uint256 newBalance;
        if (mode == 2) {
            newBalance = IERC20(this).balanceOf(user).sub(amount);
        } else if (mode == 1) {
            newBalance = IERC20(this).balanceOf(user).add(amount);
        } else {
            newBalance = IERC20(this).balanceOf(user);
        }

        // Update the holding with the newBalance (which will trigger antiDump features)
        (, fee) = _updateHolding(user, newBalance);
    }

    function _canResetCooldown(address user) internal view returns (bool) {
        uint256 fromLastSold = lastSold[user];
        if (fromLastSold == 0) return false;
        (, , , uint256 cooldownTime, ) = _getUserCooldownInfo(user);
        return block.timestamp.sub(fromLastSold) > cooldownTime;
    }

    // isInCooldown is for users that have entered cooldown and are still in cooldown
    function _isInCooldown(address user) internal view returns (bool) {
        uint256 fromLastSold = lastSold[user];
        if (fromLastSold == 0) return false;
        (, , , uint256 cooldownTime, ) = _getUserCooldownInfo(user);
        return
            _hasEnteredCooldown(user) &&
            block.timestamp.sub(fromLastSold) <= cooldownTime;
    }

    // hasEnteredCooldown is for users that have entered cooldown (but may or may not still be there)
    function _hasEnteredCooldown(address user) internal view returns (bool) {
        (uint256 cooldownStage, , , , ) = _getUserCooldownInfo(user);
        return cooldownStage != 0;
    }

    function _getCooldownFee(address user)
        internal
        view
        returns (uint256 cooldownStrike)
    {
        (, , , , cooldownStrike) = _getUserCooldownInfo(user);
    }

    function setCooldownStageInfos(
        uint256[3][COOLDOWN_STAGE_COUNT] calldata infos
    ) external onlyAdmin(1) {
        _setCooldownStageInfos(infos);
    }

    function setCooldownStageInfo(
        uint256 cooldownStage,
        uint256 percent,
        uint256 cooldownTime,
        uint256 cooldownStrike
    ) external onlyAdmin(1) {
        _setCooldownStageInfo(
            cooldownStage,
            percent,
            cooldownTime,
            cooldownStrike
        );
    }

    function setCooldownAndMaxHolding(
        address user,
        uint256 newCooldownStage,
        uint256 newMaxHolding
    )
        external
        onlyAdmin(1)
        returns (uint256 cooldownTime, uint256 cooldownStrike)
    {
        _setCooldown(user, newCooldownStage, newMaxHolding);
        cooldownTime = cooldownMapping[newCooldownStage][1];
        cooldownStrike = cooldownMapping[newCooldownStage][2];
    }

    function getCooldownState(address user)
        external
        view
        returns (
            bool hasEnteredCooldown,
            bool isInCooldown,
            bool canResetCooldown,
            uint256 cooldownFee
        )
    {
        hasEnteredCooldown = _hasEnteredCooldown(user);
        isInCooldown = _isInCooldown(user);
        canResetCooldown = _canResetCooldown(user);
        cooldownFee = _getCooldownFee(user);
    }
}
