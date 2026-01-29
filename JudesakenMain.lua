--------------------------------------------------
-- SERVICES
--------------------------------------------------
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

--------------------------------------------------
-- SPRINT MODULE
--------------------------------------------------
local Sprint = require(game.ReplicatedStorage.Systems.Character.Game.Sprinting)

if Sprint.Init and not Sprint.DefaultsSet then
	pcall(function()
		Sprint:Init()
	end)
end

repeat task.wait() until Sprint.MaxStamina and Sprint.SprintSpeed

--------------------------------------------------
-- GUI BASE
--------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MainUI"
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 520, 0, 420) -- GUI MAIOR
Main.Position = UDim2.fromScale(0.5, 0.25)
Main.AnchorPoint = Vector2.new(0.5, 0)
Main.BackgroundColor3 = Color3.fromRGB(22,22,22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

--------------------------------------------------
-- TABS (CANTO SUPERIOR ESQUERDO)
--------------------------------------------------
local Tabs = Instance.new("Frame", Main)
Tabs.Size = UDim2.new(0, 140, 1, 0)
Tabs.BackgroundColor3 = Color3.fromRGB(18,18,18)
Tabs.BorderSizePixel = 0
Tabs.Position = UDim2.new(0, 6, 0, 6)

local TabLayout = Instance.new("UIListLayout", Tabs)
TabLayout.Padding = UDim.new(0, 6)

--------------------------------------------------
-- PAGES
--------------------------------------------------
local Pages = Instance.new("Frame", Main)
Pages.Position = UDim2.new(0, 150, 0, 10)
Pages.Size = UDim2.new(1, -160, 1, -20)
Pages.BackgroundTransparency = 1

local function CreatePage()
	local page = Instance.new("Frame", Pages)
	page.Size = UDim2.fromScale(1,1)
	page.BackgroundTransparency = 1
	page.Visible = false

	local layout = Instance.new("UIListLayout", page)
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local pad = Instance.new("UIPadding", page)
	pad.PaddingTop = UDim.new(0, 6)

	return page
end

local PrincipalPage = CreatePage()
local EspPage = CreatePage()

PrincipalPage.Visible = true

--------------------------------------------------
-- TAB BUTTON
--------------------------------------------------
local function CreateTab(text, page)
	local btn = Instance.new("TextButton", Tabs)
	btn.Size = UDim2.new(1, -10, 0, 40)
	btn.Position = UDim2.new(0, 5, 0, 0)
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 15
	btn.TextColor3 = Color3.new(1,1,1)
	btn.BackgroundColor3 = Color3.fromRGB(35,35,35)
	btn.AutoButtonColor = false
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	btn.MouseButton1Click:Connect(function()
		for _, p in ipairs(Pages:GetChildren()) do
			if p:IsA("Frame") then p.Visible = false end
		end
		page.Visible = true
	end)
end

CreateTab("Principal ⾕", PrincipalPage)
CreateTab("ESP", EspPage)

--------------------------------------------------
-- UI ELEMENTS (CORRIGIDO)
--------------------------------------------------
local function Toggle(parent, text, callback)
	local b = Instance.new("TextButton", parent)
	b.Size = UDim2.new(1, -10, 0, 42)
	b.BackgroundColor3 = Color3.fromRGB(40,40,40)
	b.Text = text .. " ☐"
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = Color3.new(1,1,1)
	Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)

	local on = false
	b.MouseButton1Click:Connect(function()
		on = not on
		b.Text = text .. " " .. (on and "☑" or "☐")
		callback(on)
	end)
end

local function Slider(parent, text, min, max, callback)
	local holder = Instance.new("Frame", parent)
	holder.Size = UDim2.new(1, -10, 0, 60)
	holder.BackgroundTransparency = 1

	local lbl = Instance.new("TextLabel", holder)
	lbl.Size = UDim2.new(1,0,0,24)
	lbl.Position = UDim2.new(0,0,0,0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text .. ": " .. tostring(min)
	lbl.TextColor3 = Color3.new(1,1,1)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 14
	lbl.TextXAlignment = Enum.TextXAlignment.Left -- <--- CORREÇÃO AQUI

	local bar = Instance.new("Frame", holder)
	bar.Position = UDim2.new(0,0,0,30)
	bar.Size = UDim2.new(1,0,0,18)
	bar.BackgroundColor3 = Color3.fromRGB(60,60,60)
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0,6)

	local fill = Instance.new("Frame", bar)
	fill.Size = UDim2.new(0.3,0,1,0)
	fill.BackgroundColor3 = Color3.fromRGB(0,170,255)
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0,6)

	local dragging = false

	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			local x = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			fill.Size = UDim2.new(x,0,1,0)
			local val = math.floor(min + (max-min)*x)
			lbl.Text = text .. ": " .. tostring(val)
			callback(val)
		end
	end)

	bar.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	game:GetService("UserInputService").InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local pos = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			fill.Size = UDim2.new(pos,0,1,0)
			local value = math.floor(min + (max-min)*pos)
			lbl.Text = text .. ": " .. tostring(value)
			callback(value)
		end
	end)
