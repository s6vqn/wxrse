-- ═══════════════════════════════════════════════════════════════════
--  Camlock + Smoothing — may GUI menu
--  LocalScript (StarterPlayerScripts) o executor paste
-- ═══════════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ── State ───────────────────────────────────────────────────────────
local State = {
	active      = false,
	target      = nil,
	TargetPart  = "Head",
	FovRadius   = 250,
	Smooth      = 50,      -- 1 = hard lock, 100 = pinakamalambot
	TeamCheck   = true,
	ToggleKey   = Enum.KeyCode.E,
	MenuKey     = Enum.KeyCode.Insert,
}

-- ── GUI ─────────────────────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name             = "CamlockGui"
ScreenGui.ResetOnSpawn     = false
ScreenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LP:WaitForChild("PlayerGui") end

local Frame = Instance.new("Frame")
Frame.Size           = UDim2.fromOffset(280, 260)
Frame.Position       = UDim2.fromOffset(20, 120)
Frame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
Frame.BorderSizePixel  = 0
Frame.Active         = true
Frame.Draggable      = true
Frame.Parent         = ScreenGui

local corner = Instance.new("UICorner", Frame) corner.CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size       = UDim2.new(1, 0, 0, 34)
Title.BackgroundTransparency = 1
Title.Text       = "  Camlock"
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font       = Enum.Font.GothamBold
Title.TextSize   = 16
Title.TextColor3 = Color3.fromRGB(63, 94, 251)
Title.Parent     = Frame

local function makeLabel(text, y)
	local l = Instance.new("TextLabel")
	l.Size             = UDim2.new(1, -20, 0, 18)
	l.Position         = UDim2.fromOffset(10, y)
	l.BackgroundTransparency = 1
	l.Text             = text
	l.TextXAlignment   = Enum.TextXAlignment.Left
	l.Font             = Enum.Font.Gotham
	l.TextSize         = 13
	l.TextColor3       = Color3.fromRGB(200, 200, 200)
	l.Parent           = Frame
	return l
end

-- Toggle button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size             = UDim2.new(1, -20, 0, 30)
ToggleBtn.Position         = UDim2.fromOffset(10, 40)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
ToggleBtn.Text             = "Camlock: OFF"
ToggleBtn.Font             = Enum.Font.GothamBold
ToggleBtn.TextSize         = 14
ToggleBtn.TextColor3       = Color3.fromRGB(255, 90, 90)
ToggleBtn.Parent           = Frame
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)

ToggleBtn.MouseButton1Click:Connect(function()
	State.active = not State.active
	ToggleBtn.Text       = State.active and "Camlock: ON" or "Camlock: OFF"
	ToggleBtn.TextColor3 = State.active and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 90, 90)
	if not State.active then State.target = nil end
end)

-- Smoothness slider
makeLabel("Smoothness: " .. State.Smooth, 80)
local SmoothSlider = Instance.new("TextButton")
SmoothSlider.Size             = UDim2.new(1, -20, 0, 6)
SmoothSlider.Position         = UDim2.fromOffset(10, 102)
SmoothSlider.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
SmoothSlider.Text             = ""
SmoothSlider.Parent           = Frame
Instance.new("UICorner", SmoothSlider).CornerRadius = UDim.new(1, 0)

local SmoothFill = Instance.new("Frame")
SmoothFill.Size             = UDim2.new(State.Smooth / 100, 0, 1, 0)
SmoothFill.BackgroundColor3 = Color3.fromRGB(63, 94, 251)
SmoothFill.Parent           = SmoothSlider
Instance.new("UICorner", SmoothFill).CornerRadius = UDim.new(1, 0)

local smoothLabel
for _, c in ipairs(Frame:GetChildren()) do
	if c:IsA("TextLabel") and c.Text:match("^Smoothness") then smoothLabel = c end
end

local draggingSlider = false
SmoothSlider.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
	or i.UserInputType == Enum.UserInputType.Touch then
		draggingSlider = true
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
	or i.UserInputType == Enum.UserInputType.Touch then
		draggingSlider = false
	end
end)
UserInputService.InputChanged:Connect(function(i)
	if draggingSlider and (i.UserInputType == Enum.UserInputType.MouseMovement
	                    or i.UserInputType == Enum.UserInputType.Touch) then
		local rel = math.clamp((i.Position.X - SmoothSlider.AbsolutePosition.X)
		           / SmoothSlider.AbsoluteSize.X, 0, 1)
		State.Smooth = math.floor(rel * 99) + 1
		SmoothFill.Size    = UDim2.new(rel, 0, 1, 0)
		smoothLabel.Text   = "Smoothness: " .. State.Smooth
	end
end)

