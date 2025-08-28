local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local Workspace = game:GetService("Workspace")

repeat task.wait() until PlayerService.LocalPlayer
local LocalPlayer = PlayerService.LocalPlayer
local Camera = Workspace.CurrentCamera

local V2 = Vector2.new
local V3 = Vector3.new
local CF = CFrame.new
local rad = math.rad
local tan = math.tan
local floor = math.floor
local clamp = math.clamp
local cos = math.cos
local sin = math.sin
local abs = math.abs
local sqrt = math.sqrt
local clear = table.clear

local Fonts = Drawing.Fonts
local Color3_new = Color3.new
local White = Color3_new(1,1,1)
local Red = Color3_new(1,0,0)
local Yellow = Color3_new(1,1,0)
local Green = Color3_new(0,1,0)

local function add_drawing(t, props)
    local o = Drawing.new(t)
    if props then
        for k,v in pairs(props) do o[k] = v end
    end
    return o
end
local function clear_drawing(tbl)
    for _,v in pairs(tbl) do
        if type(v) == "table" then
            clear_drawing(v)
        elseif typeof(v) == "DrawingObject" then
            v:Destroy()
        end
    end
end

local function get_flag(flags, flag, opt)
    return flags[flag .. opt]
end

local fov_half_tan = tan(rad(Camera.FieldOfView * 0.5))
local function update_fov_cache()
    fov_half_tan = tan(rad(Camera.FieldOfView * 0.5))
end
Camera:GetPropertyChangedSignal("FieldOfView"):Connect(update_fov_cache)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
    update_fov_cache()
end)

local function world_to_screen(p3)
    local v,p = Camera:WorldToViewportPoint(p3)
    return V2(v.X,v.Y), p
end
local function anti_alias_xy(x,y)
    return V2(floor(x), floor(y))
end
local function anti_alias_v2(v)
    return V2(floor(v.X), floor(v.Y))
end
local function get_distance(wp)
    return (wp - Camera.CFrame.Position).Magnitude
end
local function in_range(enabled, limit, dist)
    if not enabled then return true end
    return dist < limit
end
local function scale_factor(enabled, base, dist)
    if not enabled then return base end
    local denom = dist * fov_half_tan * 2
    if denom <= 0 then return base end
    return math.max(1, base / denom * 1000)
end
local function eval_health(t)
    if t <= 0 then return Red end
    if t >= 1 then return Green end
    if t < 0.5 then
        return Red:Lerp(Yellow, t/0.5)
    else
        return Yellow:Lerp(Green, (t-0.5)/0.5)
    end
end
local function calc_box_size(model, dist)
    local size = model:GetExtentsSize()
    local denom = dist * fov_half_tan * 2
    local v = size / denom * 1000
    return anti_alias_xy(v.X, v.Y)
end
local function relative_screen_center(dir2)
    return Camera.ViewportSize/2 - dir2
end
local function cf_object_space(cf, p)
    local r = cf:PointToObjectSpace(p)
    return V2(-r.X, -r.Z)
end
local function rotate_v2(v, r)
    local c,s = cos(r), sin(r)
    return V2(v.X*c - v.Y*s, v.X*s + v.Y*c)
end

local function get_character_generic(target, mode)
    if mode == "Player" then
        local ch = target.Character
        if not ch then return end
        return ch, ch:FindFirstChild("HumanoidRootPart")
    else
        return target, target:FindFirstChild("HumanoidRootPart")
    end
end
local function get_health_generic(_, character)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return 100, 100, true end
    return hum.Health, hum.MaxHealth, hum.Health > 0
end
local function get_team_generic(target, _, mode)
    if mode == "Player" then
        if target.Neutral then return true, White end
        return LocalPlayer.Team ~= target.Team, target.TeamColor.Color
    end
    return true, White
end
local function get_weapon_generic()
    return "N/A"
end

local GetCharacter = get_character_generic
local GetHealth = get_health_generic
local GetTeam = get_team_generic
local GetWeapon = get_weapon_generic

local Drawing = {
    ESP = {},
    ObjectESP = {},
    CharacterSize = V3(4,5,1)
}

