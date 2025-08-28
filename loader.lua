repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.GameId ~= 0

if Testhook and Testhook.Loaded then return end

local PlayerService = game:GetService("Players")
repeat task.wait() until PlayerService.LocalPlayer
local LocalPlayer = PlayerService.LocalPlayer

local Branch, NotificationTime, IsLocal = ...
local QueueOnTeleport = queue_on_teleport

local function get_file(path)
    return IsLocal and readfile("testhook/" .. path)
    or game:HttpGet(("https://raw.githubusercontent.com/beiley/testhook/main/%s"):format(path))
end

local function load_script(path)
    return loadstring(get_file(path .. ".lua"), path)()
end

local function get_game_info()
    for id, info in pairs(Testhook.Games) do
        if tostring(game.GameId) == id then
            return info
        end
    end
    return Testhook.Games.Universal
end

getgenv().Testhook = {
    Source = "https://raw.githubusercontent.com/beiley/testhook/main/",
    Games = {
        ["Universal"] = { Name = "Universal", Script = "games/universal" }
    }
}

Testhook.Drawing = load_script("utilities/drawing")
Testhook.Library = load_script("utilities/library")
Testhook.Main    = load_script("utilities/main")
Testhook.Physics = load_script("utilities/physics")

Testhook.Loadstring = get_file("loader.lua")
LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.InProgress then
        QueueOnTeleport(Testhook.Loadstring)
    end
end)

Testhook.Game = get_game_info()
load_script(Testhook.Game.Script)
Testhook.Loaded = true
