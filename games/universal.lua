local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local PlayerService    = game:GetService("Players")
local Workspace        = game:GetService("Workspace")

repeat task.wait() until PlayerService.LocalPlayer
local LocalPlayer = PlayerService.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

local silent_aim_target = nil
local aimbot_down = false
local trigger_down = false

local projectile_speed = 1000
local projectile_gravity = 196.2
local gravity_correction = 2

local known_body_parts = {
    "Head","HumanoidRootPart","Torso","UpperTorso","LowerTorso",
    "RightUpperArm","RightLowerArm","RightHand","LeftUpperArm","LeftLowerArm","LeftHand",
    "RightUpperLeg","RightLowerLeg","RightFoot","LeftUpperLeg","LeftLowerLeg","LeftFoot"
}

local ray_params = RaycastParams.new()
ray_params.FilterType = Enum.RaycastFilterType.Blacklist
ray_params.IgnoreWater = true

local function perform_raycast(origin, dir, ignore)
    ray_params.FilterDescendantsInstances = ignore
    return Workspace:Raycast(origin, dir, ray_params)
end

local function is_enemy_team(on, player)
    if not on then return true end
    if not LocalPlayer.Team or not player.Team then return true end
    return LocalPlayer.Team ~= player.Team
end

local function distance_check(on, dist, limit)
    if not on then return true end
    return dist < limit
end

local function occluded(on, origin, hitpos, target_char)
    if not on then return false end
    return perform_raycast(origin, hitpos - origin, {target_char, LocalPlayer.Character})
end

local function solve_prediction(origin, vel, time_s)
    return Testhook.Physics and Testhook.Physics.SolveTrajectory
        and Testhook.Physics.SolveTrajectory(origin, origin, vel, projectile_speed, projectile_gravity, gravity_correction)
        or (origin + vel * time_s + Vector3.new(0, -projectile_gravity, 0) * (time_s * time_s) / gravity_correction)
end

local function v2(x, y) return Vector2.new(x, y) end

