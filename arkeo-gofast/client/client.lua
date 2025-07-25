-- Fully optimized and refactored client.lua for GoFast
local isOnMission = false
local missionVehicle, deliveryBlip, gofastPed = nil, nil, nil
local T = require("locales." .. Config.Language)

local function notify(title, desc, type)
    lib.notify({ title = title, description = desc, type = type, duration = 5000, position = Config.OxNotifyPosition })
end

local function waitForModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
end

local function showInputDialog(drug, maxAmount, minAmount)
    return lib.inputDialog(string.format('%s %s', T.quantity_label, drug.label), {
        {
            type = 'number',
            label = T.quantity_label,
            description = minAmount and string.format(T.min_max_quantity_description, minAmount, maxAmount)
                            or string.format(T.max_quantity_description, maxAmount),
            required = true,
            min = minAmount or 1,
            max = maxAmount
        }
    })
end

function manageGoFastPed()
    local pedCreated = false
    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())
        local dist = #(playerCoords - vector3(Config.PedLocation.x, Config.PedLocation.y, Config.PedLocation.z))

        if dist < 10.0 and not pedCreated then
            waitForModel(Config.PedModel)
            gofastPed = CreatePed(4, Config.PedModel, Config.PedLocation.x, Config.PedLocation.y, Config.PedLocation.z - 1, Config.PedLocation.w, false, true)
            FreezeEntityPosition(gofastPed, true)
            SetEntityInvincible(gofastPed, true)
            SetBlockingOfNonTemporaryEvents(gofastPed, true)
            pedCreated = true

            exports.ox_target:addLocalEntity(gofastPed, {
                {
                    name = 'start_gofast', icon = 'fas fa-car', label = T.start_gofast, distance = 1.5,
                    onSelect = function()
                        local minPolice = lib.callback.await('gofast:getMinPolice', false)
                        if type(minPolice) ~= 'number' then
                            return notify(T.gofast_title, T.error_police_check or 'Error checking police count.', 'error')
                        end
                        if minPolice >= Config.MinPolice then
                            checkDrugsAndShowMenu()
                        else
                            notify(T.unknown_title, T.come_back_later, 'error')
                        end
                    end
                }
            })

        elseif dist >= 10.0 and pedCreated then
            DeleteEntity(gofastPed)
            gofastPed = nil
            pedCreated = false
        end

        Wait(sleep)
    end
end

function StartGoFastMission(drugType, amount, plate)
    local model = GetHashKey(Config.VehicleModels[math.random(#Config.VehicleModels)])
    waitForModel(model)
    local coords = Config.VehicleSpawnPoint
    missionVehicle = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, true, false)
    SetEntityAsMissionEntity(missionVehicle, true, true)
    SetVehicleNumberPlateText(missionVehicle, plate)
    SetNewWaypoint(coords.x, coords.y)
    notify(T.gofast_title, T.vehicle_ready, 'info')

    CreateThread(function()
        while not IsPedInVehicle(PlayerPedId(), missionVehicle, false) do Wait(1000) end
        StartGoFastTimer(drugType, amount)
    end)
end

function StartGoFastTimer(drugType, amount)
    notify(T.gofast_title, T.move_quickly, 'info')
    Wait(math.random(Config.TimerBeforeAlert.min, Config.TimerBeforeAlert.max) * 1000)

    local alertDuration = math.random(Config.PoliceAlertDuration.min, Config.PoliceAlertDuration.max)
    local point = Config.DeliveryPoints[math.random(#Config.DeliveryPoints)]

    CreateThread(function()
        local endTime = GetGameTimer() + (alertDuration * 1000)
        while GetGameTimer() < endTime do
            TriggerServerEvent('gofast:updatePoliceBlip', GetEntityCoords(PlayerPedId()))
            Wait(Config.PoliceUpdateInterval * 1000)
        end
        TriggerServerEvent('gofast:signalLost')
        notify(T.gofast_title, T.signal_jammed, 'success')

        deliveryBlip = AddBlipForCoord(point.x, point.y, point.z)
        SetBlipRoute(deliveryBlip, true)

        CreateThread(function()
            while true do
                if #(GetEntityCoords(PlayerPedId()) - point) < 5.0 then
                    RemoveBlip(deliveryBlip)
                    TriggerServerEvent('gofast:completeMission', drugType.name, amount)
                    DeleteEntity(missionVehicle)
                    deliveryBlip, missionVehicle, isOnMission = nil, nil, false
                    break
                end
                Wait(1000)
            end
        end)
    end)
end

function showDrugMenu(drugs)
    if #drugs == 0 then return notify(T.gofast_title, T.no_drugs_available, 'error') end
    local opts = {}
    for _, d in ipairs(drugs) do
        table.insert(opts, {
            title = d.label or T.unknown_drug,
            description = string.format('%s, %s, %s', T.reward_format:format(d.rewardPerUnit), T.max_amount_format:format(d.maxAmount), T.available_amount_format:format(d.playerAmount)),
            icon = 'cannabis',
            onSelect = function()
                local amt = math.min(d.maxAmount, d.playerAmount)
                local input = showInputDialog(d, amt)
                if input and input[1] then
                    local val = math.floor(input[1])
                    if val > 0 and val <= amt then
                        TriggerServerEvent('gofast:startMission', d.name, val)
                    else
                        notify(T.gofast_title, T.invalid_quantity, 'error')
                    end
                end
            end
        })
    end
    lib.registerContext({id = 'gofast_drug_selection', title = T.drug_selection_title, options = opts})
    lib.showContext('gofast_drug_selection')
end

function checkDrugsAndShowMenu()
    if isOnMission then return notify(T.gofast_title, T.mission_in_progress, 'error') end
    local drugs = lib.callback.await('gofast:getDrugList', false)
    if not drugs or #drugs == 0 then return notify(T.gofast_title, T.no_drugs_available, 'error') end
    showDrugMenu(drugs)
end

RegisterNetEvent('gofast:startMission', function(drugType, amount, plate)
    if not isOnMission then
        isOnMission = true
        StartGoFastMission(drugType, amount, plate)
    end
end)

RegisterNetEvent('gofast:signalLost', function()
    notify(T.gofast_title, T.police_lost_trace, 'success')
end)

RegisterNetEvent('gofast:showPoliceBlip', function(coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(T.gofast_suspect)
    EndTextCommandSetBlipName(blip)
    PlaySound(-1, "Lose_1st", "GTAO_FM_Events_Soundset", 0, 0, 1)
    Wait(Config.PoliceBlipDuration * 1000)
    RemoveBlip(blip)
end)

CreateThread(manageGoFastPed)