end

--------------------------------------------------
-- PRINCIPAL TAB CONTENT
--------------------------------------------------
Toggle(PrincipalPage, "INF Stamina", function(on)
	Sprint.StaminaLossDisabled = on
	if on then
		Sprint.Stamina = Sprint.MaxStamina
	end
end)

Slider(PrincipalPage, "Max Stamina", 50, 1000, function(v)
	Sprint.MaxStamina = v
end)

Slider(PrincipalPage, "Stamina Loss", 0, 50, function(v)
	Sprint.StaminaLoss = v
end)

Slider(PrincipalPage, "Stamina Gain", 0, 50, function(v)
	Sprint.StaminaGain = v
end)

--------------------------------------------------
-- ESP SYSTEM
--------------------------------------------------
local ESPEnabled = { Medkit=false, BloxyCola=false, Generator=false }
local ESPObjects = { Medkit={}, BloxyCola={}, Generator={} }

local function ClearESP(name)
	for _, v in ipairs(ESPObjects[name]) do
		if v and v.Parent then v:Destroy() end
	end
	ESPObjects[name] = {}
end

local function ApplyESP(obj, color, name)
	if not obj then return end
	local target = obj
	-- se passar Model, usa adornee; se passar Part/Handle, usa direto
	local hl = Instance.new("Highlight")
	if typeof(obj) == "Instance" and obj:IsA("Model") then
		hl.Adornee = obj
	else
		hl.Adornee = obj
	end
	hl.FillColor = color
	hl.FillTransparency = 0.4
	hl.OutlineColor = Color3.new(1,1,1)
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = workspace
	table.insert(ESPObjects[name], hl)
end

--------------------------------------------------
-- ITEM ESP (TOOLS)
--------------------------------------------------
local function ScanItems(item, color)
	ClearESP(item)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Tool") and d.Name == item then
			local target = d:FindFirstChild("Handle") or d
			ApplyESP(target, color, item)
		end
	end
end

workspace.DescendantAdded:Connect(function(d)
	if not d then return end
	if d:IsA("Tool") and ESPEnabled[d.Name] then
		if d.Name == "Medkit" then
			local t = d:FindFirstChild("Handle") or d
			ApplyESP(t, Color3.fromRGB(0,255,0), "Medkit")
		elseif d.Name == "BloxyCola" then
			local t = d:FindFirstChild("Handle") or d
			ApplyESP(t, Color3.fromRGB(255,0,0), "BloxyCola")
		end
	end
end)

--------------------------------------------------
-- GENERATOR ESP
--------------------------------------------------
local GenFolder = workspace:WaitForChild("Map"):WaitForChild("Ingame")

local function ScanGenerators()
	ClearESP("Generator")
	for _, g in ipairs(GenFolder:GetChildren()) do
		if g:IsA("Model") and g.Name == "Generator" then
			ApplyESP(g, Color3.fromRGB(255,255,0), "Generator")
		end
	end
end

GenFolder.ChildAdded:Connect(function(obj)
	if obj:IsA("Model") and obj.Name == "Generator" and ESPEnabled.Generator then
		ApplyESP(obj, Color3.fromRGB(255,255,0), "Generator")
	end
end)

--------------------------------------------------
-- ESP TAB CONTENT
--------------------------------------------------
Toggle(EspPage, "ESP Medkit", function(on)
	ESPEnabled.Medkit = on
	if on then ScanItems("Medkit", Color3.fromRGB(0,255,0)) else ClearESP("Medkit") end
end)

Toggle(EspPage, "ESP BloxyCola", function(on)
	ESPEnabled.BloxyCola = on
	if on then ScanItems("BloxyCola", Color3.fromRGB(255,0,0)) else ClearESP("BloxyCola") end
end)

Toggle(EspPage, "ESP Generator", function(on)
	ESPEnabled.Generator = on
	if on then ScanGenerators() else ClearESP("Generator") end
end)
