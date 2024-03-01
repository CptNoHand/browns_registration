local FW = config.Core.framework 

local Notify = config.Core.notify

local Targ = config.Core.target

local inZone = false

local IsCurrentlyViewing = false

local dict = 'missfam4'
local clip = 'base'
local clipboard = 'p_amb_clipboard_01'
local bone = 36029
local offset = vector3(0.16, 0.08, 0.1)
local rot = vector3(-170.0, 50.0, 20.0)

local function GenerateVin()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'
    local vin = {}
    for i = 1, 10 do
        vin[i] = chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    return table.concat(vin)
end

local function DetachAnim(entity)
    Citizen.CreateThread(function()
        Citizen.Wait(250)
        DetachEntity(entity, true, false)
        DeleteEntity(entity)
    end)
end

local function DoAnimation(dict, clip, bone, offset, rot, model, isCurrentlyViewing)
    Citizen.CreateThread(function()

        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do 
            Citizen.Wait(0)
        end

        local model = GetHashKey(clipboard)
        RequestModel(model)
        while not HasModelLoaded(model) do 
            Citizen.Wait(0)
        end

        local prop = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        local boneIndex = GetPedBoneIndex(PlayerPedId(), bone)
        AttachEntityToEntity(prop, PlayerPedId(), boneIndex, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, true, false, false, false, 2, true)
        SetModelAsNoLongerNeeded(prop)
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(0)
                if IsCurrentlyViewing then 
                    if not IsEntityPlayingAnim(PlayerPedId(), dict, clip, 3) then
                        TaskPlayAnim(PlayerPedId(), dict, clip, 3.0, 3.0, -1, 49, 0, 0, 0, 0)
                    end
                else
                    ClearPedSecondaryTask(PlayerPedId())
                    DetachAnim(prop)
                    break 
                end
            end
        end)
    end)
end

Citizen.CreateThread(function()
    if string.find(Targ, 'ox') then 
        exports.ox_target:addGlobalVehicle({
            label = 'Look at VIN',
            icon = 'fa-solid fa-hashtag',
            distance = 2.5,
            onSelect = function(data)
                local vehicle = data.entity 
                if not Entity(vehicle).state.vin then 
                    local plate = GetVehicleNumberPlateText(vehicle)
                    local Gen = GenerateVin()
                    while true do 
                        Citizen.Wait(0)
                        if type(Gen) == 'string' then 
                            if string.len(Gen) == 10 then 
                                break 
                            end
                        end
                    end
                    local replace = plate .. Gen

                    local VIN = lib.callback.await('browns_registration:server:EnsureVehicleVIN', false, plate, replace)

                    Entity(vehicle).state:set('vin', VIN, true)

                    ShowVin(VIN)
                else
                    ShowVin(Entity(vehicle).state.vin)
                end
            end
        })
    else
        exports[Targ]:AddGlobalVehicle({
            options = { 
                { 
                    icon = 'fa-solid fa-hashtag', 
                    label = 'Look at VIN', 
                    action = function(entity) 
                        local vehicle = entity
                        if not Entity(vehicle).state.vin then 
                            local plate = GetVehicleNumberPlateText(vehicle)
                            local Gen = GenerateVin()
                            while true do 
                                Citizen.Wait(0)
                                if type(Gen) == 'string' then 
                                    if string.len(Gen) == 10 then 
                                        break 
                                    end
                                end
                            end
                            local replace = plate .. Gen
        
                            local VIN = lib.callback.await('browns_registration:server:EnsureVehicleVIN', false, plate, replace)
        
                            Entity(vehicle).state:set('vin', VIN)
        
                            ShowVin(VIN)
                        else
                            ShowVin(Entity(vehicle).state.vin)
                        end
                    end,
                    
                }
            },
            distance = 2.5,
        })
    end
end)

function ShowVin(vin)
    lib.alertDialog({
        header = 'VIN Number:',
        content = vin,
        centered = true,
        cancel = false,
        labels = {
            confirm = 'Okay'
        }
    })
end

function OnEnter(self, type)
    inZone = true
    if type == 'registration' then
        lib.showTextUI('[E] - Vehicle Registration')
    elseif type == 'insurance' then
        lib.showTextUI('[E] - Vehicle Insurance')
    end

    Citizen.CreateThread(function()
        while inZone do 
            Citizen.Wait(0)
            if IsControlJustPressed(0, 46) then 
                lib.hideTextUI()
                OpenMenu(type)
                inZone = false 
                break 
            end
        end
    end)