function Drawing.AddObject(self, obj, obj_name, obj_pos, global_flag, flag, flags)
    if self.ObjectESP[obj] then return end
    local is_part = typeof(obj_pos) ~= "Vector3"
    local d = {
        Target = { Name = obj_name, Position = obj_pos },
        Flag = flag, GlobalFlag = global_flag, Flags = flags,
        IsBasePart = is_part,
        Name = add_drawing("Text", {Visible=false,ZIndex=0,Center=true,Outline=true,Color=White,Font=Fonts.Plex})
    }
    if is_part then
        d.Target.RootPart = obj_pos
        d.Target.Position = obj_pos.Position
    end
    self.ObjectESP[obj] = d
end

function Drawing.RemoveObject(self, obj)
    local esp = self.ObjectESP[obj]
    if not esp then return end
    esp.Name:Destroy()
    clear(self.ObjectESP[obj])
    self.ObjectESP[obj] = nil
end

local function new_box_draws()
    return {
        Visible=false, OutlineVisible=false,
        LineLT={ Main=add_drawing("Line",{Visible=false,ZIndex=1}), Outline=add_drawing("Line",{Visible=false,ZIndex=0}) },
        LineTL={ Main=add_drawing("Line",{Visible=false,ZIndex=1}), Outline=add_drawing("Line",{Visible=false,ZIndex=0}) },
        LineLB={ Main=add_drawing("Line",{Visible=false,ZIndex=1}), Outline=add_drawing("Line",{Visible=false,ZIndex=0}) },
        LineBL={ Main=add_drawing("Line",{Visible=false,ZIndex=1}), Outline=add_drawing("Line",{Visible=false,ZIndex=0}) },
        LineRT={ Main=add_drawing("Line",{Visible=false,ZIndex=1}), Outline=add_drawing("Line",{Visible=false,ZIndex=0}) },
        LineTR={ Main=add_drawing("Line",{Visible=false,ZIndex=1}), Outline=add_drawing("Line",{Visible=false,ZIndex=0}) },
        LineRB={ Main=add_drawing("Line",{Visible=false,ZIndex=1}), Outline=add_drawing("Line",{Visible=false,ZIndex=0}) },
        LineBR={ Main=add_drawing("Line",{Visible=false,ZIndex=1}), Outline=add_drawing("Line",{Visible=false,ZIndex=0}) }
    }
end

function Drawing.AddESP(self, target, mode, flag, flags)
    if self.ESP[target] then return end
    self.ESP[target] = {
        Target = {}, Mode = mode, Flag = flag, Flags = flags,
        Drawing = {
            Box = new_box_draws(),
            HealthBar = {
                Main = add_drawing("Square",{Visible=false,ZIndex=1,Filled=true}),
                Outline = add_drawing("Square",{Visible=false,ZIndex=0,Filled=true})
            },
            Tracer = {
                Main = add_drawing("Line",{Visible=false,ZIndex=1}),
                Outline = add_drawing("Line",{Visible=false,ZIndex=0})
            },
            HeadDot = {
                Main = add_drawing("Circle",{Visible=false,ZIndex=1}),
                Outline = add_drawing("Circle",{Visible=false,ZIndex=0})
            },
            Arrow = {
                Main = add_drawing("Triangle",{Visible=false,ZIndex=1}),
                Outline = add_drawing("Triangle",{Visible=false,ZIndex=0})
            },
            Textboxes = {
                Name = add_drawing("Text",{Visible=false,ZIndex=0,Center=true,Outline=true,Color=White,Font=Fonts.Plex}),
                Distance = add_drawing("Text",{Visible=false,ZIndex=0,Center=true,Outline=true,Color=White,Font=Fonts.Plex}),
                Health = add_drawing("Text",{Visible=false,ZIndex=0,Center=false,Outline=true,Color=White,Font=Fonts.Plex}),
                Weapon = add_drawing("Text",{Visible=false,ZIndex=0,Center=false,Outline=true,Color=White,Font=Fonts.Plex})
            }
        }
    }
end

function Drawing.RemoveESP(self, target)
    local esp = self.ESP[target]
    if not esp then return end
    clear_drawing(esp.Drawing)
    clear(self.ESP[target])
    self.ESP[target] = nil
end

