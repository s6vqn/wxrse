local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,                         -- nagsisimula na naka-OFF
    ToggleKey = Enum.KeyCode.T,              -- pindutin para ON/OFF
    HoldKey = Enum.UserInputType.MouseButton2, -- hawakan para mag auto shoot

    TrigSpeed = 100,       -- clicks bawat segundo (1-200), napakabilis
    MaxDistance = 300,     -- studs
    WallCheck = true,      -- may sariling ray bawat player
    HeadOnly = false,      -- true = ulo lang ang binabaril kapag hindi tumatalon

    FocusFOV = 40,         -- pixels mula sa gitna para mapili ang focus player
    FocusKeep = 2.5,       -- gaano kalawak bago mawala ang focus (FocusFOV x ito)
    LockSpeed = 40,        -- lakas ng lock kapag tumalon ang focus player
    FireRadius = 18,       -- pixels: barilin kapag ganito kalapit sa crosshair ang target
    AimPart = "HumanoidRootPart",
    Prediction = true,
    PredictionTime = 0.08, -- dagdag na segundo bukod sa ping

    Debug = false,
}

print("[JumpTrigger] Loaded. T = ON/OFF (starts OFF)")

local focusPlayer = nil
local lastClick = 0
local lastLog = 0

local function log(...)
    if Settings.Debug and os.clock() - lastLog > 0.5 then
        lastLog = os.clock()
        print("[JumpTrigger]", ...)
    end
end

local function isDown(key)
    if key.EnumType == Enum.UserInputType then
        return UIS:IsMouseButtonPressed(key)
    end
    return UIS:IsKeyDown(key)
end

-- T = ON/OFF
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Settings.ToggleKey then
        Settings.Enabled = not Settings.Enabled
        focusPlayer = nil
        print("[JumpTrigger] Enabled:", Settings.Enabled)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if p == focusPlayer then focusPlayer = nil end
end)

local function isDead(char, hum)
    if hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then
        return true
    end
    local ok, ko = pcall(function()
        local be = char:FindFirstChild("BodyEffects")
        local v = be and be:FindFirstChild("K.O")
        return v and v.Value
    end)
    return ok and ko == true
end

local function isAirborne(hum, root)
    local s = hum:GetState()
    if s == Enum.HumanoidStateType.Jumping or s == Enum.HumanoidStateType.Freefall then
        return true
    end
    if hum.FloorMaterial == Enum.Material.Air then
        return true
    end
    return math.abs(root.AssemblyLinearVelocity.Y) > 8
end

local function predicted(part, root, hum)
    if not Settings.Prediction then return part.Position end
    local t = Settings.PredictionTime
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if ok and ping then t = t + ping end
    local v = root.AssemblyLinearVelocity
    if isAirborne(hum, root) then
        return part.Position + v * t + Vector3.new(0, -0.5 * workspace.Gravity * t * t, 0)
    end
    return part.Position + Vector3.new(v.X, 0, v.Z) * t
end

local function click()
    if mouse1click then
        mouse1click()
    else
        local vim = game:GetService("VirtualInputManager")
        local c = workspace.CurrentCamera.ViewportSize / 2
        vim:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0)
        vim:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
    end
end

local function screenDist(cam, pos)
    local v, on = cam:WorldToViewportPoint(pos)
    if not on then return nil end
    return (Vector2.new(v.X, v.Y) - cam.ViewportSize / 2).Magnitude
end

-- wall check: SARILING RAY ng bawat player (camera -> player). Pader at mapa lang ang haharang.
local function wallVisible(cam, pos)
    if not Settings.WallCheck then return true end
    local ignore = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then table.insert(ignore, p.Character) end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    local origin = cam.CFrame.Position
    for _ = 1, 15 do
        local hit = workspace:Raycast(origin, pos - origin, params)
        if not hit then return true end
        if hit.Instance.Transparency >= 0.9 or not hit.Instance.CanCollide then
            table.insert(ignore, hit.Instance)
            params.FilterDescendantsInstances = ignore
        else
            return false
        end
    end
    return false
end

