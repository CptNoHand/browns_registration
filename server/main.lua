local FW = config.Core.framework

local INV = config.Core.inventory

Citizen.CreateThread(function()
    if FW == 'esx' then 
        if string.find(INV, 'qs') then 
            exports['qs-inventory']:CreateUsableItem('vehicle_reg', function(source, item)
                TriggerClientEvent('browns_registration:client:ShowPaperwork', source, item.info.regPlate, item.info.regName, item.info.regDate, nil, 'registration')
            end)
            exports['qs-inventory']:CreateUsableItem('vehicle_ins', function(source, item)
                TriggerClientEvent('browns_registration:client:ShowPaperwork', source, item.info.regPlate, item.info.regName, item.info.regDate, item.info.regExpire, 'insurance')
            end)
        end
    elseif FW == 'qb-core' then 
        if not string.find(INV, 'ox') and not string.find(INV, 'qs') then 
            CORE.Functions.CreateUseableItem('vehicle_reg', function(source, item)
                TriggerClientEvent('browns_registration:client:ShowPaperwork', source, item.info.regPlate, item.info.regName, item.info.regDate, nil, 'registration')
            end)

            CORE.Functions.CreateUseableItem('vehicle_ins', function(source, item)
                TriggerClientEvent('browns_registration:client:ShowPaperwork', source, item.info.regPlate, item.info.regName, item.info.regDate, item.info.regExpire, 'insurance')
            end)
        end

        if string.find(INV, 'qs') then 
            exports['qs-inventory']:CreateUsableItem('vehicle_reg', function(source, item)
                TriggerClientEvent('browns_registration:client:ShowPaperwork', source, item.info.regPlate, item.info.regName, item.info.regDate, nil, 'registration')
            end)
            exports['qs-inventory']:CreateUsableItem('vehicle_ins', function(source, item)
                TriggerClientEvent('browns_registration:client:ShowPaperwork', source, item.info.regPlate, item.info.regName, item.info.regDate, item.info.regExpire, 'insurance')
            end)
        end
    end
end)

exports('UseRegistration', function(event, item, inventory, slot)

    item = exports.ox_inventory:GetSlot(inventory.id, slot)

    if event == 'usingItem' then
        TriggerClientEvent('browns_registration:client:ShowRegistration', inventory.id, item.metadata.regPlate, item.metadata.regName, item.metadata.regDate)

        return false
    end

end)

exports('UseInsurance', function(event, item, inventory, slot)

    item = exports.ox_inventory:GetSlot(inventory.id, slot)

    if event == 'usingItem' then
        TriggerClientEvent('browns_registration:client:ShowInsurance', inventory.id, item.metadata.regPlate, item.metadata.regName, item.metadata.regDate, item.metadata.regExpire)

        return false
    end

end)

lib.callback.register('browns_registration:server:GetVehicles', function(source)
    local player = exports.browns_registration:getPlayer(source)
    local id = exports.browns_registration:getId(player)

    local name = nil 

    local data = nil 

    if FW == 'esx' then 
        local vehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ?', {
            id
        })

        data = vehicles 


    elseif  FW == 'qb-core' then 
        local vehicles = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', {
            id
        })

        data = vehicles 

        name = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
    end

    return data, name
end)

lib.callback.register('browns_registration:server:CheckIfVehicleHasVin', function (source, plate)
    local returnData = nil
    if FW == 'esx' then
        -- add esx logic
    elseif FW == 'qb-core' then
        local vehicleFromDB = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?', {plate})
        -- note: below we check for the 1st row of vehicleFromDB as it retruns a table array and not row (yea I know, stupid)
        if vehicleFromDB[1] and vehicleFromDB[1].vin then -- if vehicle is in DB and has a vin
            returnData = vehicleFromDB[1] -- return the vin
        elseif vehicleFromDB[1] and vehicleFromDB[1].vin == nil then -- if vehicle is in DB but has no vin
            returnData = ''
        end
    end

    return returnData
    -- returnData values:
    -- nil  = vehicle not player
    -- ''   = vehicle is player but has no vin
    -- else = vin number
end)

lib.callback.register('browns_registration:server:RegisterVinToDB', function (source, plate, generatedVin)
    if FW == 'esx' then
        -- add esx logic
    elseif FW == 'qb-core' then
        MySQL.update.await('UPDATE player_vehicles SET vin = ? WHERE plate = ?', {generatedVin, plate})
    end
end)

lib.callback.register('browns_registration:server:DeliverPaperwork', function(source, plate, name, plan)
    local player = exports.browns_registration:getPlayer(source)

    local registrationCost = config.costs.registration
    local insuranceCost = tonumber(plan) / 30 * config.costs.insurance
    local totalCost = registrationCost + insuranceCost

    local amount
    local canPurchase = false

    -- Check player's balance
    if FW == 'esx' then
        local bal = player.getAccounts()
        for _, v in ipairs(bal) do
            if v.name == 'money' then
                amount = v.money
                break
            end
        end
    elseif FW == 'qb-core' then
        amount = player.PlayerData.money.cash
    end

    -- Check if player can afford both registration and insurance
    if amount >= totalCost then
        canPurchase = true
    end

    if canPurchase then
        -- Deduct the total cost from player's balance
        if FW == 'esx' then
            player.removeAccountMoney('money', totalCost)
        elseif FW == 'qb-core' then
            player.Functions.RemoveMoney('cash', totalCost, 'Vehicle Registration and Insurance')
        end

        -- Add registration paperwork to player's inventory
        exports.browns_registration:AddPaperworkToPlayerInventory(source, 'vehicle_reg', plate, name, os.date(), nil)

        -- If insurance plan is provided, add insurance paperwork as well
        if plan and tonumber(plan) > 0 then
            exports.browns_registration:AddPaperworkToPlayerInventory(source, 'vehicle_ins', plate, name, os.date(), tostring(plan))
        end
    end

    return canPurchase
end)

lib.callback.register('browns_registration:server:esxdataName', function(source)
    local player = exports.browns_registration:getPlayer(source)
    local identifier = exports.browns_registration:getId(player)

    local data = MySQL.query.await('SELECT * FROM users WHERE identifier = ?', {
        identifier
    })

    name = data[1].firstname .. " " .. data[1].lastname

    return name

end)