local function select_body_parts(priority, parts_map)
    if priority == "Closest" then
        local list = {}
        for name, on in pairs(parts_map) do
            if on then table.insert(list, name) end
        end
        if #list == 0 then
            return {"Head","HumanoidRootPart"}
        end
        return list
    elseif priority == "Random" then
        local list = {}
        for name, on in pairs(parts_map) do
            if on then table.insert(list, name) end
        end
        if #list == 0 then return {"Head"} end
        return { list[math.random(#list)] }
    else
        return { priority }
    end
end

local function body_parts_from_option(opt_table)
    -- linoria multi dropdown stores selected values as a map lmfao { ["Head"]=true, ... }
    local out = {}
    for k,v in pairs(opt_table or {}) do
        if v then out[k] = true end
    end
    return out
end

local function find_target(enabled, team_check, vis_check, dist_check, dist_limit, fov, priority, parts_multi, do_prediction)
    if not enabled then return nil end

    local camera_pos = Camera.CFrame.Position
    local best, best_fov = nil, fov

    for _, plr in ipairs(PlayerService:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end

        if not is_enemy_team(team_check, plr) then continue end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local parts_map = body_parts_from_option(parts_multi)
        local chosen = select_body_parts(priority, parts_map)

        for _, part_name in ipairs(chosen) do
            local part = char:FindFirstChild(part_name)
            if not part or not part:IsA("BasePart") then continue end

            local pos = part.Position
            local dist = (pos - camera_pos).Magnitude

            if do_prediction then
                local t = dist / math.max(1, projectile_speed)
                pos = solve_prediction(pos, part.AssemblyLinearVelocity, t)
                dist = (pos - camera_pos).Magnitude
            end

            if not distance_check(dist_check, dist, dist_limit) then continue end
            if occluded(vis_check, camera_pos, pos, char) then continue end

            local sp, on = Camera:WorldToViewportPoint(pos)
            if not on then continue end

            local mpos = UserInputService:GetMouseLocation()
            local delta = (v2(sp.X, sp.Y) - mpos).Magnitude
            if delta >= best_fov then continue end

            best_fov = delta
            best = { plr, char, part, v2(sp.X, sp.Y) }
            if priority ~= "Closest" then
                return best
            end
        end
    end

    return best
end

local function aim_at(target, sens)
    if not target then return end
    local m = UserInputService:GetMouseLocation()
    local dx = (target[4].X - m.X) * sens
    local dy = (target[4].Y - m.Y) * sens
    mousemoverel(dx, dy)
end

local Window = Testhook.Library:CreateWindow({
    Title = string.format("Testhook %s %s", utf8.char(8212), Testhook.Game.Name),
    Position = UDim2.new(0.5, -248 * 3, 0.5, -248),
    AutoShow = true
})

local CombatTab = Window:AddTab("Combat")

local PredBox = CombatTab:AddLeftGroupbox("Prediction")
PredBox:AddSlider("prediction_velocity", {Text="Velocity",Min=1,Max=10000,Default=1000,Rounding=0,Callback=function(v) projectile_speed=v end})
PredBox:AddSlider("prediction_gravity",  {Text="Gravity", Min=0,Max=1000, Default=196.2,Rounding=1,Callback=function(v) projectile_gravity=v end})
PredBox:AddSlider("prediction_grav_corr",{Text="Gravity Correction",Min=1,Max=5,Default=2,Rounding=0,Callback=function(v) gravity_correction=v end})

local AimbotBox = CombatTab:AddLeftGroupbox("Aimbot")
local t_aimbot = AimbotBox:AddToggle("aimbot_enabled",{Text="Enabled",Default=false})
t_aimbot:AddKeyPicker("aimbot_key",{Default="MB2",Text="Aimbot Key",Mode="Hold",Callback=function(isDown) aimbot_down = Toggles.aimbot_enabled.Value and isDown end})
AimbotBox:AddToggle("aimbot_always",{Text="Always Enabled",Default=false})
AimbotBox:AddToggle("aimbot_pred",{Text="Prediction",Default=false})
AimbotBox:AddToggle("aimbot_team",{Text="Team Check",Default=false})
AimbotBox:AddToggle("aimbot_dist",{Text="Distance Check",Default=false})
AimbotBox:AddToggle("aimbot_vis",{Text="Visibility Check",Default=false})
AimbotBox:AddSlider("aimbot_sens",{Text="Sensitivity",Min=0,Max=100,Default=20,Rounding=0,Suffix="%"})
AimbotBox:AddSlider("aimbot_fov",{Text="Field Of View",Min=0,Max=500,Default=100,Rounding=0,Suffix="px"})
AimbotBox:AddSlider("aimbot_distlim",{Text="Distance Limit",Min=25,Max=1000,Default=250,Rounding=0,Suffix=" studs"})
AimbotBox:AddDropdown("aimbot_prio",{Text="Priority",Values={"Closest","Random","Head","HumanoidRootPart","Torso"},Default=1})
AimbotBox:AddDropdown("aimbot_parts",{Text="Body Parts",Values=known_body_parts,Multi=true,Default={"Head","HumanoidRootPart"}})

local AimbotFOV = CombatTab:AddLeftGroupbox("Aimbot FOV Circle")
AimbotFOV:AddToggle("aimbot_fov_on",{Text="Enabled",Default=true})
AimbotFOV:AddToggle("aimbot_fov_fill",{Text="Filled",Default=false})
local AimbotFovColor = AimbotFOV:AddLabel("Color")
AimbotFovColor:AddColorPicker("aimbot_fov_color", {
    Default = Color3.fromRGB(255, 170, 255),
    Transparency = 0.25
})
AimbotFOV:AddSlider("aimbot_fov_sides",{Text="Num Sides",Min=3,Max=100,Default=14,Rounding=0})
AimbotFOV:AddSlider("aimbot_fov_thick",{Text="Thickness",Min=1,Max=10,Default=2,Rounding=0})

local SilentBox = CombatTab:AddRightGroupbox("Silent Aim")
SilentBox:AddDropdown("silent_modes",{Text="Mode",Values={
    "FindPartOnRayWithIgnoreList","FindPartOnRayWithWhitelist","WorldToViewportPoint","WorldToScreenPoint",
    "ViewportPointToRay","ScreenPointToRay","FindPartOnRay","Raycast","Target","Hit"
},Multi=true,Default={"Target","Hit"}})
local t_silent = SilentBox:AddToggle("silent_on",{Text="Enabled",Default=false})
t_silent:AddKeyPicker("silent_key",{Default="MB1",Text="Silent Aim Key",Mode="Toggle"})
SilentBox:AddToggle("silent_pred",{Text="Prediction",Default=false})
SilentBox:AddToggle("silent_team",{Text="Team Check",Default=false})
SilentBox:AddToggle("silent_dist",{Text="Distance Check",Default=false})
SilentBox:AddToggle("silent_vis",{Text="Visibility Check",Default=false})
SilentBox:AddSlider("silent_hitchance",{Text="Hit Chance",Min=0,Max=100,Default=100,Rounding=0,Suffix="%"})
SilentBox:AddSlider("silent_fov",{Text="Field Of View",Min=0,Max=500,Default=100,Rounding=0,Suffix="px"})
SilentBox:AddSlider("silent_distlim",{Text="Distance Limit",Min=25,Max=1000,Default=250,Rounding=0,Suffix=" studs"})
SilentBox:AddDropdown("silent_prio",{Text="Priority",Values={"Closest","Random","Head","HumanoidRootPart","Torso"},Default=1})
SilentBox:AddDropdown("silent_parts",{Text="Body Parts",Values=known_body_parts,Multi=true,Default={"Head","HumanoidRootPart"}})

local SilentFOV = CombatTab:AddRightGroupbox("Silent Aim FOV Circle")
SilentFOV:AddToggle("silent_fov_on",{Text="Enabled",Default=true})
SilentFOV:AddToggle("silent_fov_fill",{Text="Filled",Default=false})
local SilentFovColor = SilentFOV:AddLabel("Color")
SilentFovColor:AddColorPicker("silent_fov_color", {
    Default = Color3.fromRGB(170, 170, 255),
    Transparency = 0.25
})
SilentFOV:AddSlider("silent_fov_sides",{Text="Num Sides",Min=3,Max=100,Default=14,Rounding=0})
SilentFOV:AddSlider("silent_fov_thick",{Text="Thickness",Min=1,Max=10,Default=2,Rounding=0})

local TriggerBox = CombatTab:AddRightGroupbox("Trigger")
local t_trigger = TriggerBox:AddToggle("trigger_on",{Text="Enabled",Default=false})
t_trigger:AddKeyPicker("trigger_key",{Default="MB2",Text="Trigger Key",Mode="Hold",Callback=function(isDown) trigger_down = Toggles.trigger_on.Value and isDown end})
TriggerBox:AddToggle("trigger_always",{Text="Always Enabled",Default=false})
TriggerBox:AddToggle("trigger_hold",{Text="Hold Mouse Button",Default=false})
TriggerBox:AddToggle("trigger_pred",{Text="Prediction",Default=false})
TriggerBox:AddToggle("trigger_team",{Text="Team Check",Default=false})
TriggerBox:AddToggle("trigger_dist",{Text="Distance Check",Default=false})
TriggerBox:AddToggle("trigger_vis",{Text="Visibility Check",Default=false})
TriggerBox:AddSlider("trigger_delay",{Text="Click Delay",Min=0,Max=1,Default=0.15,Rounding=2,Suffix="s"})
TriggerBox:AddSlider("trigger_distlim",{Text="Distance Limit",Min=25,Max=1000,Default=250,Rounding=0,Suffix=" studs"})
TriggerBox:AddSlider("trigger_fov",{Text="Field Of View",Min=0,Max=500,Default=25,Rounding=0,Suffix="px"})
TriggerBox:AddDropdown("trigger_prio",{Text="Priority",Values={"Closest","Random","Head","HumanoidRootPart","Torso"},Default=1})
TriggerBox:AddDropdown("trigger_parts",{Text="Body Parts",Values=known_body_parts,Multi=true,Default={"Head","HumanoidRootPart"}})

local TriggerFOV = CombatTab:AddRightGroupbox("Trigger FOV Circle")
TriggerFOV:AddToggle("trigger_fov_on",{Text="Enabled",Default=true})
TriggerFOV:AddToggle("trigger_fov_fill",{Text="Filled",Default=false})
local TriggerFovColor = TriggerFOV:AddLabel("Color")
TriggerFovColor:AddColorPicker("trigger_fov_color", {
    Default = Color3.fromRGB(21, 170, 255),
    Transparency = 0.25
})
TriggerFOV:AddSlider("trigger_fov_sides",{Text="Num Sides",Min=3,Max=100,Default=14,Rounding=0})
TriggerFOV:AddSlider("trigger_fov_thick",{Text="Thickness",Min=1,Max=10,Default=2,Rounding=0})

local EspTab = Window:AddTab("ESP")
local EspMain = EspTab:AddLeftGroupbox("Player ESP")

EspMain:AddToggle("player_esp/Enabled", {Text="Enabled", Default=true})
EspMain:AddToggle("player_esp/TeamCheck", {Text="Team Check", Default=false})
EspMain:AddToggle("player_esp/TeamColor", {Text="Use Team Color", Default=true})
EspMain:AddToggle("player_esp/DistanceCheck", {Text="Distance Check", Default=false})
EspMain:AddSlider("player_esp/Distance", {Text="Max Distance", Min=25, Max=5000, Default=1000, Rounding=0, Suffix=" studs"})

local ally_lbl  = EspMain:AddLabel("Ally Color")
ally_lbl:AddColorPicker("player_esp/Ally", {
    Default = Color3.fromRGB(85,170,255),
    Transparency = 0
})

local enemy_lbl = EspMain:AddLabel("Enemy Color")
enemy_lbl:AddColorPicker("player_esp/Enemy", {
    Default = Color3.fromRGB(255,170,255),
    Transparency = 0
})

local BoxGb = EspTab:AddLeftGroupbox("Box")
BoxGb:AddToggle("player_esp/Box/Enabled", {Text="Enabled", Default=true})
BoxGb:AddToggle("player_esp/Box/Outline", {Text="Outline", Default=true})
BoxGb:AddToggle("player_esp/Box/HealthBar", {Text="Health Bar", Default=true})
BoxGb:AddToggle("player_esp/Box/Filled", {Text="Filled", Default=false})
BoxGb:AddSlider("player_esp/Box/CornerSize", {Text="Corner %", Min=0, Max=100, Default=25, Rounding=0})
BoxGb:AddSlider("player_esp/Box/Thickness", {Text="Thickness", Min=1, Max=6, Default=2, Rounding=0})
BoxGb:AddSlider("player_esp/Box/Transparency", {Text="Transparency", Min=0, Max=1, Default=0.0, Rounding=2})

local TracerGb = EspTab:AddRightGroupbox("Tracer")
TracerGb:AddToggle("player_esp/Tracer/Enabled", {Text="Enabled", Default=false})
TracerGb:AddToggle("player_esp/Tracer/Outline", {Text="Outline", Default=true})
TracerGb:AddDropdown("player_esp/Tracer/Mode", {Text="From", Values={"From Mouse","From Bottom"}, Default=2})
TracerGb:AddSlider("player_esp/Tracer/Thickness", {Text="Thickness", Min=1, Max=6, Default=2, Rounding=0})
TracerGb:AddSlider("player_esp/Tracer/Transparency", {Text="Transparency", Min=0, Max=1, Default=0.0, Rounding=2})

local HeadGb = EspTab:AddRightGroupbox("Head Dot")
HeadGb:AddToggle("player_esp/HeadDot/Enabled", {Text="Enabled", Default=false})
HeadGb:AddToggle("player_esp/HeadDot/Outline", {Text="Outline", Default=true})
HeadGb:AddToggle("player_esp/HeadDot/Filled", {Text="Filled", Default=true})
HeadGb:AddToggle("player_esp/HeadDot/Autoscale", {Text="Autoscale", Default=true})
HeadGb:AddSlider("player_esp/HeadDot/Radius", {Text="Radius", Min=1, Max=24, Default=8, Rounding=0})
HeadGb:AddSlider("player_esp/HeadDot/NumSides", {Text="Num Sides", Min=3, Max=64, Default=24, Rounding=0})
HeadGb:AddSlider("player_esp/HeadDot/Thickness", {Text="Thickness", Min=1, Max=6, Default=2, Rounding=0})
HeadGb:AddSlider("player_esp/HeadDot/Transparency", {Text="Transparency", Min=0, Max=1, Default=0.0, Rounding=2})

local ArrowGb = EspTab:AddRightGroupbox("Offscreen Arrows")
ArrowGb:AddToggle("player_esp/Arrow/Enabled", {Text="Enabled", Default=true})
ArrowGb:AddToggle("player_esp/Arrow/Outline", {Text="Outline", Default=true})
ArrowGb:AddToggle("player_esp/Arrow/Filled", {Text="Filled", Default=true})
ArrowGb:AddSlider("player_esp/Arrow/Radius", {Text="Radius", Min=20, Max=500, Default=200, Rounding=0})
ArrowGb:AddSlider("player_esp/Arrow/Height", {Text="Height", Min=6, Max=80, Default=28, Rounding=0})
ArrowGb:AddSlider("player_esp/Arrow/Width",  {Text="Width",  Min=6, Max=80, Default=28, Rounding=0})
ArrowGb:AddSlider("player_esp/Arrow/Thickness", {Text="Thickness", Min=1, Max=6, Default=2, Rounding=0})
ArrowGb:AddSlider("player_esp/Arrow/Transparency", {Text="Transparency", Min=0, Max=1, Default=0.0, Rounding=2})

local NameGb = EspTab:AddLeftGroupbox("Name")
NameGb:AddToggle("player_esp/Name/Enabled", {Text="Enabled", Default=true})
NameGb:AddToggle("player_esp/Name/Outline", {Text="Outline", Default=true})
NameGb:AddToggle("player_esp/Name/Autoscale", {Text="Autoscale", Default=true})
NameGb:AddSlider("player_esp/Name/Size", {Text="Size", Min=10, Max=32, Default=14, Rounding=0})
NameGb:AddSlider("player_esp/Name/Transparency", {Text="Transparency", Min=0, Max=1, Default=0.0, Rounding=2})

local HealthGb = EspTab:AddLeftGroupbox("Health Text")
HealthGb:AddToggle("player_esp/Health/Enabled", {Text="Enabled", Default=false})
HealthGb:AddToggle("player_esp/Health/Outline", {Text="Outline", Default=true})
HealthGb:AddToggle("player_esp/Health/Autoscale", {Text="Autoscale", Default=true}) -- not read directly but consistent
HealthGb:AddSlider("player_esp/Health/Size", {Text="Size", Min=10, Max=32, Default=12, Rounding=0})
HealthGb:AddSlider("player_esp/Health/Transparency", {Text="Transparency", Min=0, Max=1, Default=0.0, Rounding=2})

local DistGb = EspTab:AddLeftGroupbox("Distance Text")
DistGb:AddToggle("player_esp/Distance/Enabled", {Text="Enabled", Default=true})
DistGb:AddToggle("player_esp/Distance/Outline", {Text="Outline", Default=true})
DistGb:AddToggle("player_esp/Distance/Autoscale", {Text="Autoscale", Default=true})
DistGb:AddSlider("player_esp/Distance/Size", {Text="Size", Min=10, Max=32, Default=12, Rounding=0})
DistGb:AddSlider("player_esp/Distance/Transparency", {Text="Transparency", Min=0, Max=1, Default=0.0, Rounding=2})

local WeapGb = EspTab:AddLeftGroupbox("Weapon Text")
WeapGb:AddToggle("player_esp/Weapon/Enabled", {Text="Enabled", Default=false})
WeapGb:AddToggle("player_esp/Weapon/Outline", {Text="Outline", Default=true})
WeapGb:AddToggle("player_esp/Weapon/Autoscale", {Text="Autoscale", Default=true})
WeapGb:AddSlider("player_esp/Weapon/Size", {Text="Size", Min=10, Max=32, Default=12, Rounding=0})
WeapGb:AddSlider("player_esp/Weapon/Transparency", {Text="Transparency", Min=0, Max=1, Default=0.0, Rounding=2})

Testhook.Main.settings_section(Window, "RightShift", false)
Testhook.Main.init_auto_load(Window)
Testhook.Main.init_watermark()
Testhook.Main.setup_lighting(Options)

if Testhook.Drawing then
    --Testhook.Drawing.SetupCursor(Window)
    Testhook.Drawing.SetupCrosshair(Options)
    Testhook.Drawing.SetupFOV("aimbot", Options)
    Testhook.Drawing.SetupFOV("silent", Options)
    Testhook.Drawing.SetupFOV("trigger", Options)
end

local old_index
old_index = hookmetamethod(game, "__index", function(self, idx)
    if checkcaller() then return old_index(self, idx) end
    if silent_aim_target and math.random(100) <= (Options.silent_hitchance and Options.silent_hitchance.Value or 100) then
        local modes = Options.silent_modes and Options.silent_modes.Value or {}
        if self == Mouse then
            if idx == "Target" and modes["Target"] then
                return silent_aim_target[3]
            elseif idx == "Hit" and modes["Hit"] then
                return silent_aim_target[3].CFrame
            end
        end
    end
    return old_index(self, idx)
end)

local old_namecall
old_namecall = hookmetamethod(game, "__namecall", function(self, ...)
    if checkcaller() then return old_namecall(self, ...) end
    if silent_aim_target and math.random(100) <= (Options.silent_hitchance and Options.silent_hitchance.Value or 100) then
        local args = {...}
        local method = getnamecallmethod()
        local modes = Options.silent_modes and Options.silent_modes.Value or {}

        if self == Workspace then
            if method == "Raycast" and modes["Raycast"] then
                args[2] = silent_aim_target[3].Position - args[1]
                return old_namecall(self, unpack(args))
            elseif (method == "FindPartOnRayWithIgnoreList" and modes["FindPartOnRayWithIgnoreList"])
                or (method == "FindPartOnRayWithWhitelist" and modes["FindPartOnRayWithWhitelist"])
                or (method == "FindPartOnRay" and modes["FindPartOnRay"]) then
                args[1] = Ray.new(args[1].Origin, silent_aim_target[3].Position - args[1].Origin)
                return old_namecall(self, unpack(args))
            end
        elseif self == Camera then
            if (method == "ScreenPointToRay" and modes["ScreenPointToRay"])
                or (method == "ViewportPointToRay" and modes["ViewportPointToRay"]) then
                return Ray.new(silent_aim_target[3].Position, silent_aim_target[3].Position - Camera.CFrame.Position)
            elseif (method == "WorldToScreenPoint" and modes["WorldToScreenPoint"])
                or (method == "WorldToViewportPoint" and modes["WorldToViewportPoint"]) then
                args[1] = silent_aim_target[3].Position
                return old_namecall(self, unpack(args))
            end
        end
    end
    return old_namecall(self, ...)
end)

Testhook.Main.new_thread_loop(0, function()
    if not (aimbot_down or (Toggles.aimbot_always and Toggles.aimbot_always.Value)) then return end
    local tgt = find_target(
        Toggles.aimbot_enabled and Toggles.aimbot_enabled.Value,
        Toggles.aimbot_team and Toggles.aimbot_team.Value,
        Toggles.aimbot_vis and Toggles.aimbot_vis.Value,
        Toggles.aimbot_dist and Toggles.aimbot_dist.Value,
        Options.aimbot_distlim.Value,
        Options.aimbot_fov.Value,
        Options.aimbot_prio.Value,
        Options.aimbot_parts.Value,
        Toggles.aimbot_pred and Toggles.aimbot_pred.Value
    )
    aim_at(tgt, (Options.aimbot_sens.Value or 20) / 100)
end)

Testhook.Main.new_thread_loop(0, function()
    silent_aim_target = find_target(
        Toggles.silent_on and Toggles.silent_on.Value,
        Toggles.silent_team and Toggles.silent_team.Value,
        Toggles.silent_vis and Toggles.silent_vis.Value,
        Toggles.silent_dist and Toggles.silent_dist.Value,
        Options.silent_distlim.Value,
        Options.silent_fov.Value,
        Options.silent_prio.Value,
        Options.silent_parts.Value,
        Toggles.silent_pred and Toggles.silent_pred.Value
    )
end)

Testhook.Main.new_thread_loop(0, function()
    if not (trigger_down or (Toggles.trigger_always and Toggles.trigger_always.Value)) then return end
    if not isrbxactive() then return end

    local tgt = find_target(
        Toggles.trigger_on and Toggles.trigger_on.Value,
        Toggles.trigger_team and Toggles.trigger_team.Value,
        Toggles.trigger_vis and Toggles.trigger_vis.Value,
        Toggles.trigger_dist and Toggles.trigger_dist.Value,
        Options.trigger_distlim.Value,
        Options.trigger_fov.Value,
        Options.trigger_prio.Value,
        Options.trigger_parts.Value,
        Toggles.trigger_pred and Toggles.trigger_pred.Value
    )
    if not tgt then return end

    task.wait(Options.trigger_delay.Value or 0)
    mouse1press()

    if Toggles.trigger_hold and Toggles.trigger_hold.Value then
        while task.wait() do
            if not (trigger_down and Toggles.trigger_on and Toggles.trigger_on.Value) then break end
            tgt = find_target(
                Toggles.trigger_on.Value,
                Toggles.trigger_team.Value,
                Toggles.trigger_vis.Value,
                Toggles.trigger_dist.Value,
                Options.trigger_distlim.Value,
                Options.trigger_fov.Value,
                Options.trigger_prio.Value,
                Options.trigger_parts.Value,
                Toggles.trigger_pred.Value
            )
            if not tgt then break end
        end
    end

    mouse1release()
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

for _, p in ipairs(PlayerService:GetPlayers()) do
    if p ~= LocalPlayer then
        Testhook.Main.create_esp(p, "Player", "player_esp")
    end
end

PlayerService.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        Testhook.Main.create_esp(p, "Player", "player_esp")
    end
end)

PlayerService.PlayerRemoving:Connect(function(p)
    Testhook.Main.remove_esp(p)
end)