local function update_on_screen_target(esp, target)
    local Mode, Flag, Flags = esp.Mode, esp.Flag, esp.Flags
    local Textboxes = esp.Drawing.Textboxes

    local character, root = GetCharacter(target, Mode)
    if not (character and root) then
        return false, nil, nil, nil, nil, nil, nil, nil
    end

    local screen_pos, on_screen = world_to_screen(root.Position)
    if not on_screen then
        return false, character, root, screen_pos, 0, false, false, White
    end

    local dist = get_distance(root.Position)
    local in_range_bool = in_range(get_flag(Flags, Flag, "/DistanceCheck"), get_flag(Flags, Flag, "/Distance"), dist)
    if not in_range_bool then
        return false, character, root, screen_pos, dist, in_range_bool, false, White
    end

    local hp, maxhp, alive = GetHealth(target, character, Mode)
    if not alive then
        return false, character, root, screen_pos, dist, true, false, White
    end

    local enemy, team_color = GetTeam(target, character, Mode)
    local color = get_flag(Flags, Flag, "/TeamColor") and team_color
        or (enemy and get_flag(Flags, Flag, "/Enemy")[6] or get_flag(Flags, Flag, "/Ally")[6])

    return true, character, root, screen_pos, dist, true, enemy, color, hp, maxhp
end

local function set_line_pair(pair, color, thick, trans, from_v2, to_v2, outline_delta)
    pair.Main.Color = color
    pair.Main.Thickness = thick
    pair.Outline.Thickness = thick + 2
    pair.Main.Transparency = trans
    pair.Outline.Transparency = trans
    pair.Main.From = from_v2
    pair.Outline.From = from_v2 + outline_delta
    pair.Main.To = to_v2
    pair.Outline.To = to_v2 + outline_delta
end

local function draw_box(esp, screen_pos, box_size, color, flags, flag)
    local trans = 1 - get_flag(flags, flag, "/Box/Transparency")
    local thick = get_flag(flags, flag, "/Box/Thickness")
    local corner = get_flag(flags, flag, "/Box/CornerSize")
    local half = V2(box_size.X/2, box_size.Y/2)
    local corner_v = V2(half.X * (corner/100), half.Y * (corner/100))
    local thick_adj = floor(thick/2)

    local tl = anti_alias_xy(screen_pos.X - half.X, screen_pos.Y - half.Y)
    local tr = anti_alias_xy(screen_pos.X + half.X, screen_pos.Y - half.Y)
    local bl = anti_alias_xy(screen_pos.X - half.X, screen_pos.Y + half.Y)
    local br = anti_alias_xy(screen_pos.X + half.X, screen_pos.Y + half.Y)

    local Line = esp.Drawing.Box
    set_line_pair(Line.LineLT, color, thick, trans, tl - V2(0,thick_adj), tl + V2(0,corner_v.Y), V2(0,1))
    set_line_pair(Line.LineTL, color, thick, trans, tl - V2(thick_adj,0), tl + V2(corner_v.X,0), V2(1,0))
    set_line_pair(Line.LineLB, color, thick, trans, bl + V2(0,thick_adj), bl - V2(0,corner_v.Y), V2(0,-1))
    set_line_pair(Line.LineBL, color, thick, trans, bl - V2(thick_adj,1), bl + V2(corner_v.X,-1), V2(1,1))

    set_line_pair(Line.LineRT, color, thick, trans, tr - V2(1,thick_adj), tr + V2(0,corner_v.Y), V2(-1,1))
    set_line_pair(Line.LineTR, color, thick, trans, tr + V2(thick_adj,0), tr - V2(corner_v.X,0), V2(-1,0))
    set_line_pair(Line.LineRB, color, thick, trans, br + V2(-1,thick_adj), br - V2(0,corner_v.Y), V2(-1,1))
    set_line_pair(Line.LineBR, color, thick, trans, br + V2(thick_adj,-1), br - V2(corner_v.X,1), V2(-1,1))
end

