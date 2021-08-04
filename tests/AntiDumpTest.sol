pragma solidity ^0.6.2;

import "../contracts/AntiDump.sol";

// SPDX-License-Identifier: MIT License

/**
 * Just a simple test contract to make sure AntiDump works the way it should
 */
contract AntiDumpTest is AntiDump {
    constructor() public {}

    function setCooldownStageInfo() public {
        uint256 value;
        for (uint256 i = 1; i <= 4; i++) {
            value = (i) * 20;
            _setCooldownStageInfo(i, value, 2 minutes, value);
        }
        _setCooldownStageInfo(0, 0, 2 minutes, 0);
    }

    /* Test for real contract */

    // Tracking the last time someone bought
    mapping(address => uint256) public lastBought;
    // Tracking the last time someone sold
    mapping(address => uint256) public lastSold;
    // User holding
    mapping(address => uint256) public userHolding;

    function _canResetCooldown(address user) internal view returns (bool) {
        uint256 fromLastSold = lastSold[user];
        if (fromLastSold == 0) return false;
        (, uint256 cooldownTime, ) = _getUserCooldownInfo(user);
        return block.timestamp.sub(fromLastSold) > cooldownTime;
    }

    function canResetCooldown(address user) public view returns (bool) {
        return _canResetCooldown(user);
    }

    function _isInCooldown(address user) internal view returns (bool) {
        uint256 fromLastSold = lastSold[user];
        if (fromLastSold == 0) return false;
        (, uint256 cooldownTime, ) = _getUserCooldownInfo(user);
        return
            _needsCooldown(user) &&
            block.timestamp.sub(fromLastSold) <= cooldownTime;
    }

    function isInCooldown(address user) public view returns (bool) {
        return _isInCooldown(user);
    }

    function _needsCooldown(address user) internal view returns (bool) {
        (uint256 cooldownStage, ) = _getUserStage(user);
        return cooldownStage != 0;
    }

    function needsCooldown(address user) public view returns (bool) {
        return _needsCooldown(user);
    }

    function _getCooldownFee(address user)
        internal
        view
        returns (uint256 cooldownStrike)
    {
        (, , cooldownStrike) = _getUserCooldownInfo(user);
    }

    function getCooldownFee(address user) public view returns (uint256) {
        return _getCooldownFee(user);
    }

    function setCooldownStageInfos(
        uint256[3][COOLDOWN_STAGE_COUNT] calldata infos
    ) public {
        _setCooldownStageInfos(infos);
    }

    function setCooldownStageInfo(
        uint256 cooldownStage,
        uint256 percent,
        uint256 cooldownTime,
        uint256 cooldownStrike
    ) public {
        _setCooldownStageInfo(
            cooldownStage,
            percent,
            cooldownTime,
            cooldownStrike
        );
    }

    function updateHolding(address user, uint256 newHolding)
        public
        returns (uint256 cooldownTime, uint256 cooldownStrike)
    {
        return _updateHolding(user, newHolding);
    }

    function resetCooldown(address user, uint256 newMaxHolding) public {
        _resetCooldown(user, newMaxHolding);
    }

    function performBuy(address user, uint256 amount) public returns (uint256) {
        // Update user holding with balance before this transaction's results
        if (_canResetCooldown(user)) {
            // Reset if we're out of cooldown
            _resetCooldown(user, userHolding[user].add(amount));
        }

        _updateHolding(user, userHolding[user].add(amount));

        uint256 fee = _getCooldownFee(user);

        lastBought[user] = block.timestamp;

        userHolding[user] = userHolding[user].add(amount);

        return fee;
    }

    function performSell(address user, uint256 amount)
        public
        returns (uint256)
    {
        // Update user holding with balance before this transaction's results
        if (_canResetCooldown(user)) {
            // Reset if we're out of cooldown
            _resetCooldown(user, userHolding[user]);
        }

        _updateHolding(user, userHolding[user].sub(amount));

        uint256 fee = _getCooldownFee(user);

        lastSold[user] = block.timestamp;

        userHolding[user] = userHolding[user].sub(amount);

        return fee;
    }
}