-- FOV slider
makeLabel("FOV Radius: " .. State.FovRadius, 120)
local FovSlider = SmoothSlider:Clone()
FovSlider.Position = UDim2.fromOffset(10, 142)
FovSlider.Parent   = Frame
local FovFill = FovSlider:FindFirstChildOfClass("Frame")
FovFill.Size = UDim2.new(math.min(State.FovRadius / 500, 1), 0, 1, 0)

local fovLabel
for _, c in ipairs(Frame:GetChildren()) do
	if c:IsA("TextLabel") and c.Text:match("^FOV") then fovLabel = c end
end

local draggingFov = false
FovSlider.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
	or i.UserInputType == Enum.UserInputType.Touch then
		draggingFov = true
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
	or i.UserInputType == Enum.UserInputType.Touch then
		draggingFov = false
	end
end)
UserInputService.InputChanged:Connect(function(i)
	if draggingFov and (i.UserInputType == Enum.UserInputType.MouseMovement
	                 or i.UserInputType == Enum.UserInputType.Touch) then
		local rel = math.clamp((i.Position.X - FovSlider.AbsolutePosition.X)
		           / FovSlider.AbsoluteSize.X, 0, 1)
		State.FovRadius = math.floor(rel * 500)
		FovFill.Size    = UDim2.new(rel, 0, 1, 0)
		fovLabel.Text   = "FOV Radius: " .. State.FovRadius
	end
end)

-- Target part dropdown (simple cycle button)
makeLabel("Target Part", 162)
local PartBtn = Instance.new("TextButton")
PartBtn.Size             = UDim2.new(1, -20, 0, 26)
PartBtn.Position         = UDim2.fromOffset(10, 184)
PartBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
PartBtn.Text             = State.TargetPart
PartBtn.Font             = Enum.Font.Gotham
PartBtn.TextSize         = 13
PartBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
PartBtn.Parent           = Frame
Instance.new("UICorner", PartBtn).CornerRadius = UDim.new(0, 8)

local parts = {"Head", "UpperTorso", "HumanoidRootPart", "Torso"}
local pi = 1
PartBtn.MouseButton1Click:Connect(function()
	pi = (pi % #parts) + 1
	State.TargetPart = parts[pi]
	PartBtn.Text = State.TargetPart
end)

-- Team check toggle
local TeamBtn = Instance.new("TextButton")
TeamBtn.Size             = UDim2.new(1, -20, 0, 26)
TeamBtn.Position         = UDim2.fromOffset(10, 216)
TeamBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
TeamBtn.Text             = "Team Check: ON"
TeamBtn.Font             = Enum.Font.Gotham
TeamBtn.TextSize         = 13
TeamBtn.TextColor3       = Color3.fromRGB(90, 255, 120)
TeamBtn.Parent           = Frame
Instance.new("UICorner", TeamBtn).CornerRadius = UDim.new(0, 8)

TeamBtn.MouseButton1Click:Connect(function()
	State.TeamCheck = not State.TeamCheck
	TeamBtn.Text       = "Team Check: " .. (State.TeamCheck and "ON" or "OFF")
	TeamBtn.TextColor3 = State.TeamCheck and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 90, 90)
end)

-- ── Aim logic ───────────────────────────────────────────────────────
local function isAlive(plr)
	local char = plr.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	return char ~= nil and hum ~= nil and hum.Health > 0
end

local function partOf(plr)
	local char = plr.Character
	if not char then return nil end
	return char:FindFirstChild(State.TargetPart) or char:FindFirstChild("HumanoidRootPart")
end

local function passesTeam(plr)
	if not State.TeamCheck then return true end
	return LP.Team == nil or plr.Team == nil or LP.Team ~= plr.Team
end

local function findBest()
	local center = Camera.ViewportSize * 0.5
	local best, bestD = nil, State.FovRadius
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and isAlive(plr) and passesTeam(plr) then
			local part = partOf(plr)
			if part then
				local sp, on = Camera:WorldToViewportPoint(part.Position)
				if on then
					local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
					if d <= bestD then best, bestD = plr, d end
				end
			end
		end
	end
	return best
end

RunService:BindToRenderStep("CamlockLoop", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not State.active then return end
	local t = State.target
	if not t or not isAlive(t) or not passesTeam(t) then
		t = findBest()
		State.target = t
		if not t then return end
	end
	local part = partOf(t)
	if not part then State.target = nil return end

	local alpha = math.clamp(1 - (State.Smooth - 1) / 99, 0.01, 1) * dt * 60
	alpha = math.clamp(alpha, 0, 1)
	Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, part.Position), alpha)
end)

-- ── Keybinds ────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == State.ToggleKey then
		State.active = not State.active
		ToggleBtn.Text       = State.active and "Camlock: ON" or "Camlock: OFF"
		ToggleBtn.TextColor3 = State.active and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 90, 90)
		if not State.active then State.target = nil end
	elseif input.KeyCode == State.MenuKey then
		Frame.Visible = not Frame.Visible
	end
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = workspace.CurrentCamera
	State.target = nil
end)
