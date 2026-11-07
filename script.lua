local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    TrigKey = Enum.UserInputType.MouseButton2, -- hold para mag auto shoot
    TrigSpeed = 60,        -- clicks bawat segundo (1-200)
    MaxDistance = 300,     -- studs
    WallCheck = true,
    HeadOnly = false,      -- true = ulo lang ang tatamaan sa normal na trigger

    -- jump lock
    JumpLock = true,       -- kusang lock kapag tumalon ang player
    LockFOV = 120,         -- pixels mula sa gitna kung saan hahanapin ang tumatalon
    LockSpeed = 25,        -- lakas ng lock (mas mataas = mas mabilis)
    MoveFree = 0.3,        -- hina ng lock kapag ginagalaw mo ang mouse
    FireRadius = 14,       -- pixels: magpapaputok kapag ganito kalapit sa crosshair ang predicted na punto
    AimPart = "HumanoidRootPart", -- bahagi na tututukan habang nasa ere (mas madaling tamaan)
    Prediction = true,
    PredictionTime = 0.08, -- dagdag na segundo bukod sa ping

    Debug = false,
}

print("[Trigger] Loaded. Hold RightClick = auto shoot + lock on jumping players")

local function isDown(key)
    if key.EnumType == Enum.UserInputType then
        return UIS:IsMouseButtonPressed(key)
    end
    return UIS:IsKeyDown(key)
end

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
        -- sundan ang arko ng talon
        return part.Position + v * t + Vector3.new(0, -0.5 * workspace.Gravity * t * t, 0)
    end
    return part.Position + Vector3.new(v.X, 0, v.Z) * t
end

local lastLog = 0
local function log(...)
    if Settings.Debug and os.clock() - lastLog > 0.5 then
        lastLog = os.clock()
        print("[Trigger]", ...)
    end
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

-- may harang ba (pader/mapa) papunta sa posisyon? lahat ng character ay lalampasan
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

-- normal trigger: buhay na player ang nasa crosshair
local function crosshairOnPlayer(cam)
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
        local plr = model and Players:GetPlayerFromCharacter(model)

        if plr and hum then
            if plr == LocalPlayer then return false end
            if isDead(model, hum) then
                table.insert(ignore, model)
                params.FilterDescendantsInstances = ignore
            else
                if Settings.HeadOnly and inst.Name ~= "Head" then return false end
                return true
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

-- hanapin ang pinakamalapit sa crosshair na TUMATALON na player
local function getJumper(cam)
    local center = cam.ViewportSize / 2
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or cam.CFrame.Position
    local best, bestDist, bestScreen = nil, Settings.LockFOV, nil

    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if p ~= LocalPlayer and char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            local part = char:FindFirstChild(Settings.AimPart) or root
            if hum and root and part and not isDead(char, hum) and isAirborne(hum, root) then
                if (root.Position - myPos).Magnitude <= Settings.MaxDistance then
                    local pos = predicted(part, root, hum)
                    local v, on = cam:WorldToViewportPoint(pos)
                    if on then
                        local d = (Vector2.new(v.X, v.Y) - center).Magnitude
                        if d < bestDist and wallVisible(cam, part.Position) then
                            best, bestDist, bestScreen = pos, d, d
                        end
                    end
                end
            end
        end
    end
    return best, bestScreen
end

local lastClick = 0

RunService:BindToRenderStep("TriggerBot", Enum.RenderPriority.Last.Value + 1, function(dt)
    if not isDown(Settings.TrigKey) then return end

    local cam = workspace.CurrentCamera
    local delay = 1 / math.clamp(Settings.TrigSpeed, 1, 200)
    local canClick = os.clock() - lastClick >= delay
    local shouldFire = false

    -- JUMP LOCK: kapag may tumatalon na player sa loob ng LockFOV, i-lock at barilin
    if Settings.JumpLock then
        local target, screenDist = getJumper(cam)
        if target then
            local speed = Settings.LockSpeed
            if UIS:GetMouseDelta().Magnitude > 1 then
                speed = speed * Settings.MoveFree
            end
            local alpha = 1 - math.exp(-speed * dt)
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, target), alpha)
            log("jump lock, layo sa crosshair:", math.floor(screenDist))
            if screenDist <= Settings.FireRadius then
                shouldFire = true
            end
        end
    end

    -- normal trigger: kung nasa buhay na player ang crosshair
    if not shouldFire and crosshairOnPlayer(cam) then
        shouldFire = true
    end

    if shouldFire and canClick then
        lastClick = os.clock()
        click()
    end
end)