-- sinusuri ang isang player. Ibabalik ang (layo sa crosshair, aim part, root, humanoid, char) o nil
local function evaluate(cam, p, fov)
    local char = p.Character
    if not char or p == LocalPlayer then return nil end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) or isDead(char, hum) then return nil end

    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or cam.CFrame.Position
    if (root.Position - myPos).Magnitude > Settings.MaxDistance then return nil end

    local part = char:FindFirstChild(Settings.AimPart) or root
    local head = char:FindFirstChild("Head")

    local d = screenDist(cam, part.Position)
    local dh = head and screenDist(cam, head.Position)
    if dh and (not d or dh < d) then d = dh end
    if not d or d > fov then return nil end

    if not wallVisible(cam, part.Position) and not (head and wallVisible(cam, head.Position)) then
        return nil
    end
    return d, part, root, hum, char
end

-- kung nasa focus player ang crosshair (walang ibang pader/player sa pagitan)
local function crosshairOnFocus(cam, targetChar)
    local c = cam.ViewportSize / 2
    local ray = cam:ViewportPointToRay(c.X, c.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    params.FilterDescendantsInstances = ignore

    for _ = 1, 12 do
        local hit = workspace:Raycast(ray.Origin, ray.Direction * Settings.MaxDistance, params)
        if not hit then return false end
        local inst = hit.Instance
        local model = inst:FindFirstAncestorOfClass("Model")
        local hum = model and model:FindFirstChildOfClass("Humanoid")

        if model == targetChar then
            if Settings.HeadOnly and inst.Name ~= "Head" then return false end
            return true
        elseif model and hum then
            if isDead(model, hum) then
                table.insert(ignore, model) -- lampasan ang bangkay
                params.FilterDescendantsInstances = ignore
            else
                return false -- ibang buhay na player ang nasa harap
            end
        elseif inst.Transparency >= 0.9 or not inst.CanCollide or not Settings.WallCheck then
            table.insert(ignore, inst)
            params.FilterDescendantsInstances = ignore
        else
            return false
        end
    end
    return false
end

RunService:BindToRenderStep("JumpTrigger", Enum.RenderPriority.Last.Value + 1, function(dt)
    if not Settings.Enabled then return end

    -- lahat (focus, aimlock, pagbaril) ay gumagana LANG habang hawak ang right click
    local holding = isDown(Settings.HoldKey)
    if not holding then
        focusPlayer = nil
        return
    end
    local cam = workspace.CurrentCamera

    -- 1) i-check kung valid pa ang focus player
    if focusPlayer then
        local d = evaluate(cam, focusPlayer, Settings.FocusFOV * Settings.FocusKeep)
        if not d then
            log("nawala ang focus")
            focusPlayer = nil
        end
    end

    -- 2) pumili ng focus: ang player na pinakamalapit sa crosshair (isa lang)
    if not focusPlayer then
        local bestD = Settings.FocusFOV
        for _, p in ipairs(Players:GetPlayers()) do
            local d = evaluate(cam, p, bestD)
            if d and d < bestD then
                bestD = d
                focusPlayer = p
            end
        end
        if focusPlayer then log("focus:", focusPlayer.Name) end
    end

    if not focusPlayer then return end

    -- 3) para LANG sa focus player
    --    tumatalon: aimlock at agad na babaril
    --    hindi tumatalon: walang aimlock, normal na trigger lang
    local d, part, root, hum, char = evaluate(cam, focusPlayer, Settings.FocusFOV * Settings.FocusKeep)
    if not d then return end

    local fire = false

    if isAirborne(hum, root) then
        local target = predicted(part, root, hum)
        local alpha = 1 - math.exp(-Settings.LockSpeed * dt)
        cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, target), alpha)
        local sd = screenDist(cam, target)
        log("JUMP LOCK", focusPlayer.Name, sd and math.floor(sd) or "off-screen", holding and "(shooting)" or "(no hold)")
        if holding and sd and sd <= Settings.FireRadius then
            fire = true
        end
    elseif holding and crosshairOnFocus(cam, char) then
        fire = true
    end

    if fire then
        local delay = 1 / math.clamp(Settings.TrigSpeed, 1, 200)
        if os.clock() - lastClick >= delay then
            lastClick = os.clock()
            click()
        end
    end
end)