end

function OnExit(self)
    inZone = false 
    lib.hideTextUI()
end

Citizen.CreateThread(function()
    lib.zones.box({
        coords = config.locations.registration,
        OnEnter = OnEnter('registration'),
        OnExit = OnExit
    })
    lib.zones.box({
        coords = config.locations.insurance,
        OnEnter = OnEnter('insurance'),
        onExit = OnExit
    })
end)

function OpenMenu(type)
    if type == 'registration' then
        local plates = {}

        local vehicles, playerName = lib.callback.await('browns_registration:server:GetVehicles', false)
    
        if FW == 'esx' then 
            local pdata = CORE.GetPlayerData() 
            
            if pdata and pdata.firstName and pdata.lastName then 
                playerName = pdata.firstName .. " " .. pdata.lastName
            else
                playerName = lib.callback.await('browns_registration:server:esxdataName', false)
            end
            
        end
    
        if vehicles[1] then 
            for i = 1, #vehicles do 
                local data = vehicles[i]
                table.insert(plates, {
                    title = data.plate,
                    description = 'Click to Purchase Registration for vehicle with plate:' .. " " .. data.plate,
                    onSelect = function()
                        local bool = lib.callback.await('browns_registration:server:AddRegistration', false, data.plate, playerName)
                        
                        if not bool then 
                            Notify('Vehicle Registration', 'You dont have enough money', 'error', 5000)
                        end
                    end
                })
            end
    
            lib.registerContext({
                id = 'browns_registration',
                title = 'Vehicle Registration',
                options = plates
            })
    
            lib.showContext('browns_registration')
    
        else
    
            Notify('Vehicle Registration', 'You dont own any vehicles', 'error', 5000)
    
        end
    elseif type == 'insurance' then
        local plates = {}
        local vehicles, playerName = lib.callback.await('browns_registration:server:GetVehicles', false)
    
        if FW == 'esx' then 
            local pdata = CORE.GetPlayerData() 
            if pdata and pdata.firstName and pdata.lastName then 
                playerName = pdata.firstName .. " " .. pdata.lastName
            else
                playerName = lib.callback.await('browns_registration:server:esxdataName', false)
            end
        end
    
        if vehicles[1] then 
            for i = 1, #vehicles do
                local data = vehicles[i]
                table.insert(plates, {
                    label = 'Plate:' .. " " .. data.plate,
                    value = data.plate
                })
            end
    
            local input = lib.inputDialog('Purchase Insurance - ($' .. tostring(config.costs.insurance) .. " Per Month)", {
                {type = 'select', label = 'Choose Vehicle', options = plates, description = 'Choose Vehicle By Plate'},
                {type = 'select', label = 'Choose Plan', options = {
                    {label = '1 Month', value = '30'},
                    {label = '2 Month', value = '60'},
                    {label = '3 Month', value = '90'},
                    {label = '4 Month', value = '120'},
                    {label = '5 Month', value = '150'},
                    {label = '6 Month', value = '180'},
                    {label = '7 Month', value = '210'},
                    {label = '8 Month', value = '240'},
                    {label = '9 Month', value = '270'},
                    {label = '10 Month', value = '300'},
                    {label = '11 Month', value = '330'},
                    {label = '12 Month', value = '360'},
                }},
            })
        
            if input then 
                local _, playerName = lib.callback.await('browns_registration:server:GetVehicles', false)
        
                if FW == 'esx' then 
                    local pdata = CORE.GetPlayerData()
                    if pdata and pdata.firstName and pdata.lastName then 
                        playerName = pdata.firstName .. " " .. pdata.lastName
                    else
                        playerName = lib.callback.await('browns_registration:server:esxdataName', false)
                    end
                end
        
                local bool = lib.callback.await('browns_registration:server:AddInsurance', false, input[1], input[2], playerName)
        
                if not bool then 
                    Notify('Vehicle Insurance', 'You Dont have enough money', 'error', 5000)
                end
            end
    
        else
            Notify('Vehicle Insurance', 'You dont own any vehicles', 'error', 5000)
    
        end
    end
end

