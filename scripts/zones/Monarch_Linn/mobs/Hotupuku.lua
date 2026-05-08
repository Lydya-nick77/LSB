-----------------------------------
-- Area: Monarch Linn
-- Mob : Hotupuku
-- ENM : Bugard in the Clouds
-----------------------------------
local entity = {}

---@type TMobSkill[]
local bugardSkills =
{
    xi.mobSkill.TAIL_ROLL,
    xi.mobSkill.TUSK,
    xi.mobSkill.SCUTUM,
    xi.mobSkill.BONE_CRUNCH,
    xi.mobSkill.AWFUL_EYE,
    xi.mobSkill.HEAVY_BELLOW,
}

---@type TMobSkill[]
local twoHours =
{
    xi.mobSkill.HUNDRED_FISTS_1,
    xi.mobSkill.INVINCIBLE_1,
    xi.mobSkill.MIGHTY_STRIKES_1,
}

local immunityMods =
{
    xi.mod.UDMGPHYS,
    xi.mod.UDMGMAGIC,
    xi.mod.UDMGRANGE,
}

local targetMaxHP = 5000
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
    mob:setMobMod(xi.mobMod.BASE_DAMAGE_MULTIPLIER, 350)
    mob:setMobMod(xi.mobMod.ADD_EFFECT, 1)
end

entity.onMobSpawn = function(mob)
    mob:setLocalVar('immunityMod', immunityMods[math.random(1, #immunityMods)])
    mob:setLocalVar('twoHourUsed', 0)
    mob:setLocalVar('nextTwoHourTime', 0)
    mob:setLocalVar('twoHourBuffStage', 0)
    mob:setLocalVar('enstoneEnabled', 0)
    mob:setLocalVar('immunityApplied', 0)
    mob:setLocalVar('tpChainCount', 0)
    mob:setLocalVar('tpChainSkill', 0)
    mob:setLocalVar('tpChainPending', 0)
    mob:setMaxHP(targetMaxHP)
    mob:setHP(mob:getMaxHP())
    mob:setMod(xi.mod.UDMGPHYS, 0)
    mob:setMod(xi.mod.UDMGMAGIC, 0)
    mob:setMod(xi.mod.UDMGRANGE, 0)
    mob:setMod(xi.mod.ACC, 25)
    mob:setMod(xi.mod.DEFP, 0)
    mob:addMod(xi.mod.DEF, 150)
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
        mob:setMod(mob:getLocalVar('immunityMod'), -10000)
    end

    if  mob:getLocalVar('twoHourUsed') == 0 and
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