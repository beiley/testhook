local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")

local Main = { default_lighting = {} }

local Camera = Workspace.CurrentCamera
local LocalPlayer = PlayerService.LocalPlayer
local Request = request or (http and http.request)
local SetIdentity = setthreadidentity

do 
    local OldPluginManager, Message = nil, nil

    task.spawn(function()
        SetIdentity(2)
        local Success, Error = pcall(getrenv().PluginManager)
        Message = Error
    end)

    OldPluginManager = hookfunction(getrenv().PluginManager, function()
        return error(Message)
    end)
end

repeat task.wait() until Stats.Network:FindFirstChild("ServerStatsItem")
local Ping = Stats.Network.ServerStatsItem["Data Ping"]

repeat task.wait() until Workspace:FindFirstChildOfClass("Terrain")
local Terrain = Workspace:FindFirstChildOfClass("Terrain")

local XZVector, YVector = Vector3.new(1, 0, 1), Vector3.new(0, 1, 0)
local Movement = { Forward = 0, Backward = 0, Right = 0, Left = 0, Up = 0, Down = 0 }

local function get_flat_vector(CF) 
    return CF.LookVector * XZVector, CF.RightVector * XZVector 
end

local function get_unit(Vector) 
    if Vector.Magnitude == 0 then return Vector end 
    return Vector.Unit 
end

local function movement_bind(ActionName, InputState)
    Movement[ActionName] = InputState == Enum.UserInputState.Begin and 1 or 0
    return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("Forward", movement_bind, false, Enum.KeyCode.W)
ContextActionService:BindAction("Backward", movement_bind, false, Enum.KeyCode.S)
ContextActionService:BindAction("Left", movement_bind, false, Enum.KeyCode.A)
ContextActionService:BindAction("Right", movement_bind, false, Enum.KeyCode.D)
ContextActionService:BindAction("Up", movement_bind, false, Enum.KeyCode.Space)
ContextActionService:BindAction("Down", movement_bind, false, Enum.KeyCode.LeftShift)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

function Main.setup_fps()
    local start_time, time_table, last_time = os.clock(), {}, nil

    return function()
        last_time = os.clock()

        for Index = #time_table, 1, -1 do
            time_table[Index + 1] = time_table[Index] >= last_time - 1 and time_table[Index] or nil
        end

        time_table[1] = last_time
        return os.clock() - start_time >= 1 and #time_table or #time_table / (os.clock() - start_time)
    end
end

function Main.movement_to_direction()
    local look_vector, right_vector = get_flat_vector(Camera.CFrame)
    local z_movement = look_vector * (Movement.Forward - Movement.Backward)
    local x_movement = right_vector * (Movement.Right - Movement.Left)
    local y_movement = YVector * (Movement.Up - Movement.Down)

    return get_unit(z_movement + x_movement + y_movement)
end

function Main.make_beam(origin, position, color)
    local origin_attachment = Instance.new("Attachment")
    origin_attachment.CFrame = CFrame.new(origin)
    origin_attachment.Name = "OriginAttachment"
    origin_attachment.Parent = Terrain

    local position_attachment = Instance.new("Attachment")
    position_attachment.CFrame = CFrame.new(position)
    position_attachment.Name = "PositionAttachment"
    position_attachment.Parent = Terrain

    local beam = Instance.new("Beam")
    beam.Name = "Beam"
    beam.Color = ColorSequence.new(color)
    beam.LightEmission = 1
    beam.LightInfluence = 1
    beam.TextureMode = Enum.TextureMode.Static
    beam.TextureSpeed = 0
    beam.Transparency = NumberSequence.new(0)
    beam.Attachment0 = origin_attachment
    beam.Attachment1 = position_attachment
    beam.FaceCamera = true
    beam.Segments = 1
    beam.Width0 = 0.1
    beam.Width1 = 0.1
    beam.Parent = Terrain

    task.spawn(function()
        local time = 1 * 60
        for index = 1, time do
            RunService.Heartbeat:Wait()
            beam.Transparency = NumberSequence.new(index / time)
        end
        origin_attachment:Destroy()
        position_attachment:Destroy()
        beam:Destroy()
    end)

    return beam