Citizen.CreateThread(function()
    if config.blip.registration.enable then 

        local blipsettings = config.blip.registration

        local x, y, z = table.unpack(config.locations.registration)
        local blip = AddBlipForCoord(x, y, z)
        SetBlipSprite(blip, blipsettings.sprite)
        SetBlipColour(blip, blipsettings.color)
        SetBlipDisplay(blip, 4)
        SetBlipAlpha(blip, 250)
        SetBlipScale(blip, blipsettings.scale)
        SetBlipAsShortRange(blip, true)
        PulseBlip(blip)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(blipsettings.label)
        EndTextCommandSetBlipName(blip)

    end
end)

Citizen.CreateThread(function()
    if config.blip.insurance.enable then 

        local blipsettings = config.blip.insurance

        local x, y, z = table.unpack(config.locations.insurance)
        local blip = AddBlipForCoord(x, y, z)
        SetBlipSprite(blip, blipsettings.sprite)
        SetBlipColour(blip, blipsettings.color)
        SetBlipDisplay(blip, 4)
        SetBlipAlpha(blip, 250)
        SetBlipScale(blip, blipsettings.scale)
        SetBlipAsShortRange(blip, true)
        PulseBlip(blip)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(blipsettings.label)
        EndTextCommandSetBlipName(blip)

    end
end)

RegisterNetEvent('browns_registration:client:ShowRegistration', function(plate, name, date)

    if not IsCurrentlyViewing then 
        IsCurrentlyViewing = true
        local Gen = GenerateVin()

        while true do 
            Citizen.Wait(0)
            if type(Gen) == 'string' then 
                if string.len(Gen) == 10 then 
                    break 
                end
            end
        end
    
        local comb = plate .. Gen 
    
        local VIN, netId = lib.callback.await('browns_registration:server:HandleVehicleVIN', false, plate, comb)
    
        if netId ~= false then 
            local vehicle = NetToVeh(netId)
    
            if Entity(vehicle).state.vin ~= nil and string.len(Entity(vehicle).state.vin) >= 10 then 
    
                VIN = Entity(vehicle).state.vin
    
            else
    
                Entity(vehicle).state:set('vin', VIN, true)
    
            end
    
        end
    
        SendNUIMessage({
            show = 'reg',
            plate = 'Plate:' .. " " .. plate, 
            name = 'Owner:' .. " " .. name,
            vin = 'VIN:' .. " " .. VIN,
            date = 'REGISTRATION DATE:' .. " " .. date,
            msg = 'REGISTRATION SHALL EXPIRE' .. " " .. tostring(config.expire) .. " " .. 'DAYS AFTER ABOVE DATE'
        })

        DoAnimation(dict, clip, bone, offset, rot, clipboard, true)
    
        Citizen.CreateThread(function()
            while true do 
                Citizen.Wait(0)
                if IsControlJustPressed(0, 202) then 
                    SendNUIMessage({
                        show = 'hide'
                    })  
                    IsCurrentlyViewing = false
                    break 
                end
            end
        end)
    else
        Notify('Notification', 'You cant do this, your already viewing paperwork', 'error', 5000)
    end
    
end)

RegisterNetEvent('browns_registration:client:ShowInsurance', function(plate, name, date, expire)

    if not IsCurrentlyViewing then 

        IsCurrentlyViewing = true
        local Gen = GenerateVin()
        local comb = plate .. Gen 
        local VIN, netId = lib.callback.await('browns_registration:server:HandleVehicleVIN', false, plate, comb)

        if netId ~= false then 
            local vehicle = NetToVeh(netId)
    
            if Entity(vehicle).state.vin ~= nil and string.len(Entity(vehicle).state.vin) >= 10 then 
    
                VIN = Entity(vehicle).state.vin
    
            else
    
                Entity(vehicle).state:set('vin', VIN, true)
    
            end
    
        end
    
    
        SendNUIMessage({
            show = 'ins',
            plate = 'Plate:' .. " " .. plate, 
            name = 'Owner:' .. " " .. name,
            vin = 'VIN:' .. " " .. VIN,
            date = 'PAYMENT DATE:' .. " " .. date,
            msg = 'INSURANCE SHALL EXPIRE' .. " " .. expire .. " " .. 'DAYS AFTER ABOVE DATE'
        })

        DoAnimation(dict, clip, bone, offset, rot, clipboard, true)
    
        Citizen.CreateThread(function()
            while true do 
                Citizen.Wait(0)
                if IsControlJustPressed(0, 202) then 
                    SendNUIMessage({
                        show = 'hide'
                    })  
                    IsCurrentlyViewing = false
                    break 
                end
            end
        end)
    else
        Notify('Notification', 'You cant do this, your already viewing paperwork', 'error', 5000)
    end

end)