function Drawing.Update(esp, target)
    local Textboxes = esp.Drawing.Textboxes
    local Mode, Flag, Flags = esp.Mode, esp.Flag, esp.Flags

    local ok, character, root, screen_pos, dist, in_range_bool, enemy, color, hp, maxhp =
        update_on_screen_target(esp, target)

    if ok then
        local tracer_vis = esp.Drawing.Tracer.Main.Visible
        local head_vis = esp.Drawing.HeadDot.Main.Visible
        if tracer_vis or head_vis then
            local head = character:FindFirstChild("Head", true)
            if head then
                local head_pos = world_to_screen(head.Position)
                if tracer_vis then
                    local from_sel = get_flag(Flags, Flag, "/Tracer/Mode")
                    local from_v = (from_sel[1] == "From Mouse" and UserInputService:GetMouseLocation())
                                    or (from_sel[1] == "From Bottom" and V2(Camera.ViewportSize.X/2, Camera.ViewportSize.Y))
                    local thickness = get_flag(Flags, Flag, "/Tracer/Thickness")
                    local transparency = 1 - get_flag(Flags, Flag, "/Tracer/Transparency")
                    esp.Drawing.Tracer.Main.Color = color
                    esp.Drawing.Tracer.Main.Thickness = thickness
                    esp.Drawing.Tracer.Outline.Thickness = thickness + 2
                    esp.Drawing.Tracer.Main.Transparency = transparency
                    esp.Drawing.Tracer.Outline.Transparency = transparency
                    esp.Drawing.Tracer.Main.From = from_v
                    esp.Drawing.Tracer.Outline.From = from_v
                    esp.Drawing.Tracer.Main.To = head_pos
                    esp.Drawing.Tracer.Outline.To = head_pos
                end
                if head_vis then
                    local filled = get_flag(Flags, Flag, "/HeadDot/Filled")
                    local radius = get_flag(Flags, Flag, "/HeadDot/Radius")
                    local numsides = get_flag(Flags, Flag, "/HeadDot/NumSides")
                    local thick = get_flag(Flags, Flag, "/HeadDot/Thickness")
                    local autoscale = get_flag(Flags, Flag, "/HeadDot/Autoscale")
                    local transparency = 1 - get_flag(Flags, Flag, "/HeadDot/Transparency")
                    radius = scale_factor(autoscale, radius, dist)
                    esp.Drawing.HeadDot.Main.Color = color
                    esp.Drawing.HeadDot.Main.Transparency = transparency
                    esp.Drawing.HeadDot.Outline.Transparency = transparency
                    esp.Drawing.HeadDot.Main.NumSides = numsides
                    esp.Drawing.HeadDot.Outline.NumSides = numsides
                    esp.Drawing.HeadDot.Main.Radius = radius
                    esp.Drawing.HeadDot.Outline.Radius = radius
                    esp.Drawing.HeadDot.Main.Thickness = thick
                    esp.Drawing.HeadDot.Outline.Thickness = thick + 2
                    esp.Drawing.HeadDot.Main.Filled = filled
                    esp.Drawing.HeadDot.Main.Position = head_pos
                    esp.Drawing.HeadDot.Outline.Position = head_pos
                end
            end
        end

        if esp.Drawing.Box.Visible then
            local box = calc_box_size(character, dist)
            local too_small = box.Y < 18
            draw_box(esp, screen_pos, box, color, Flags, Flag)

            if esp.Drawing.HealthBar.Main.Visible and not too_small then
                local hp_pct = clamp(hp / maxhp, 0, 1)
                local col = eval_health(hp_pct)
                local trans = 1 - get_flag(Flags, Flag, "/Box/Transparency")
                local thick = get_flag(Flags, Flag, "/Box/Thickness")
                local thick_adj = floor(thick/2)

                esp.Drawing.HealthBar.Main.Color = col
                esp.Drawing.HealthBar.Main.Transparency = trans
                esp.Drawing.HealthBar.Outline.Transparency = trans

                esp.Drawing.HealthBar.Outline.Size = anti_alias_xy(thick + 2, box.Y + (thick + 1))
                esp.Drawing.HealthBar.Outline.Position = anti_alias_xy(
                    (screen_pos.X - (box.X/2)) - thick - thick_adj - 4,
                    screen_pos.Y - (box.Y/2) - thick_adj - 1
                )
                esp.Drawing.HealthBar.Main.Size = V2(
                    esp.Drawing.HealthBar.Outline.Size.X - 2,
                    -hp_pct * (esp.Drawing.HealthBar.Outline.Size.Y - 2)
                )
                esp.Drawing.HealthBar.Main.Position = esp.Drawing.HealthBar.Outline.Position + V2(1, esp.Drawing.HealthBar.Outline.Size.Y - 1)
            end

            if Textboxes.Name.Visible or Textboxes.Health.Visible or Textboxes.Distance.Visible or Textboxes.Weapon.Visible then
                local size = get_flag(Flags, Flag, "/Name/Size")
                local autoscale = get_flag(Flags, Flag, "/Name/Autoscale")
                local font_trans = 1 - get_flag(Flags, Flag, "/Name/Transparency")
                local outline = get_flag(Flags, Flag, "/Name/Outline")
                local px_size = floor(scale_factor(autoscale, size, dist))

                if Textboxes.Name.Visible then
                    Textboxes.Name.Outline = outline
                    Textboxes.Name.Transparency = font_trans
                    Textboxes.Name.Size = px_size
                    Textboxes.Name.Text = Mode == "Player" and target.Name or (enemy and "Enemy NPC" or "Ally NPC")
                    Textboxes.Name.Position = anti_alias_xy(
                        screen_pos.X,
                        screen_pos.Y - (box.Y/2) - Textboxes.Name.TextBounds.Y - floor(get_flag(Flags, Flag, "/Box/Thickness")/2) - 2
                    )
                end

                if Textboxes.Health.Visible then
                    local hp_pct = clamp(hp / maxhp, 0, 1)
                    Textboxes.Health.Outline = outline
                    Textboxes.Health.Transparency = font_trans
                    Textboxes.Health.Size = px_size
                    Textboxes.Health.Text = tostring(math.floor(hp_pct * 100)) .. "%"

                    local thick = get_flag(Flags, Flag, "/Box/Thickness")
                    local thick_adj = floor(thick/2)
                    local base_x = (screen_pos.X - (box.X/2)) - Textboxes.Health.TextBounds.X - thick_adj - 2
                    if esp.Drawing.HealthBar.Main.Visible then
                        base_x = (screen_pos.X - (box.X/2)) - Textboxes.Health.TextBounds.X - (thick + thick_adj + 5)
                    end
                    Textboxes.Health.Position = anti_alias_xy(base_x, (screen_pos.Y - (box.Y/2)) - thick_adj - 1)
                end

                if Textboxes.Distance.Visible then
                    Textboxes.Distance.Outline = outline
                    Textboxes.Distance.Transparency = font_trans
                    Textboxes.Distance.Size = px_size
                    Textboxes.Distance.Text = tostring(math.floor(dist)) .. " studs"
                    Textboxes.Distance.Position = anti_alias_xy(
                        screen_pos.X,
                        (screen_pos.Y + (box.Y/2)) + floor(get_flag(Flags, Flag, "/Box/Thickness")/2) + 2
                    )
                end

                if Textboxes.Weapon.Visible then
                    local w = GetWeapon(target, character, Mode)
                    local thick = get_flag(Flags, Flag, "/Box/Thickness")
                    local thick_adj = floor(thick/2)
                    Textboxes.Weapon.Outline = outline
                    Textboxes.Weapon.Transparency = font_trans
                    Textboxes.Weapon.Size = px_size
                    Textboxes.Weapon.Text = w
                    Textboxes.Weapon.Position = anti_alias_xy(
                        (screen_pos.X + (box.X/2)) + thick_adj + 2,
                        screen_pos.Y - (box.Y/2) - thick_adj - 1
                    )
                end
            end
        end
    else
        if esp.Drawing.Arrow.Main.Visible and character and root then
            local dist = get_distance(root.Position)
            local inr = in_range(get_flag(Flags, Flag, "/DistanceCheck"), get_flag(Flags, Flag, "/Distance"), dist)
            if inr then
                local hp, maxhp, alive = GetHealth(target, character, esp.Mode)
                if alive then
                    local enemy, team_color = GetTeam(target, character, esp.Mode)
                    local color = get_flag(Flags, Flag, "/TeamColor") and team_color
                        or (enemy and get_flag(Flags, Flag, "/Enemy")[6] or get_flag(Flags, Flag, "/Ally")[6])

                    local dir = cf_object_space(Camera.CFrame, root.Position).Unit
                    local side = get_flag(Flags, Flag, "/Arrow/Width")/2
                    local radius = get_flag(Flags, Flag, "/Arrow/Radius")
                    local base = dir * radius
                    local r90 = rad(90)

                    local pA = relative_screen_center(base + rotate_v2(dir, r90) * side)
                    local pB = relative_screen_center(dir * (radius + get_flag(Flags, Flag, "/Arrow/Height")))
                    local pC = relative_screen_center(base + rotate_v2(dir, -r90) * side)

                    local filled = get_flag(Flags, Flag, "/Arrow/Filled")
                    local thick = get_flag(Flags, Flag, "/Arrow/Thickness")
                    local trans = 1 - get_flag(Flags, Flag, "/Arrow/Transparency")

                    esp.Drawing.Arrow.Main.Color = color
                    esp.Drawing.Arrow.Main.Filled = filled
                    esp.Drawing.Arrow.Main.Thickness = thick
                    esp.Drawing.Arrow.Outline.Thickness = thick + 2
                    esp.Drawing.Arrow.Main.Transparency = trans
                    esp.Drawing.Arrow.Outline.Transparency = trans

                    esp.Drawing.Arrow.Main.PointA = pA
                    esp.Drawing.Arrow.Outline.PointA = pA
                    esp.Drawing.Arrow.Main.PointB = pB
                    esp.Drawing.Arrow.Outline.PointB = pB
                    esp.Drawing.Arrow.Main.PointC = pC
                    esp.Drawing.Arrow.Outline.PointC = pC
                end
            end
        end
    end

    local team_check = (not get_flag(Flags, Flag, "/TeamCheck") and not enemy) or enemy
    local visible = ok and team_check
    local arrow_visible = (not ok) and team_check

    esp.Drawing.Box.Visible = visible and get_flag(Flags, Flag, "/Box/Enabled") or false
    esp.Drawing.Box.OutlineVisible = esp.Drawing.Box.Visible and get_flag(Flags, Flag, "/Box/Outline") or false
    for k,v in pairs(esp.Drawing.Box) do
        if type(v) == "table" then
            v.Main.Visible = esp.Drawing.Box.Visible
            v.Outline.Visible = esp.Drawing.Box.OutlineVisible
        end
    end

    esp.Drawing.HealthBar.Main.Visible = esp.Drawing.Box.Visible and get_flag(Flags, Flag, "/Box/HealthBar") or false
    esp.Drawing.HealthBar.Outline.Visible = esp.Drawing.HealthBar.Main.Visible and get_flag(Flags, Flag, "/Box/Outline") or false

    esp.Drawing.Arrow.Main.Visible = arrow_visible and get_flag(Flags, Flag, "/Arrow/Enabled") or false
    esp.Drawing.Arrow.Outline.Visible = get_flag(Flags, Flag, "/Arrow/Outline") and esp.Drawing.Arrow.Main.Visible or false

    esp.Drawing.HeadDot.Main.Visible = visible and get_flag(Flags, Flag, "/HeadDot/Enabled") or false
    esp.Drawing.HeadDot.Outline.Visible = get_flag(Flags, Flag, "/HeadDot/Outline") and esp.Drawing.HeadDot.Main.Visible or false

    esp.Drawing.Tracer.Main.Visible = visible and get_flag(Flags, Flag, "/Tracer/Enabled") or false
    esp.Drawing.Tracer.Outline.Visible = get_flag(Flags, Flag, "/Tracer/Outline") and esp.Drawing.Tracer.Main.Visible or false

    esp.Drawing.Textboxes.Name.Visible = visible and get_flag(Flags, Flag, "/Name/Enabled") or false
    esp.Drawing.Textboxes.Health.Visible = visible and get_flag(Flags, Flag, "/Health/Enabled") or false
    esp.Drawing.Textboxes.Distance.Visible = visible and get_flag(Flags, Flag, "/Distance/Enabled") or false
    esp.Drawing.Textboxes.Weapon.Visible = visible and get_flag(Flags, Flag, "/Weapon/Enabled") or false
