-----------------------------------
-- Area: Monarch Linn
-- Mob : Hotupuku
-- ENM : Bugard in the Clouds
-----------------------------------
local entity = {}

local bugardSkills =
{
    xi.mobSkill.TAIL_ROLL,
    xi.mobSkill.TUSK,
    xi.mobSkill.SCUTUM,
    xi.mobSkill.BONE_CRUNCH,
    xi.mobSkill.AWFUL_EYE,
    xi.mobSkill.HEAVY_BELLOW,
}

local twoHours =
{
    xi.mobSkill.HUNDRED_FISTS_1,
    xi.mobSkill.INVINCIBLE_1,
    xi.mobSkill.MIGHTY_STRIKES_1,
}

local immunityMods =
{
    [1] = xi.mod.UDMGPHYS,
    [2] = xi.mod.UDMGMAGIC,
    [4] = xi.mod.UDMGRANGE,
}

local immunityTriggerDamage = 2000
local firstTwoHourTriggerDamage = 4000
local minTwoHourDelay = 90
local maxTwoHourDelay = 210

local function applyPostTwoHourBuffs(mob)
    mob:setMod(xi.mod.DELAYP, -40)
    mob:setMod(xi.mod.ACC, 150)
    mob:setMod(xi.mod.DOUBLE_ATTACK, 75)
end

local function resetTpChain(mob)
    mob:setLocalVar('tpChainCount', 0)
    mob:setLocalVar('tpChainSkill', 0)
    mob:setLocalVar('tpChainPending', 0)
end

local function canUseTwoHour(mob)
    return
        mob:canUseAbilities() and
        not mob:hasStatusEffect(xi.effect.HUNDRED_FISTS) and
        not mob:hasStatusEffect(xi.effect.INVINCIBLE) and
        not mob:hasStatusEffect(xi.effect.MIGHTY_STRIKES)
end

local function scheduleNextTwoHour(mob, battleTime)
    mob:setLocalVar('nextTwoHourTime', battleTime + math.random(minTwoHourDelay, maxTwoHourDelay))
end

local function hasSkill(skillList, skillId)
    for _, listedSkillId in ipairs(skillList) do
        if listedSkillId == skillId then
            return true
        end
    end

    return false
end

entity.onMobInitialize = function(mob)
    mob:addImmunity(xi.immunity.PARALYZE)
    mob:setMobMod(xi.mobMod.BASE_DAMAGE_MULTIPLIER, 250)
    mob:setMobMod(xi.mobMod.ADD_EFFECT, 1)
end

entity.onMobSpawn = function(mob)
    mob:setLocalVar('immunityMod', 0) -- Will be set to the appropriate UDMG* when immunity is applied
    mob:setLocalVar('damageTypesUsed', 0) -- Bitfield for phys/magic/ranged
    mob:setLocalVar('twoHourUsed', 0) -- Set to 1 once Hotupuku has used a 2 hour ability, preventing further procs until the next one is scheduled
    mob:setLocalVar('nextTwoHourTime', 0) -- Battle time at which Hotupuku can use a 2 hour ability again, set when a 2 hour is used
    mob:setLocalVar('twoHourBuffStage', 0) -- Tracks which buffs have been applied after using a 2 hour ability. 0 = none, 1 = first stage buffs applied
    mob:setLocalVar('enstoneEnabled', 0) -- Set to 1 when Hotupuku uses a 2 hour ability, allowing additional earth damage on attacks
    mob:setLocalVar('immunityApplied', 0) -- Set to 1 once Hotupuku has taken enough damage to trigger an immunity, preventing multiple immunities from being applied
    mob:setLocalVar('tpChainCount', 0) -- Tracks how many skills have been used in the current TP chain, resets after 2. Should be 0 when no chain is active.
    mob:setLocalVar('tpChainSkill', 0) -- Set to the skill ID of the first skill used in a TP chain, which is the one that will be used for the entire chain
    mob:setLocalVar('tpChainPending', 0) -- Set to 1 when a skill that can be chained is used, and the chain isn't already pending. When 1, the mob will use the appropriate chain skill on the next MobFight update, and then reset this to 0.
    mob:setMod(xi.mod.UDMGPHYS, 0) 
    mob:setMod(xi.mod.UDMGMAGIC, 0)
    mob:setMod(xi.mod.UDMGRANGE, 0)
    mob:setMod(xi.mod.DEFP, 0) 
    mob:addMod(xi.mod.DEF, 150) 
    
    mob:addListener('DAMAGE_TAKEN', 'Hotupuku_DamageTracker', function(mobArg, damage, attacker, attackType, damageType)
        if mobArg:getLocalVar('immunityApplied') == 0 then
            local damageMask = 0

            if attackType == xi.attackType.MAGICAL then
                damageMask = 2
            elseif attackType == xi.attackType.RANGED then
                damageMask = 4
            elseif attackType == xi.attackType.PHYSICAL then
                -- Some ranged auto-attacks can arrive as PHYSICAL.
                -- Action category is a more reliable checks.
                if attacker ~= nil then
                    local attackerAction = attacker:getCurrentAction()

                    if
                        attackerAction == xi.action.category.RANGED_START or
                        attackerAction == xi.action.category.RANGED_FINISH
                    then
                        damageMask = 4
                    else
                        damageMask = 1
                    end
                else
                    damageMask = 1
                end
            end

            if damageMask ~= 0 then
                mobArg:setLocalVar('damageTypesUsed', bit.bor(mobArg:getLocalVar('damageTypesUsed'), damageMask))
            end
        end
    end)
