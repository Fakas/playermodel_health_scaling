-- Set up PHS object
PHS = {}
PHS.__index = PHS

-- Set up ConVars
CreateConVar("phs_enable", "1", FCVAR_NONE, "Enable Playermodel Health Scaling", 0, 1)
CreateConVar("phs_debug", "0", FCVAR_NONE, "Enable debug messages in the console", 0, 1)
CreateConVar("phs_health_modifier", "100", FCVAR_NONE, "Global health modifier", 0)

-- Set up commands
concommand.Add("phs_rescale", function() PHS:scale_all() end, nil, "Perform health scaling on all alive players with their current playermodels")
concommand.Add("phs_restart", function() PHS:init() end, nil, "Reload the playermodel health file and reinitialise PHS")

-- PHS functions
function PHS:get_line(list_file)
    -- Get a new line from the playermodel health file and remove newline characters
    local debug = GetConVar("phs_debug"):GetInt()
    if debug == 1 then print("PHS: Reading a new line from the playermodel health file...") end
    local line = list_file:ReadLine()
    local _
    if line == nil then
        if debug == 1 then print("PHS: Reached end of playermodel health file!") end
        return nil
    end
    local line, _ = string.gsub(line, "\n", "")
    if debug == 1 then print("PHS: The line is: "..line) end
    return line
end

function PHS:get_health(model)
    -- Get the configured health for a given playermodel, or 100 if not configured
    local debug = GetConVar("phs_debug"):GetInt()
    local health_num = PHS["playermodel_health"][model]
    if health_num == nil then
        if debug == 1 then print("PHS: Model \""..model.."\" has no entry in the playermodel_health table so health will be set to 100!") end
        return 100
    else
        if debug == 1 then print("PHS: Returning health for model \""..model.."\" as "..health_num) end
        return health_num
    end
end

function PHS:set_health(player, health)
    -- Set a player's health to a value, multiplied by the global health modifier
    local debug = GetConVar("phs_debug"):GetInt()
    health = health * GetConVar("phs_health_modifier"):GetInt() / 100
    if debug == 1 then print("PHS: Setting health of player \""..player:Nick().."\" to "..health) end
    player:SetMaxHealth(health)
    player:SetHealth(health)
end

function PHS:scale(player)
    -- Scale a player's health based on their playermodel
    local debug = GetConVar("phs_debug"):GetInt()
    if debug == 1 then print("Scaling health of player \""..player:Nick().."\"...") end
    if player.phs_immunity ~= 0 then
        if debug == 1 then print("Player has immunity so health will not be scaled!") end
        return
    end
    if GetConVar("phs_enable"):GetInt() == 1 then
        -- We have to set this 0 timer to prevent the gamemode from overriding our health changes
        timer.Simple(0.2, function() PHS:set_health(player, PHS:get_health(player:GetModel())) end)
    end
end

function PHS:init()
    -- Initialise setup for PHS
    local debug = GetConVar("phs_debug"):GetInt()
    
    print("PHS: Initialising Playermodel Health Scaling!")
    local file_name = "phs_playermodel_health.txt"
    if debug == 1 then print("Checking for playermodel health file...") end
    local list_file
    if not file.Exists(file_name, "DATA") then
        list_file = file.Open(file_name, "w", "DATA")
    else
        list_file = file.Open(file_name, "r", "DATA")
    end
    
    local playermodel_health = {}
    if debug == 1 then print("Reading model/health key/value pairs from playermodel health file...") end
    while true do
        local model_line = PHS:get_line(list_file)
        local health_line = PHS:get_line(list_file)
        if model_line == nil or health_line == nil then
            break
        end
        if debug == 1 then print(model_line .. ": ".. health_line) end
        playermodel_health[model_line] = tonumber(health_line)
    end
    list_file:Close()
    PHS["playermodel_health"] = playermodel_health

    -- Set up hooks
    hook.Add("PlayerSpawn", "PHS_SetImmunity", function(player) PHS:set_immunity(player, 0) end) -- Set the player's initial PHS immunity level
    hook.Add("PlayerSpawn", "PHS_PlayerSpawn", function(player) PHS:scale(player) end) -- Scale health on player spawn
    hook.Add("TTTPrepareRound", "PHS_TTTPrepareRound", function() PHS:wipe_immunity(1) end) -- Wipe immunity before round start
    hook.Add("TTTBeginRound", "PHS_TTTBeginRound", function() PHS:wipe_immunity(1) end) -- Wipe immunity on round start
    hook.Add("TTTEndRound", "PHS_TTTEndRound", function(_) PHS:wipe_immunity(1) end) -- Wipe immunity on round end

    print("PHS: Done initialising Playermodel Health Scaling!")
end

function PHS:wipe_immunity(level)
    -- Wippe immunity at or below a certian level from all players
    local players = player.GetAll()
    for _, ply in pairs(players) do
        PHS:clear_immunity(ply, level)
    end
end

function PHS:clear_immunity(ply, level)
    -- Remove immunity at or below a certain level from a player
    if ply.phs_immunity == nil or ply.phs_immunity <= level then
        ply.phs_immunity = 0
    end
end

function PHS:set_immunity(ply, level)
    -- Ensure player has an immunity value
    if ply.phs_immunity == nil then
        ply.phs_immunity = level
    end
end

function PHS:scale_all()
    -- Scale every player's health
    players = player.GetAll()
    for _, ply in pairs(players) do
        PHS:scale(ply)
    end
end

-- First time init
PHS:init()
