local activeMissions = {}
local lastGlobalGoFast = 0
local playerCooldowns = {}

local gofastCountSinceCooldown = 0
local gofastCooldownEndTime = 0

local language = Config.Language
local T = require("locales." .. language)

local hookId = exports.ox_inventory:registerHook('createItem', function(payload)
    if payload.item.name == 'gofast_bag' then
        local metadata = payload.metadata or {}
        metadata.label = 'Sac Go-Fast'
        metadata.description = string.format(
            "Drogue: %s | Quantité: %d | S/N: %d | ",
            metadata.drugLabel or T.unknown_drug,
            metadata.amount or 0,
            metadata.sn or 0
        )
        return metadata
    end
end, {
    print = false,
    itemFilter = {
        gofast_bag = true
    }
})

lib.callback.register('gofast:getDrugList', function(source)
    local availableDrugs = {}

    for _, drug in ipairs(Config.DrugTypes) do
        local count = exports.ox_inventory:Search(source, 'count', drug.name)
        if count and count >= drug.minAmount then
            local drugInfo = table.clone(drug)
            drugInfo.playerAmount = count
            table.insert(availableDrugs, drugInfo)
        end
    end

    return availableDrugs
end)

lib.callback.register('gofast:getMinPolice', function(source)
    local minPolice = 0
    local players = exports.qbx_core:GetQBPlayers()

    for _, player in pairs(players) do
        if player.PlayerData.job.name == Config.PoliceJobName then
            minPolice = minPolice + 1
        end
    end

    return minPolice
end)

RegisterNetEvent('gofast:startMission')
AddEventHandler('gofast:startMission', function(drugName, amount)
    local source = source
    local currentTime = os.time()

    -- Global 15-minute cooldown after 2 missions
    if currentTime < gofastCooldownEndTime then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = T.global_gofast_limit_reached or 'All GoFast missions are currently on cooldown. Try again later.',
            duration = 5000,
            position = Config.OxNotifyPosition
        })
        return
    end

    -- Max 2 active missions
    local activeCount = 0
    for _ in pairs(activeMissions) do
        activeCount += 1
    end

    if activeCount >= 2 then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = T.max_gofast_active or 'Maximum number of GoFast missions in progress. Wait for one to finish.',
            duration = 5000,
            position = Config.OxNotifyPosition
        })
        return
    end

    if playerCooldowns[source] and currentTime - playerCooldowns[source] < Config.PlayerCooldown then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = T.come_back_later_player,
            duration = 5000,
            position = Config.OxNotifyPosition
        })
        return
    end

    local drugType = nil
    for _, drug in ipairs(Config.DrugTypes) do
        if drug.name == drugName then
            drugType = drug
            break
        end
    end

    if drugType then
        local count = exports.ox_inventory:GetItem(source, drugType.name, nil, true)
        if count >= amount and amount <= drugType.maxAmount then
            local removed = exports.ox_inventory:RemoveItem(source, drugType.name, amount)
            if not removed then
                TriggerClientEvent('ox_lib:notify', source, {
                    type = 'error',
                    description = T.drug_removal_error,
                    duration = 5000,
                    position = Config.OxNotifyPosition
                })
                return
            end

            local totalReward = amount * drugType.rewardPerUnit
            local plate = 'FR' .. math.random(1000, 9999)
            local sn = math.random(100000, 999999)

            local metadata = {
                drugType = drugType.name,
                drugLabel = drugType.label,
                amount = amount,
                sn = sn
            }
            local success = exports.ox_inventory:AddItem(source, 'gofast_bag', 1, metadata)

            if success then
                activeMissions[source] = {
                    drugType = drugType,
                    amount = amount,
                    reward = totalReward,
                    startTime = os.time(),
                    plate = plate,
                    sn = sn
                }

                TriggerClientEvent('gofast:startMission', source, drugType, amount, plate)
                TriggerClientEvent('ox_lib:notify', source, {
                    type = 'success',
                    description = T.mission_started,
                    duration = 5000,
                    position = Config.OxNotifyPosition
                })

                playerCooldowns[source] = currentTime
            else
                exports.ox_inventory:AddItem(source, drugType.name, amount)
                TriggerClientEvent('ox_lib:notify', source, {
                    type = 'error',
                    description = T.gofast_bag_creation_error,
                    duration = 5000,
                    position = Config.OxNotifyPosition
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', source, {
                type = 'error',
                description = string.format(T.invalid_drug_quantity, drugType.label)
            })
        end
    end