end

--[[function Drawing.SetupCursor(Window)
    local Cursor = add_drawing("Image", {
        Size = V2(64,64)/1.5, Data = Testhook.Cursor, ZIndex = 3
    })
    RunService.Heartbeat:Connect(function()
        local vis = Window.Flags["Mouse/Enabled"] and Window.Enabled and UserInputService.MouseBehavior == Enum.MouseBehavior.Default
        Cursor.Visible = vis
        if vis then
            Cursor.Position = UserInputService:GetMouseLocation() - Cursor.Size/2
        end
    end)
end--]]

function Drawing.SetupCrosshair(Flags)
    local L = add_drawing("Line",{Thickness=1.5,Transparency=1,Visible=false,ZIndex=2})
    local R = add_drawing("Line",{Thickness=1.5,Transparency=1,Visible=false,ZIndex=2})
    local T = add_drawing("Line",{Thickness=1.5,Transparency=1,Visible=false,ZIndex=2})
    local B = add_drawing("Line",{Thickness=1.5,Transparency=1,Visible=false,ZIndex=2})
    RunService.Heartbeat:Connect(function()
        local on = Flags["Crosshair/Enabled"]
            and UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default
            and not UserInputService.MouseIconEnabled
        L.Visible,R.Visible,T.Visible,B.Visible = on,on,on,on
        if on then
            local p = UserInputService:GetMouseLocation()
            local c = Flags["Crosshair/Color"]; local size = Flags["Crosshair/Size"]; local gap = Flags["Crosshair/Gap"]
            local color = c[6]; local tr = 1 - c[4]
            L.Color = color; L.Transparency = tr; L.From = p - V2(gap,0); L.To = p - V2(size+gap,0)
            R.Color = color; R.Transparency = tr; R.From = p + V2(gap+1,0); R.To = p + V2(size+gap+1,0)
            T.Color = color; T.Transparency = tr; T.From = p - V2(0,gap); T.To = p - V2(0,size+gap)
            B.Color = color; B.Transparency = tr; B.From = p + V2(0,gap+1); B.To = p + V2(0,size+gap+1)
        end
    end)