end

function Main.new_thread_loop(wait_time, func)
    task.spawn(function()
        while true do
            local delta = task.wait(wait_time)
            local success, error = pcall(func, delta)
            if not success then
                warn("thread error " .. error)
            elseif error == "break" then
                break
            end
        end
    end)
end

function Main.fix_up_value(fn, hook, gvar)
    if gvar then
        old = hookfunction(fn, function(...)
            return hook(old, ...)
        end)
    else
        local old = nil
        old = hookfunction(fn, function(...)
            return hook(old, ...)
        end)
    end
end

function Main.rejoin()
    if #PlayerService:GetPlayers() <= 1 then
        LocalPlayer:Kick("\nTesthook\nRejoining...")
        task.wait(0.5)
        TeleportService:Teleport(game.PlaceId)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
    end
end

function Main.server_hop()
    local data_decoded, servers = HttpService:JSONDecode(game:HttpGet(
        "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/0?sortOrder=2&excludeFullGames=true&limit=100"
    )).data, {}

    for index, server_data in ipairs(data_decoded) do
        if type(server_data) == "table" and server_data.id ~= game.JobId then
            table.insert(servers, server_data.id)
        end
    end

    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(
            game.PlaceId, servers[math.random(#servers)]
        )
    else
        Testhook.Library:Notify("Couldn't find a server", 5)
    end
end

function Main.join_discord()
    Request({
        ["Url"] = "http://localhost:6463/rpc?v=1",
        ["Method"] = "POST",
        ["Headers"] = {
            ["Content-Type"] = "application/json",
            ["Origin"] = "https://discord.com"
        },
        ["Body"] = HttpService:JSONEncode({
            ["cmd"] = "INVITE_BROWSER",
            ["nonce"] = string.lower(HttpService:GenerateGUID(false)),
            ["args"] = {
                ["code"] = "sYqDpbPYb7"
            }
        })
    })
end

function Main.init_auto_load(window)
    if window.AutoLoadConfig then
        window:AutoLoadConfig("Testhook")
    end
    if window.SetValue then
        window:SetValue("UI/Enabled", Toggles["UI/OOL"] and Toggles["UI/OOL"].Value or true)
    end
end

function Main.setup_watermark(window)
    local get_fps = Main.setup_fps()
    
    RunService.Heartbeat:Connect(function()
        if Testhook.Library.Watermark and Testhook.Library.Watermark.Visible then
            local watermark_text = string.format(
                "Testhook    %s    %i FPS    %i MS",
                os.date("%X"), get_fps(), math.round(Ping:GetValue())
            )
            Testhook.Library:SetWatermark(watermark_text)
        end
    end)
end

function Main.get_backgrounds()
    return {
        {"None", "", false},
        {"Legacy", "rbxassetid://2151741365", false},
        {"Hearts", "rbxassetid://6073763717", false},
        {"Abstract", "rbxassetid://6073743871", false},
        {"Hexagon", "rbxassetid://6073628839", false},
        {"Geometric", "rbxassetid://2062021684", false},
        {"Circles", "rbxassetid://6071579801", false},
        {"Checkered", "rbxassetid://4806196507", false},
        {"Lace With Flowers", "rbxassetid://6071575925", false},
        {"Flowers & Leafs", "rbxassetid://10921866694", false},
        {"Floral", "rbxassetid://5553946656", true},
        {"Leafs", "rbxassetid://10921868665", false},
        {"Mountains", "rbxassetid://10921801398", false},
        {"Halloween", "rbxassetid://11113209821", false},
        {"Christmas", "rbxassetid://11711560928", false},
        {"Polka Dots", "rbxassetid://6214418014", false},
        {"Mountains", "rbxassetid://6214412460", false},
        {"Zigzag", "rbxassetid://6214416834", false},
        {"Zigzag 2", "rbxassetid://6214375242", false},
        {"Tartan", "rbxassetid://6214404863", false},
        {"Roses", "rbxassetid://6214374619", false},
        {"Hexagons", "rbxassetid://6214320051", false},
        {"Leopard Print", "rbxassetid://6214318622", false},
        {"Blue Cubes", "rbxassetid://7188838187", false},
        {"Blue Waves", "rbxassetid://10952910471", false},
        {"White Circles", "rbxassetid://5168924660", false},
        {"Animal Print", "rbxassetid://6299360527", false},
        {"Fur", "rbxassetid://990886896", false},
        {"Marble", "rbxassetid://8904067198", false},
        {"Touhou", "rbxassetid://646426813", false},
    }
end

function Main.settings_section(window, ui_keybind, custom_mouse)
    local backgrounds = Main.get_backgrounds()
    local backgrounds_list = {}
    
    for index, data in pairs(backgrounds) do
        table.insert(backgrounds_list, data[1])
    end

    local options_tab = window:AddTab("Options")
    local menu_box = options_tab:AddLeftGroupbox("Menu") 
    
    local ui_toggle = menu_box:AddToggle("UI_Enabled", {
        Text = "UI Enabled",
        Default = true,
        Callback = function(value)
            window:SetEnabled(value)
        end
    })
    
    if ui_keybind then
        ui_toggle:AddKeyPicker("UI_Keybind", {
            Default = ui_keybind,
            Text = "UI Toggle",
            Mode = "Toggle",
        })
    end

    menu_box:AddColorPicker("UI_Color", {
        Title = "UI Color",
        Default = Color3.fromRGB(0, 85, 255),
        Callback = function(value)
            if Testhook.Library then
                Testhook.Library.AccentColor = value
                Testhook.Library:UpdateColorsUsingRegistry()
            end
        end
    })

    menu_box:AddToggle("UI_Watermark", {
        Text = "Watermark",
        Default = true,
        Callback = function(value)
            if Testhook.Library then
                Testhook.Library:SetWatermarkVisibility(value)
            end
        end
    })

    menu_box:AddToggle("UI_Keybinds", {
        Text = "Keybind List",
        Default = false,
        Callback = function(value)
            if Testhook.Library.KeybindFrame then
                Testhook.Library.KeybindFrame.Visible = value
            end
        end
    })

    if custom_mouse ~= nil then
        menu_box:AddToggle("Mouse_Enabled", {
            Text = "Custom Mouse",
            Default = custom_mouse
        })
    end

    menu_box:AddDivider()
    menu_box:AddButton("Rejoin", Main.rejoin)
    menu_box:AddButton("Server Hop", Main.server_hop)
    menu_box:AddButton("Copy Lua Invite", function()
        setclipboard("game:GetService(\"TeleportService\"):TeleportToPlaceInstance(" .. game.PlaceId .. ", \"" .. game.JobId .. "\")")
        Testhook.Library:Notify("Copied Lua invite to clipboard!", 3)
    end)
    menu_box:AddButton("Copy JS Invite", function()
        setclipboard("Roblox.GameLauncher.joinGameInstance(" .. game.PlaceId .. ", \"" .. game.JobId .. "\");")
        Testhook.Library:Notify("Copied JS invite to clipboard!", 3)
    end)

    local background_box = options_tab:AddRightGroupbox("Background")
    
    if window.BackgroundFrame then
        background_box:AddColorPicker("Background_Color", {
            Title = "Background Color",
            Default = Color3.new(1, 1, 1),
            Transparency = 0,
            Callback = function(value, transparency)
                window.BackgroundFrame.ImageColor3 = value
                window.BackgroundFrame.ImageTransparency = transparency
            end
        })
    end

    background_box:AddDropdown("Background_Image", {
        Text = "Background Image",
        Values = backgrounds_list,
        Default = 1,
        Callback = function(value)
            if window.BackgroundFrame then
                for _, data in pairs(backgrounds) do
                    if data[1] == value then
                        window.BackgroundFrame.Image = data[2]
                        break
                    end
                end
            end
        end
    })

    local crosshair_box = options_tab:AddRightGroupbox("Crosshair")
    
    local crosshair_toggle = crosshair_box:AddToggle("Crosshair_Enabled", {
        Text = "Enabled",
        Default = false
    })

    crosshair_toggle:AddColorPicker("Crosshair_Color", {
        Title = "Color",
        Default = Color3.new(1, 1, 1)
    })

    crosshair_box:AddSlider("Crosshair_Size", {
        Text = "Size",
        Min = 0,
        Max = 20,
        Default = 4,
        Rounding = 0,
        Suffix = "px"
    })

    crosshair_box:AddSlider("Crosshair_Gap", {
        Text = "Gap", 
        Min = 0,
        Max = 10,
        Default = 2,
        Rounding = 0,
        Suffix = "px"
    })

    local discord_box = options_tab:AddRightGroupbox("Discord")
    discord_box:AddLabel("Invite Code: sYqDpbPYb7")
    discord_box:AddButton("Copy Invite Link", function()
        setclipboard("https://discord.gg/sYqDpbPYb7")
        Testhook.Library:Notify("Copied Discord invite!", 3)
    end)
    discord_box:AddButton("Join Through Discord App", Main.join_discord)

    local credits_box = options_tab:AddRightGroupbox("Credits")
    credits_box:AddLabel("Made by W6ze")
    credits_box:AddDivider()
    credits_box:AddLabel("Special thanks to:")
    credits_box:AddLabel("s1... hes the homie")
    credits_box:AddLabel("m4chris - the goat") 
    credits_box:AddLabel("❤️ Contributors ❤️")

    return options_tab
end

function Main.esp_section(window, name, flag, box_enabled, tracer_enabled, head_enabled, oov_enabled, lighting_enabled)
    local visuals_tab = window:AddTab(name)
    local global_section = visuals_tab:AddLeftGroupbox("Global")
    
    global_section:AddToggle(flag .. "_team_check", {
        Text = "Team Check",
        Default = false
    })

    global_section:AddToggle(flag .. "_distance_check", {
        Text = "Distance Check",
        Default = false
    })

    global_section:AddSlider(flag .. "_distance", {
        Text = "Max Distance",
        Min = 50,
        Max = 5000,
        Default = 1000,
        Rounding = 0,
        Suffix = " studs"
    })

    global_section:AddColorPicker(flag .. "_enemy", {
        Title = "Enemy Color",
        Default = Color3.fromRGB(255, 100, 100)
    })

    global_section:AddColorPicker(flag .. "_ally", {
        Title = "Ally Color", 
        Default = Color3.fromRGB(100, 255, 100)
    })

    global_section:AddToggle(flag .. "_team_color", {
        Text = "Use Team Colors",
        Default = false
    })

    if box_enabled then
        local box_section = visuals_tab:AddLeftGroupbox("Boxes")
        
        box_section:AddToggle(flag .. "_box_enabled", {
            Text = "Box Enabled",
            Default = false
        })

        box_section:AddToggle(flag .. "_box_filled", {
            Text = "Filled",
            Default = false
        })

        box_section:AddToggle(flag .. "_box_outline", {
            Text = "Outline",
            Default = true
        })

        box_section:AddSlider(flag .. "_box_thickness", {
            Text = "Thickness",
            Min = 1,
            Max = 10,
            Default = 1,
            Rounding = 0
        })

        box_section:AddSlider(flag .. "_box_transparency", {
            Text = "Transparency",
            Min = 0,
            Max = 1,
            Default = 0,
            Rounding = 2
        })

        box_section:AddSlider(flag .. "_box_corner_size", {
            Text = "Corner Size",
            Min = 10,
            Max = 100,
            Default = 50,
            Rounding = 0,
            Suffix = "%"
        })

        box_section:AddToggle(flag .. "_box_health_bar", {
            Text = "Health Bar",
            Default = false
        })

        box_section:AddDivider()

        box_section:AddToggle(flag .. "_name_enabled", {
            Text = "Name",
            Default = false
        })

        box_section:AddToggle(flag .. "_health_enabled", {
            Text = "Health",
            Default = false
        })

        box_section:AddToggle(flag .. "_distance_enabled", {
            Text = "Distance",
            Default = false
        })

        box_section:AddToggle(flag .. "_weapon_enabled", {
            Text = "Weapon", 
            Default = false
        })

        box_section:AddToggle(flag .. "_name_outline", {
            Text = "Text Outline",
            Default = true
        })

        box_section:AddToggle(flag .. "_name_autoscale", {
            Text = "Text Autoscale",
            Default = true
        })

        box_section:AddSlider(flag .. "_name_size", {
            Text = "Text Size",
            Min = 1,
            Max = 100,
            Default = 8,
            Rounding = 0
        })

        box_section:AddSlider(flag .. "_name_transparency", {
            Text = "Text Transparency",
            Min = 0,
            Max = 1,
            Default = 0.25,
            Rounding = 2
        })
    end

    if head_enabled then
        local head_section = visuals_tab:AddRightGroupbox("Head Dots")
        
        head_section:AddToggle(flag .. "_head_dot_enabled", {
            Text = "Enabled",
            Default = false
        })

        head_section:AddToggle(flag .. "_head_dot_filled", {
            Text = "Filled",
            Default = true
        })

        head_section:AddToggle(flag .. "_head_dot_outline", {
            Text = "Outline",
            Default = true
        })

        head_section:AddToggle(flag .. "_head_dot_autoscale", {
            Text = "Autoscale",
            Default = true
        })

        head_section:AddSlider(flag .. "_head_dot_radius", {
            Text = "Size",
            Min = 1,
            Max = 100,
            Default = 4,
            Rounding = 0
        })

        head_section:AddSlider(flag .. "_head_dot_num_sides", {
            Text = "Num Sides",
            Min = 3,
            Max = 100,
            Default = 4,
            Rounding = 0
        })

        head_section:AddSlider(flag .. "_head_dot_thickness", {
            Text = "Thickness",
            Min = 1,
            Max = 10,
            Default = 1,
            Rounding = 0
        })

        head_section:AddSlider(flag .. "_head_dot_transparency", {
            Text = "Transparency", 
            Min = 0,
            Max = 1,
            Default = 0,
            Rounding = 2
        })
    end

    if tracer_enabled then
        local tracer_section = visuals_tab:AddRightGroupbox("Tracers")
        
        tracer_section:AddToggle(flag .. "_tracer_enabled", {
            Text = "Enabled",
            Default = false
        })

        tracer_section:AddToggle(flag .. "_tracer_outline", {
            Text = "Outline",
            Default = true
        })

        tracer_section:AddDropdown(flag .. "_tracer_mode", {
            Text = "Mode",
            Values = {"From Bottom", "From Mouse"},
            Default = 1
        })

        tracer_section:AddSlider(flag .. "_tracer_thickness", {
            Text = "Thickness",
            Min = 1,
            Max = 10,
            Default = 1,
            Rounding = 0
        })

        tracer_section:AddSlider(flag .. "_tracer_transparency", {
            Text = "Transparency",
            Min = 0,
            Max = 1,
            Default = 0,
            Rounding = 2
        })
    end

    if oov_enabled then
        local oov_section = visuals_tab:AddRightGroupbox("Offscreen Arrows")
        
        oov_section:AddToggle(flag .. "_arrow_enabled", {
            Text = "Enabled",
            Default = false
        })

        oov_section:AddToggle(flag .. "_arrow_filled", {
            Text = "Filled",
            Default = true
        })

        oov_section:AddToggle(flag .. "_arrow_outline", {
            Text = "Outline",
            Default = true
        })

        oov_section:AddSlider(flag .. "_arrow_width", {
            Text = "Width",
            Min = 14,
            Max = 28,
            Default = 14,
            Rounding = 0
        })

        oov_section:AddSlider(flag .. "_arrow_height", {
            Text = "Height",
            Min = 14,
            Max = 28,
            Default = 28,
            Rounding = 0
        })

        oov_section:AddSlider(flag .. "_arrow_radius", {
            Text = "Distance From Center",
            Min = 80,
            Max = 200,
            Default = 150,
            Rounding = 0
        })

        oov_section:AddSlider(flag .. "_arrow_thickness", {
            Text = "Thickness",
            Min = 1,
            Max = 10,
            Default = 1,
            Rounding = 0
        })

        oov_section:AddSlider(flag .. "_arrow_transparency", {
            Text = "Transparency",
            Min = 0,
            Max = 1,
            Default = 0,
            Rounding = 2
        })
    end

    if lighting_enabled then
        Main:lighting_section(visuals_tab, "Right")
    end

    return global_section
end

function Main.lighting_section(self, tab, side)
    side = side or "Right"
    local lighting_section = tab:AddGroupbox("Lighting", side)
    
    lighting_section:AddToggle("lighting_enabled", {
        Text = "Enabled",
        Default = false,
        Callback = function(value) 
            if not value then
                for property, val in pairs(self.default_lighting) do
                    Lighting[property] = val
                end
            end
        end
    })

    lighting_section:AddColorPicker("lighting_ambient", {
        Title = "Ambient",
        Default = Color3.new(1, 0, 1)
    })

    lighting_section:AddSlider("lighting_brightness", {
        Text = "Brightness",
        Min = 0,
        Max = 10,
        Default = 3,
        Rounding = 2
    })

    lighting_section:AddSlider("lighting_clock_time", {
        Text = "Clock Time",
        Min = 0,
        Max = 24,
        Default = 12,
        Rounding = 2
    })

    lighting_section:AddColorPicker("lighting_color_shift_bottom", {
        Title = "ColorShift Bottom",
        Default = Color3.new(1, 0, 1)
    })

    lighting_section:AddColorPicker("lighting_color_shift_top", {
        Title = "ColorShift Top", 
        Default = Color3.new(1, 0, 1)
    })

    lighting_section:AddSlider("lighting_environment_diffuse_scale", {
        Text = "Environment Diffuse Scale",
        Min = 0,
        Max = 1,
        Default = 0,
        Rounding = 3
    })

    lighting_section:AddSlider("lighting_environment_specular_scale", {
        Text = "Environment Specular Scale",
        Min = 0,
        Max = 1,
        Default = 0,
        Rounding = 3
    })

    lighting_section:AddSlider("lighting_exposure_compensation", {
        Text = "Exposure Compensation",
        Min = -3,
        Max = 3,
        Default = 0,
        Rounding = 2
    })

    lighting_section:AddColorPicker("lighting_fog_color", {
        Title = "Fog Color",
        Default = Color3.new(1, 0, 1)
    })

    lighting_section:AddSlider("lighting_fog_end", {
        Text = "Fog End",
        Min = 0,
        Max = 100000,
        Default = 100000,
        Rounding = 0
    })

    lighting_section:AddSlider("lighting_fog_start", {
        Text = "Fog Start",
        Min = 0,
        Max = 100000,
        Default = 0,
        Rounding = 0
    })

    lighting_section:AddSlider("lighting_geographic_latitude", {
        Text = "Geographic Latitude",
        Min = 0,
        Max = 360,
        Default = 23.5,
        Rounding = 1
    })

    lighting_section:AddToggle("lighting_global_shadows", {
        Text = "Global Shadows",
        Default = false
    })

    lighting_section:AddColorPicker("lighting_outdoor_ambient", {
        Title = "Outdoor Ambient",
        Default = Color3.new(1, 0, 1)
    })

    lighting_section:AddSlider("lighting_shadow_softness", {
        Text = "Shadow Softness",
        Min = 0,
        Max = 1,
        Default = 0,
        Rounding = 2
    })

    lighting_section:AddToggle("terrain_decoration", {
        Text = "Terrain Decoration",
        Default = gethiddenproperty(Terrain, "Decoration"),
        Callback = function(value) 
            sethiddenproperty(Terrain, "Decoration", value) 
        end
    })
end

function Main.setup_lighting(self, flags)
    self.default_lighting = {
        Ambient = Lighting.Ambient,
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        ColorShift_Top = Lighting.ColorShift_Top,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
        ExposureCompensation = Lighting.ExposureCompensation,
        FogColor = Lighting.FogColor,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        GeographicLatitude = Lighting.GeographicLatitude,
        GlobalShadows = Lighting.GlobalShadows,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ShadowSoftness = Lighting.ShadowSoftness
    }

    Lighting.Changed:Connect(function(property)
        if property == "TimeOfDay" then return end 
        local value = nil
        if not pcall(function() value = Lighting[property] end) then return end
        local custom_value, formated_value = Options["lighting_" .. string.lower(property)], value
        local default_value = self.default_lighting[property]

        if custom_value and custom_value.Value then
            custom_value = custom_value.Value
        end

        if type(formated_value) == "number" then
            if property == "EnvironmentSpecularScale" or property == "EnvironmentDiffuseScale" then
                formated_value = tonumber(string.format("%.3f", formated_value))
            else
                formated_value = tonumber(string.format("%.2f", formated_value))
            end
        end

        if custom_value ~= formated_value and value ~= default_value then
            self.default_lighting[property] = value
        end
    end)

    RunService.Heartbeat:Connect(function()
        if Options["lighting_enabled"] and Options["lighting_enabled"].Value then
            for property in pairs(self.default_lighting) do
                local custom_option = Options["lighting_" .. string.lower(property)]
                if custom_option then
                    local custom_value = custom_option.Value
                    if type(custom_value) == "table" and custom_value.Color then
                        custom_value = custom_value.Color
                    end
                    if Lighting[property] ~= custom_value then
                        Lighting[property] = custom_value
                    end
                end
            end
        end
    end)
end

function Main.setup_crosshair()
    if Testhook.Drawing and Testhook.Drawing.SetupCrosshair then
        Testhook.Drawing.SetupCrosshair(Options)
    end
end

function Main.init_watermark()
    if Testhook.Library then
        Main.setup_watermark(Testhook.Library)
    end
end

function Main.get_flag(flag)
    if Options[flag] then
        return Options[flag].Value
    end
    if Toggles[flag] then
        return Toggles[flag].Value
    end
    return nil
end

function Main.make_beam_with_flag(origin, position, color_flag)
    local color = Main.get_flag(color_flag)
    if color and typeof(color) == "Color3" then
        return Main.make_beam(origin, position, color)
    else
        return Main.make_beam(origin, position, Color3.new(1, 1, 1))
    end
end

function Main.create_esp(target, mode, flag)
    if Testhook.Drawing then
        Testhook.Drawing:AddESP(target, mode, flag, Options)
    end
end

function Main.remove_esp(target)
    if Testhook.Drawing then
        Testhook.Drawing:RemoveESP(target)
    end
end

function Main.add_object_esp(obj, name, position, global_flag, flag)
    if Testhook.Drawing then
        Testhook.Drawing:AddObject(obj, name, position, global_flag, flag, Options)
    end
end

function Main.remove_object_esp(obj)
    if Testhook.Drawing then
        Testhook.Drawing:RemoveObject(obj)
    end
end

function Main.initialize(window, ui_keybind, custom_mouse)
    Main:setup_lighting(Options)
    Main.init_watermark()
    Main.setup_crosshair()
    Main.settings_section(window, ui_keybind, custom_mouse)
    
    if Testhook.Drawing and Testhook.Drawing.SetupCursor then
        Testhook.Drawing.SetupCursor(window)
    end
    
    return Main
end

function Main.predict_movement(origin, target_position, target_velocity, projectile_speed, gravity)
    if Testhook.Physics then
        return Testhook.Physics.SolveTrajectory(
            origin, 
            target_position, 
            target_velocity, 
            projectile_speed, 
            gravity
        )
    end
    return target_position
end

function Main.notify(message, duration)
    if Testhook.Library then
        Testhook.Library:Notify(message, duration or 5)
    else
        warn("Testhook Notification: " .. message)
    end
end

return Main