end)

RegisterNetEvent('gofast:completeMission')
AddEventHandler('gofast:completeMission', function(drugName, amount)
    local source = source
    local mission = activeMissions[source]

    if mission and mission.drugType.name == drugName and mission.amount == amount then
        local inventory = exports.ox_inventory:GetInventory(source)
        local gofast_bag = nil

        for _, item in pairs(inventory.items) do
            if item.name == 'gofast_bag' then
                gofast_bag = item
                break
            end
        end

        if gofast_bag and gofast_bag.metadata.drugType == drugName and gofast_bag.metadata.amount == amount then
            local removed = exports.ox_inventory:RemoveItem(source, 'gofast_bag', 1)
            if removed then
                exports.ox_inventory:AddItem(source, Config.TypeMoney, mission.reward)

                TriggerClientEvent('ox_lib:notify', source, {
                    title = T.gofast_title,
                    description = string.format(T.mission_success, mission.reward),
                    type = 'success',
                    duration = 5000,
                    position = Config.OxNotifyPosition
                })

                activeMissions[source] = nil
                playerCooldowns[source] = os.time()

                -- TRACK COMPLETION COUNT
                gofastCountSinceCooldown += 1
                if gofastCountSinceCooldown >= 2 then
                    gofastCooldownEndTime = os.time() + 900 -- 15 minutes
                    gofastCountSinceCooldown = 0
                end
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = T.gofast_title,
                    description = T.gofast_bag_removal_error,
                    type = 'error',
                    duration = 5000,
                    position = Config.OxNotifyPosition
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = T.gofast_title,
                description = T.gofast_bag_not_found,
                type = 'error',
                duration = 5000,
                position = Config.OxNotifyPosition
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = T.gofast_title,
            description = T.mission_completion_error,
            type = 'error',
            duration = 5000,
            position = Config.OxNotifyPosition
        })
    end
end)

-- RegisterNetEvent('gofast:alertPolice', function()
--     local players = exports.qbx_core:GetQBPlayers()

--     for _, player in pairs(players) do
--         if player.PlayerData.job.name == Config.PoliceJobName then
--             TriggerClientEvent('ox_lib:notify', player.PlayerData.source, {
--                 title = T.police_alert_title,
--                 description = T.police_alert_description,
--                 type = 'inform',
--                 duration = 5000,
--                 position = Config.OxNotifyPosition
--             })
--         end
--     end
-- end)

RegisterNetEvent('gofast:signalLost', function()
    local players = exports.qbx_core:GetQBPlayers()

    for _, player in pairs(players) do
        if player.PlayerData.job.name == Config.PoliceJobName then
            TriggerClientEvent('ox_lib:notify', player.PlayerData.source, {
                title = T.police_alert_title,
                description = T.police_signal_lost,
                type = 'inform',
                duration = 5000,
                position = Config.OxNotifyPosition
            })
        end
    end
end)

RegisterNetEvent('gofast:updatePoliceBlip', function(coords)
    local players = exports.qbx_core:GetQBPlayers()

    for _, player in pairs(players) do
        if player.PlayerData.job.name == Config.PoliceJobName then
            TriggerClientEvent('gofast:showPoliceBlip', player.PlayerData.source, coords)
        end
    end
end)

AddEventHandler('playerDropped', function()
    playerCooldowns[source] = nil
    activeMissions[source] = nil
end)

local function cleanupMissions()
    local currentTime = os.time()
    for playerId, mission in pairs(activeMissions) do
        if currentTime - mission.startTime > 3600 then
            activeMissions[playerId] = nil
        end
    end
end

CreateThread(function()
    while true do
        Wait(900000) -- 15 minutes
        cleanupMissions()
    end
end)
