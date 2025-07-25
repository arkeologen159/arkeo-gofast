-- Refactored and optimized server.lua for GoFast
local activeMissions, playerCooldowns, gofastCountSinceCooldown = {}, {}, 0
local gofastCooldownEndTime = 0
local T = require("locales." .. Config.Language)

local function notify(src, type, msg)
    TriggerClientEvent('ox_lib:notify', src, {
        type = type,
        description = msg,
        duration = 5000,
        position = Config.OxNotifyPosition
    })
end

exports.ox_inventory:registerHook('createItem', function(payload)
    if payload.item.name == 'gofast_bag' then
        local md = payload.metadata or {}
        md.label = 'Sac Go-Fast'
        md.description = string.format("Drogue: %s | Quantité: %d | S/N: %d | ", md.drugLabel or T.unknown_drug, md.amount or 0, md.sn or 0)
        return md
    end
end, {print = false, itemFilter = { gofast_bag = true }})

lib.callback.register('gofast:getDrugList', function(source)
    local result = {}
    for _, drug in ipairs(Config.DrugTypes) do
        local count = exports.ox_inventory:Search(source, 'count', drug.name)
        if count and count >= drug.minAmount then
            local clone = table.clone(drug)
            clone.playerAmount = count
            table.insert(result, clone)
        end
    end
    return result
end)

lib.callback.register('gofast:getMinPolice', function(source)
    local policeCount = 0
    for _, p in pairs(exports.qbx_core:GetQBPlayers()) do
        if p.PlayerData.job.name == Config.PoliceJobName then
            policeCount = policeCount + 1
        end
    end
    return policeCount
end)

RegisterNetEvent('gofast:startMission', function(drugName, amount)
    local src = source
    local now = os.time()

    if now < gofastCooldownEndTime then
        return notify(src, 'error', T.global_gofast_limit_reached)
    end

    if #activeMissions >= 2 then
        return notify(src, 'error', T.max_gofast_active)
    end

    if playerCooldowns[src] and now - playerCooldowns[src] < Config.PlayerCooldown then
        return notify(src, 'error', T.come_back_later_player)
    end

    local drugType
    for _, d in ipairs(Config.DrugTypes) do
        if d.name == drugName then drugType = d break end
    end

    if not drugType then return end

    local owned = exports.ox_inventory:GetItem(src, drugType.name, nil, true)
    if not owned or owned < amount or amount > drugType.maxAmount then
        return notify(src, 'error', string.format(T.invalid_drug_quantity, drugType.label))
    end

    if not exports.ox_inventory:RemoveItem(src, drugType.name, amount) then
        return notify(src, 'error', T.drug_removal_error)
    end

    local reward = amount * drugType.rewardPerUnit
    local metadata = {
        drugType = drugType.name,
        drugLabel = drugType.label,
        amount = amount,
        sn = math.random(100000, 999999)
    }
    local plate = 'FR' .. math.random(1000, 9999)

    if not exports.ox_inventory:AddItem(src, 'gofast_bag', 1, metadata) then
        exports.ox_inventory:AddItem(src, drugType.name, amount)
        return notify(src, 'error', T.gofast_bag_creation_error)
    end

    activeMissions[src] = { drugType = drugType, amount = amount, reward = reward, plate = plate, startTime = now }
    playerCooldowns[src] = now

    TriggerClientEvent('gofast:startMission', src, drugType, amount, plate)
    notify(src, 'success', T.mission_started)

    gofastCountSinceCooldown = gofastCountSinceCooldown + 1
    if gofastCountSinceCooldown >= 2 then
        gofastCooldownEndTime = now + 900
        gofastCountSinceCooldown = 0
    end
end)

RegisterNetEvent('gofast:completeMission', function(drugName, amount)
    local src, mission = source, activeMissions[source]
    if not mission or mission.drugType.name ~= drugName or mission.amount ~= amount then
        return notify(src, 'error', T.mission_completion_error)
    end

    for _, item in pairs(exports.ox_inventory:GetInventory(src).items) do
        if item.name == 'gofast_bag' and item.metadata.drugType == drugName and item.metadata.amount == amount then
            if exports.ox_inventory:RemoveItem(src, 'gofast_bag', 1) then
                exports.ox_inventory:AddItem(src, Config.TypeMoney, mission.reward)
                notify(src, 'success', string.format(T.mission_success, mission.reward))
                activeMissions[src] = nil
                playerCooldowns[src] = os.time()
            else
                notify(src, 'error', T.gofast_bag_removal_error)
            end
            return
        end
    end

    notify(src, 'error', T.gofast_bag_not_found)
end)

RegisterNetEvent('gofast:signalLost', function()
    for _, p in pairs(exports.qbx_core:GetQBPlayers()) do
        if p.PlayerData.job.name == Config.PoliceJobName then
            TriggerClientEvent('ox_lib:notify', p.PlayerData.source, {
                title = T.police_alert_title,
                description = T.police_signal_lost,
                type = 'inform', duration = 5000, position = Config.OxNotifyPosition
            })
        end
    end
end)

RegisterNetEvent('gofast:updatePoliceBlip', function(coords)
    for _, p in pairs(exports.qbx_core:GetQBPlayers()) do
        if p.PlayerData.job.name == Config.PoliceJobName then
            TriggerClientEvent('gofast:showPoliceBlip', p.PlayerData.source, coords)
        end
    end
end)

AddEventHandler('playerDropped', function()
    playerCooldowns[source] = nil
    activeMissions[source] = nil
end)

CreateThread(function()
    while true do
        Wait(900000)
        local now = os.time()
        for k, v in pairs(activeMissions) do
            if now - v.startTime > 3600 then activeMissions[k] = nil end
        end
    end
end)