end

entity.onAdditionalEffect = function(mob, target, damage)
    if mob:getLocalVar('enstoneEnabled') == 0 then
        return 0, 0, 0
    end

    local addEffectDamage = math.random(70, 90)
    local actionDamageType = xi.damageType.ELEMENTAL + xi.element.EARTH

    target:takeDamage(addEffectDamage, mob, xi.attackType.MAGICAL, actionDamageType)
    return xi.subEffect.EARTH_DAMAGE, xi.msg.basic.ADD_EFFECT_DMG_2, addEffectDamage
end

entity.onMobFight = function(mob, target)
    local damageTaken = mob:getMaxHP() - mob:getHP()
    local battleTime = mob:getBattleTime()

    if mob:getLocalVar('immunityApplied') == 0 and damageTaken >= immunityTriggerDamage then
        mob:setLocalVar('immunityApplied', 1)
        mob:removeListener('Hotupuku_DamageTracker')

        local usedTypes = mob:getLocalVar('damageTypesUsed')
        if usedTypes == 0 then
            usedTypes = 7
        end

        local chosenMask = bit.lshift(1, math.random(0, 2))
        while bit.band(usedTypes, chosenMask) == 0 do
            chosenMask = bit.lshift(1, math.random(0, 2))
        end

        local chosenImmunity = immunityMods[chosenMask]
        mob:setLocalVar('immunityMod', chosenImmunity)
        mob:setMod(chosenImmunity, -10000)
    end

    if
        mob:getLocalVar('twoHourUsed') == 0 and
        damageTaken >= firstTwoHourTriggerDamage and
        canUseTwoHour(mob)
    then
        mob:setLocalVar('twoHourUsed', 1)
        scheduleNextTwoHour(mob, battleTime)
        mob:useMobAbility(twoHours[math.random(1, #twoHours)])
    elseif
        mob:getLocalVar('twoHourUsed') == 1 and
        battleTime >= mob:getLocalVar('nextTwoHourTime') and
        canUseTwoHour(mob)
    then
        scheduleNextTwoHour(mob, battleTime)
        mob:useMobAbility(twoHours[math.random(1, #twoHours)])
    end

    if xi.combat.behavior.isEntityBusy(mob) then
        return
    end

    if mob:getLocalVar('tpChainPending') == 1 and mob:canUseAbilities() then
        mob:setLocalVar('tpChainPending', 0)
        mob:useMobAbility(mob:getLocalVar('tpChainSkill'))
        return
    end

    if mob:getLocalVar('tpChainCount') > 0 then
        return
    end
end

entity.onMobWeaponSkill = function(mob, target, skill, action)
    local skillId = skill:getID()
    if hasSkill(twoHours, skillId) then
        mob:setLocalVar('enstoneEnabled', 1)

        if mob:getLocalVar('twoHourBuffStage') == 0 then
            mob:setLocalVar('twoHourBuffStage', 1)
            applyPostTwoHourBuffs(mob)
        end

        resetTpChain(mob)
        return
    end

    if not hasSkill(bugardSkills, skillId) then
        resetTpChain(mob)
        return
    end

    -- TP chain x3 logic.
    local tpChainCount = mob:getLocalVar('tpChainCount')

    if tpChainCount == 0 then
        mob:setLocalVar('tpChainSkill', skillId)
    end

    if tpChainCount >= 2 then
        resetTpChain(mob)
    else
        mob:setLocalVar('tpChainPending', 1)
        mob:setLocalVar('tpChainCount', tpChainCount + 1)

        if mob:canUseAbilities() then
            mob:setLocalVar('tpChainPending', 0)
            mob:useMobAbility(mob:getLocalVar('tpChainSkill'))
        end
    end
end

return entity
