local eps = 1e-10

local function is_zero(x)
    return x > -eps and x < eps
end

local function cube_root(x)
    return x >= 0 and x ^ (1/3) or -((-x) ^ (1/3))
end

local function solve_quadratic(a, b, c)
    if is_zero(a) then
        if is_zero(b) then
            return {}
        end
        return { -c / b }
    end
    local d = b*b - 4*a*c
    if d < -eps then return {} end
    if d < 0 then d = 0 end
    local s = math.sqrt(d)
    local q = -0.5 * (b + (b >= 0 and 1 or -1) * s)
    local x1 = q / a
    local x2 = is_zero(q) and x1 or c / q
    if math.abs(x1 - x2) < 1e-12 then return {x1} end
    if x1 < x2 then return {x1, x2} else return {x2, x1} end
end

local function solve_cubic(a, b, c, d)
    if is_zero(a) then return solve_quadratic(b, c, d) end
    local A = b / a
    local B = c / a
    local C = d / a
    local sqA = A*A
    local p = (1/3) * (-(1/3) * sqA + B)
    local q = 0.5 * ((2/27) * A * sqA - (1/3) * A * B + C)
    local D = q*q + p*p*p
    local roots = {}
    if is_zero(D) then
        if is_zero(q) then
            roots[1] = 0
        else
            local u = cube_root(-q)
            roots[1] = 2*u
            roots[2] = -u
        end
    elseif D < 0 then
        local phi = (1/3) * math.acos(-q / math.sqrt(-p*p*p))
        local t = 2 * math.sqrt(-p)
        roots[1] = t * math.cos(phi)
        roots[2] = -t * math.cos(phi + math.pi/3)
        roots[3] = -t * math.cos(phi - math.pi/3)
    else
        local s = math.sqrt(D)
        local u = cube_root(s - q)
        local v = -cube_root(s + q)
        roots[1] = u + v
    end
    local sub = A / 3
    for i=1,#roots do roots[i] = roots[i] - sub end
    table.sort(roots, function(x,y) return x<y end)
    return roots
end

local function solve_quartic(a, b, c, d, e)
    if is_zero(a) then return solve_cubic(b, c, d, e) end
    local A = b / a
    local B = c / a
    local C = d / a
    local D = e / a
    local sqA = A*A
    local p = -0.375 * sqA + B
    local q = 0.125 * sqA * A - 0.5 * A * B + C
    local r = -(3/256) * sqA * sqA + 0.0625 * sqA * B - 0.25 * A * C + D
    local roots = {}

    if is_zero(q) then
        local t_roots = solve_quadratic(1, p, r)
        for i=1,#t_roots do
            local t = t_roots[i]
            if t >= -eps then
                if t < 0 then t = 0 end
                local s = math.sqrt(t)
                roots[#roots+1] = s
                roots[#roots+1] = -s
            end
        end
    else
        local z_roots = solve_cubic(1, -0.5 * p, -r, 0.5 * r * p - 0.125 * q * q)
        for zi=1,#z_roots do
            local z = z_roots[zi]
            if z then
                local u2 = z*z - r
                local v2 = 2*z - p
                if u2 >= -eps and v2 >= -eps then
                    if u2 < 0 then u2 = 0 end
                    if v2 < 0 then v2 = 0 end
                    local u = math.sqrt(u2)
                    local v = math.sqrt(v2)
                    local b1 = (q < 0) and -v or v
                    local b2 = (q < 0) and  v or -v
                    local r1 = solve_quadratic(1, b1, z - u)
                    local r2 = solve_quadratic(1, b2, z + u)
                    for i=1,#r1 do roots[#roots+1] = r1[i] end
                    for i=1,#r2 do roots[#roots+1] = r2[i] end
                    break
                end
            end
        end
    end

    local sub = 0.25 * A
    local out = {}
    for i=1,#roots do
        if roots[i] then
            out[#out+1] = roots[i] - sub
        end
    end
    table.sort(out, function(x,y) return x<y end)
    return out
end

local function pick_min_positive(ts)
    local best
    for i=1,#ts do
        local t = ts[i]
        if t and t > eps and (not best or t < best) then
            best = t
        end
    end
    return best
end

local Physics = {}

function Physics.SolveTrajectory(origin, target_position, target_velocity, projectile_speed, gravity, gravity_correction)
    target_velocity = target_velocity or Vector3.zero
    if not projectile_speed or projectile_speed <= 0 then
        return target_position
    end
    local g
    if typeof(gravity) == "Vector3" then
        g = gravity
    elseif type(gravity) == "number" then
        g = Vector3.new(0, -gravity, 0)
    else
        local gv = (rawget(getfenv(), "workspace") and workspace.Gravity) or 196.2
        g = Vector3.new(0, -gv, 0)
    end
    if gravity_correction and gravity_correction ~= 0 then
        g = g / gravity_correction
    end

    local p = target_position - origin
    local v = target_velocity
    local s = projectile_speed

    local gg = g:Dot(g)
    local a = 0.25 * gg
    local b = 0.5 * v:Dot(g)
    local c = v:Dot(v) + p:Dot(g) - s*s
    local d = 2 * p:Dot(v)
    local e = p:Dot(p)

    local ts = solve_quartic(a, b, c, d, e)
    local tof = pick_min_positive(ts)
    if not tof then
        return target_position
    end

    local v0 = (p + v * tof + 0.5 * g * tof * tof) / tof
    return origin + v0
end

return Physics
