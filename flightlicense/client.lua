local QBCore = exports['qb-core']:GetCoreObject()

-- Configuration
local Config = {
    helicopters = {
        theory = "theory_helicopter",
        practical = "practical_helicopter"
    },
    planes = {
        theory = "theory_plane",
        practical = "practical_plane"
    },
    -- Vehicles allowed for flight test (theory license only)
    -- Add the spawn names of vehicles you want to allow for testing
    testVehicles = {
        -- Helicopters
        "frogger",      -- Example helicopter for testing
        -- Planes       -- Example plane for testing
        "vestra",       -- Example plane for testing
    }
}

-- Vehicle classes
local VEHICLE_CLASS = {
    HELICOPTER = 15,
    PLANE = 16
}

-- Check if vehicle is a test vehicle
local function IsTestVehicle(vehicle)
    local model = GetEntityModel(vehicle)
    local modelName = string.lower(GetDisplayNameFromVehicleModel(model))
    
    for _, testVehicle in ipairs(Config.testVehicles) do
        if string.lower(testVehicle) == modelName then
            return true
        end
    end
    return false
end

-- Check if player has required licenses
local function HasFlightLicense(licenseType, isTestVehicle)
    local Player = QBCore.Functions.GetPlayerData()
    if not Player or not Player.metadata then return false end
    
    local licenses = Player.metadata.licences or Player.metadata.licenses
    if not licenses then return false end
    
    if licenseType == "helicopter" then
        -- Test vehicles only need theory, regular vehicles need practical
        if isTestVehicle then
            return licenses[Config.helicopters.theory]
        else
            return licenses[Config.helicopters.practical]
        end
    elseif licenseType == "plane" then
        -- Test vehicles only need theory, regular vehicles need practical
        if isTestVehicle then
            return licenses[Config.planes.theory]
        else
            return licenses[Config.planes.practical]
        end
    end
    
    return false
end

-- Track if notification has been sent for current vehicle
local notifiedVehicle = nil

-- Main thread to check vehicle and disable flight
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            local seat = GetPedInVehicleSeat(vehicle, -1)
            
            -- Only check if player is the driver
            if seat == ped then
                local vehicleClass = GetVehicleClass(vehicle)
                local shouldDisable = false
                local licenseType = nil
                local isTestVehicle = IsTestVehicle(vehicle)
                
                if vehicleClass == VEHICLE_CLASS.HELICOPTER then
                    licenseType = "helicopter"
                    shouldDisable = not HasFlightLicense("helicopter", isTestVehicle)
                elseif vehicleClass == VEHICLE_CLASS.PLANE then
                    licenseType = "plane"
                    shouldDisable = not HasFlightLicense("plane", isTestVehicle)
                end
                
                if shouldDisable then
                    sleep = 0
                    
                    -- Send notification only once per vehicle
                    if notifiedVehicle ~= vehicle then
                        local licenseText = licenseType == "helicopter" and "helicopter" or "plane"
                        local requiredLicense = isTestVehicle and "theory" or "practical"
                        QBCore.Functions.Notify("You need a " .. licenseText .. " " .. requiredLicense .. " license to fly this vehicle!", "error")
                        notifiedVehicle = vehicle
                    end
                    
                    -- Disable flight controls
                    DisableControlAction(0, 87, true)  -- Mouse up/down (pitch)
                    DisableControlAction(0, 88, true)  -- Mouse left/right (roll)
                    DisableControlAction(0, 32, true)  -- W (throttle up)
                    DisableControlAction(0, 33, true)  -- S (throttle down)
                    DisableControlAction(0, 34, true)  -- A (yaw left)
                    DisableControlAction(0, 35, true)  -- D (yaw right)
                    DisableControlAction(0, 85, true)  -- Q (rudder left)
                    DisableControlAction(0, 86, true)  -- E (rudder right)
                    DisableControlAction(0, 107, true) -- Mouse wheel up
                    DisableControlAction(0, 108, true) -- Mouse wheel down
                    
                    -- Keep vehicle grounded
                    SetVehicleEngineOn(vehicle, false, true, true)
                end
            end
        else
            -- Reset notification tracker when not in vehicle
            notifiedVehicle = nil
        end
        
        Wait(sleep)
    end
end)

-- Event to refresh player data when licenses are updated
RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    -- This event fires when player data is updated
    -- The script will automatically check new license data
end)

-- Command to check your current flight licenses (for testing)
RegisterCommand('checklicenses', function()
    local Player = QBCore.Functions.GetPlayerData()
    if Player and Player.metadata then
        local licenses = Player.metadata.licences or Player.metadata.licenses
        
        if licenses then
            local hasHeliTheory = licenses[Config.helicopters.theory] or false
            local hasHeliPractical = licenses[Config.helicopters.practical] or false
            local hasPlaneTheory = licenses[Config.planes.theory] or false
            local hasPlanePractical = licenses[Config.planes.practical] or false
            
            print("=== Flight Licenses ===")
            print("Helicopter Theory: " .. tostring(hasHeliTheory))
            print("Helicopter Practical: " .. tostring(hasHeliPractical))
            print("Plane Theory: " .. tostring(hasPlaneTheory))
            print("Plane Practical: " .. tostring(hasPlanePractical))
        else
            print("No licenses found in metadata")
        end
    end
end, false)