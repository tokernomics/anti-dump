pragma solidity ^0.6.2;

import "../libraries/SafeMath.sol";

// SPDX-License-Identifier: MIT License

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
 * By: Tokernomics
 * Date: 2021-08-05
 * Please do not delete this header
 */
contract AntiDump {
    using SafeMath for uint256;

    struct StageHolding {
        uint256 cooldownStage;
        uint256 maxHolding;
    }

    uint16 internal constant COOLDOWN_STAGE_COUNT = 5;

    // address user -> uint256 cooldownStage, uint256 maxHolding
    mapping(address => StageHolding) private antiDumpTracker;

    // cooldownStage to (percent, time, strike)
    uint256[3][COOLDOWN_STAGE_COUNT] internal cooldownMapping;

    event UpdateMaxHolding(address indexed user, uint256 maxHolding);
    event UpdateCooldownStage(address indexed user, uint256 cooldownStage);
    event UpdateCooldownInfo(
        uint256 cooldownStage,
        uint256 percent,
        uint256 cooldownTime,
        uint256 cooldownStrike
    );
    event SetCooldown(
        address indexed user,
        uint256 cooldownStage,
        uint256 maxHolding
    );

    constructor() public {}

    function _setCooldown(
        address user,
        uint256 newCooldownStage,
        uint256 newMaxHolding
    ) internal {
        emit SetCooldown(user, newCooldownStage, newMaxHolding);
        antiDumpTracker[user] = StageHolding(newCooldownStage, newMaxHolding);
    }

    function _setCooldownStageInfo(
        uint256 cooldownStage,
        uint256 percent,
        uint256 cooldownTime,
        uint256 cooldownStrike
    ) internal {
        emit UpdateCooldownInfo(
            cooldownStage,
            percent,
            cooldownTime,
            cooldownStrike
        );
        cooldownMapping[cooldownStage][0] = percent;
        cooldownMapping[cooldownStage][1] = cooldownTime;
        cooldownMapping[cooldownStage][2] = cooldownStrike;
    }

    function _setCooldownStageInfos(
        uint256[3][COOLDOWN_STAGE_COUNT] calldata infos
    ) internal {
        for (uint256 i = 0; i < COOLDOWN_STAGE_COUNT; i++) {
            _setCooldownStageInfo(i, infos[i][0], infos[i][1], infos[i][2]);
        }
    }

    function _updateHolding(address user, uint256 newHolding)
        internal
        returns (uint256 cooldownTime, uint256 cooldownStrike)
    {
        StageHolding memory stageHolding = antiDumpTracker[user];
        uint256 newCooldownStage; // default 0

        if (newHolding > stageHolding.maxHolding) {
            if (stageHolding.cooldownStage != newCooldownStage) {
                // cooldown will be reset to 0 so emit event
                emit UpdateCooldownStage(user, newCooldownStage);
            }
            emit UpdateMaxHolding(user, newHolding);
            antiDumpTracker[user] = StageHolding(newCooldownStage, newHolding);
        } else {
            uint256 newPercent;
            if (stageHolding.maxHolding > 0)
                newPercent = newHolding.mul(100).div(stageHolding.maxHolding);
            uint256 tempPercent;
            for (uint16 i = 0; i < COOLDOWN_STAGE_COUNT; i++) {
                tempPercent = cooldownMapping[i][0];
                if (newPercent < tempPercent) {
                    emit UpdateCooldownStage(user, i);

                    // only check `<` so that `maxHolding == 0` doesn't get through
                    antiDumpTracker[user] = StageHolding(
                        i,
                        stageHolding.maxHolding
                    );
                    newCooldownStage = i;

                    // break out of loop
                    break;
                }
            }
        }
        cooldownTime = cooldownMapping[newCooldownStage][1];
        cooldownStrike = cooldownMapping[newCooldownStage][2];
    }

    function _getUserCooldownInfo(address user)
        internal
        view
        returns (
            uint256 cooldownStage,
            uint256 maxHolding,
            uint256 percent,
            uint256 cooldownTime,
            uint256 cooldownStrike
        )
    {
        StageHolding memory stageHolding = antiDumpTracker[user];

        cooldownStage = stageHolding.cooldownStage;
        maxHolding = stageHolding.maxHolding;
        percent = cooldownMapping[cooldownStage][0];
        cooldownTime = cooldownMapping[cooldownStage][1];
        cooldownStrike = cooldownMapping[cooldownStage][2];
    }

    function getUserCooldownInfo(address user)
        public
        view
        returns (
            uint256 cooldownStage,
            uint256 maxHolding,
            uint256 percent,
            uint256 cooldownTime,
            uint256 cooldownStrike
        )
    {
        return _getUserCooldownInfo(user);
    }

    function getCooldownStageInfos()
        public
        view
        returns (uint256[3][COOLDOWN_STAGE_COUNT] memory)
    {
        return cooldownMapping;
    }
}