end

function Drawing.SetupFOV(flag, flags)
    local F = add_drawing("Circle",{ZIndex=4})
    local O = add_drawing("Circle",{ZIndex=3})
    RunService.Heartbeat:Connect(function()
        local vis = get_flag(flags, flag, "/Enabled") and get_flag(flags, flag, "/FOV/Enabled")
        F.Visible = vis; O.Visible = vis
        if vis then
            local p = UserInputService:GetMouseLocation()
            local thick = get_flag(flags, flag, "/FOV/Thickness")
            local sides = get_flag(flags, flag, "/FOV/NumSides")
            local filled = get_flag(flags, flag, "/FOV/Filled")
            local rad = get_flag(flags, flag, "/FOV/Radius")
            local c = get_flag(flags, flag, "/FOV/Color")
            local tr = 1 - c[4]; local col = c[6]
            F.Color = col; F.Transparency = tr; O.Transparency = tr
            F.Thickness = thick; O.Thickness = thick + 2
            F.NumSides = sides; O.NumSides = sides
            F.Filled = filled
            F.Radius = rad; O.Radius = rad
            F.Position = p; O.Position = p
        end
    end)
end

Drawing.Connection = RunService.RenderStepped:Connect(function()
    for tgt, esp in pairs(Drawing.ESP) do
        Drawing.Update(esp, tgt)
    end
    for obj, esp in pairs(Drawing.ObjectESP) do
        if not get_flag(esp.Flags, esp.GlobalFlag, "/Enabled") or not get_flag(esp.Flags, esp.Flag, "/Enabled") then
            esp.Name.Visible = false
        else
            esp.Target.Position = esp.IsBasePart and esp.Target.RootPart.Position or esp.Target.Position
            local sp, on = world_to_screen(esp.Target.Position); esp.Target.ScreenPosition, esp.Target.OnScreen = sp, on
            local dist = get_distance(esp.Target.Position); esp.Target.Distance = dist
            esp.Target.InTheRange = in_range(get_flag(esp.Flags, esp.GlobalFlag, "/DistanceCheck"),
                                             get_flag(esp.Flags, esp.GlobalFlag, "/Distance"), dist)
            local visible = (on and esp.Target.InTheRange) or false
            esp.Name.Visible = visible
            if visible then
                local col = get_flag(esp.Flags, esp.Flag, "/Color")
                esp.Name.Transparency = 1 - col[4]
                esp.Name.Color = col[6]
                esp.Name.Position = sp
                esp.Name.Text = string.format("%s\n%i studs", esp.Target.Name, dist)
            end
        end
    end
end)

return Drawing
