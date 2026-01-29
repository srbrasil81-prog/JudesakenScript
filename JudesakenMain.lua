-- Judesaken_Final_WithDebugger.lua
-- LocalScript -> StarterPlayer > StarterPlayerScripts
-- Versão final: TitleBar arrastável, abas Principal/ESP/Combat, ESP desligável, Minimize esconde abas, Debugger incluso

if _G.JudesakenLoaded then return end
_G.JudesakenLoaded = true

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestService = game:GetService("TestService")

local Player = Players.LocalPlayer
if not Player then
	warn("[JUDESAKEN] LocalPlayer not available. Run in Play (F5).")
	return
end
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- DEBUGGER
local Debugger = {
	GUI = false,
	StaminaModule = false,
	ESP_Items = false,
	ESP_Players = false,
	ESP_Generators = false,
	Controls = false
}
local function setDebug(name, value)
	if Debugger[name] ~= nil then Debugger[name] = (value == true) end
end

-- SAFE REQUIRE (sprinting module optional)
local Sprint
do
	local ok, mod = pcall(function()
		return require(game.ReplicatedStorage:WaitForChild("Systems"):WaitForChild("Character"):WaitForChild("Game"):WaitForChild("Sprinting"))
	end)
	if ok and mod then
		Sprint = mod
		pcall(function() if Sprint.Init and not Sprint.DefaultsSet then Sprint:Init() end end)
		-- short wait for values
		local t0 = tick()
		repeat task.wait() until (Sprint.MaxStamina and Sprint.SprintSpeed) or (tick() - t0 > 2)
		setDebug("StaminaModule", true)
	else
		-- stub so UI still works
		Sprint = {
			Stamina = 100,
			MaxStamina = 100,
			StaminaLoss = 10,
			StaminaGain = 20,
			SprintSpeed = 26
		}
		setDebug("StaminaModule", false)
	end
end

-- HELPERS
local function makeCorner(parent, r)
	local c = Instance.new("UICorner", parent)
	c.CornerRadius = UDim.new(0, r or 8)
	return c
end
local function safeDestroy(inst)
	if inst and inst.Parent then inst:Destroy() end
end
local function floor(n) return math.floor(n or 0) end

-- ESP storage + toggle state
local itemESP = {}    -- tool -> {hl, bill, label, part}
local playerESP = {}  -- model -> {hl, bill, label, part}
local genESP = {}     -- model -> hl
local toggles = {
	Medkit = false,
	BloxyCola = false,
	Survivors = false,
	Killers = false,
	Generators = false
}

-- BILLBOARD helper
local function makeBill(part, text, color)
	local bill = Instance.new("BillboardGui")
	bill.Name = "JudesakenBill"
	bill.Adornee = part
	bill.AlwaysOnTop = true
	bill.Size = UDim2.new(0, 160, 0, 36)
	bill.StudsOffset = Vector3.new(0, 2.2, 0)
	bill.Parent = part

	local lbl = Instance.new("TextLabel", bill)
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Text = text
	lbl.TextColor3 = color or Color3.new(1, 1, 1)
	lbl.TextStrokeTransparency = 0.5

	return bill, lbl
end

-- CREATE / DESTROY ITEM ESP
local function createItemESP(tool)
	if not tool or not tool:IsA("Tool") then return end
	if itemESP[tool] then return end
	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart") or tool
	if not handle then return end
	local ok, err = pcall(function()
		local hl = Instance.new("Highlight")
		hl.Name = "Judesaken_ItemHL"
		hl.Adornee = tool
		hl.FillColor = Color3.fromRGB(0, 200, 0)
		hl.FillTransparency = 0.5
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = tool

		local bill, lbl = makeBill(handle, "0m | " .. tostring(tool.Name), Color3.fromRGB(0, 200, 0))
		itemESP[tool] = { hl = hl, bill = bill, label = lbl, part = handle }
	end)
	if not ok then
		warn("[JUDESAKEN] createItemESP error:", err)
	end
end

local function destroyItemESP(tool)
	local d = itemESP[tool]
	if d then
		safeDestroy(d.bill)
		safeDestroy(d.hl)
		itemESP[tool] = nil
	end
end

-- CREATE / DESTROY PLAYER ESP
local function createPlayerESP(model, color)
	if not model or not model:IsA("Model") then return end
	if playerESP[model] then return end
	local attach = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
	if not attach then return end
	local ok, err = pcall(function()
		local hl = Instance.new("Highlight")
		hl.Name = "Judesaken_PlayerHL"
		hl.Adornee = model
		hl.FillColor = color
		hl.FillTransparency = 0.5
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = workspace

		local bill, lbl = makeBill(attach, "0m | " .. (model.Name or "Player"), color)
		playerESP[model] = { hl = hl, bill = bill, label = lbl, part = attach }
	end)
	if not ok then
		warn("[JUDESAKEN] createPlayerESP error:", err)
	end
end

local function destroyPlayerESP(model)
	local d = playerESP[model]
	if d then
		safeDestroy(d.bill)
		safeDestroy(d.hl)
		playerESP[model] = nil
	end
end

-- CREATE / DESTROY GENERATOR ESP
local function createGeneratorESP(model)
	if not model or not model:IsA("Model") then return end
	if genESP[model] then return end
	local ok, err = pcall(function()
		local hl = Instance.new("Highlight")
		hl.Name = "Judesaken_GenHL"
		hl.Adornee = model
		hl.FillColor = Color3.fromRGB(255, 200, 0)
		hl.FillTransparency = 0.45
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = workspace
		genESP[model] = hl
	end)
	if not ok then
		warn("[JUDESAKEN] createGeneratorESP error:", err)
	end
end

local function destroyGeneratorESP(model)
	if genESP[model] then
		safeDestroy(genESP[model])
		genESP[model] = nil
	end
end

-- CLEAR CATEGORY helper
local function clearCategory(cat)
	if cat == "Medkit" then
		for tool,_ in pairs(itemESP) do
			if tool and tool.Name == "Medkit" then destroyItemESP(tool) end
		end
	elseif cat == "BloxyCola" then
		for tool,_ in pairs(itemESP) do
			if tool and tool.Name == "BloxyCola" then destroyItemESP(tool) end
		end
	elseif cat == "Survivors" then
		for model,_ in pairs(playerESP) do
			if model and tostring(model.Name):lower():find("survivor") then destroyPlayerESP(model) end
		end
	elseif cat == "Killers" then
		for model,_ in pairs(playerESP) do
			if model and tostring(model.Name):lower():find("killer") then destroyPlayerESP(model) end
		end
	elseif cat == "Generators" then
		for model,_ in pairs(genESP) do destroyGeneratorESP(model) end
	end
end

-- DYNAMIC DETECTION (spawn/despawn) respeitando toggles
workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("Tool") then
		if obj.Name == "Medkit" and toggles.Medkit then createItemESP(obj) end
		if obj.Name == "BloxyCola" and toggles.BloxyCola then createItemESP(obj) end
	end
	if obj:IsA("Model") then
		if obj.Name == "Generator" and toggles.Generators then createGeneratorESP(obj) end
		local p = obj.Parent
		if p and p.Name == "Survivors" and toggles.Survivors then createPlayerESP(obj, Color3.fromRGB(0,170,255)) end
		if p and p.Name == "Killers" and toggles.Killers then createPlayerESP(obj, Color3.fromRGB(255,70,70)) end
	end
end)

workspace.DescendantRemoving:Connect(function(obj)
	if obj:IsA("Tool") and itemESP[obj] then destroyItemESP(obj) end
	if obj:IsA("Model") then
		if playerESP[obj] then destroyPlayerESP(obj) end
		if genESP[obj] then destroyGeneratorESP(obj) end
	end
end)

-- -----------------------------
-- GUI (clean & consistent)
-- -----------------------------
local SG = Instance.new("ScreenGui")
SG.Name = "JudesakenUI"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = PlayerGui

-- Main window
local Main = Instance.new("Frame", SG)
Main.Name = "Main"
Main.Size = UDim2.new(0, 700, 0, 520)
Main.Position = UDim2.new(0.5, 0, 0.12, 0)
Main.AnchorPoint = Vector2.new(0.5, 0)
Main.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
makeCorner(Main, 12)
Main.ZIndex = 1

-- TitleBar (drag only)
local TitleBar = Instance.new("Frame", Main)
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.Position = UDim2.new(0, 0, 0, 0)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
makeCorner(TitleBar, 8)
TitleBar.ZIndex = 20

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size = UDim2.new(1, -140, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Judesaken"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 18
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 21

local BtnMin = Instance.new("TextButton", TitleBar)
BtnMin.Size = UDim2.new(0, 40, 1, 0)
BtnMin.Position = UDim2.new(1, -88, 0, 0)
BtnMin.Text = "–"
makeCorner(BtnMin, 6)
BtnMin.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
BtnMin.ZIndex = 21

local BtnClose = Instance.new("TextButton", TitleBar)
BtnClose.Size = UDim2.new(0, 40, 1, 0)
BtnClose.Position = UDim2.new(1, -44, 0, 0)
BtnClose.Text = "X"
makeCorner(BtnClose, 6)
BtnClose.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
BtnClose.ZIndex = 21

-- Tabs (left)
local TabsFrame = Instance.new("Frame", Main)
TabsFrame.Size = UDim2.new(0, 180, 1, -64)
TabsFrame.Position = UDim2.new(0, 12, 0, 52)
TabsFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
makeCorner(TabsFrame, 8)
TabsFrame.ZIndex = 12

local TabsLayout = Instance.new("UIListLayout", TabsFrame)
TabsLayout.Padding = UDim.new(0, 10)
local TabsPad = Instance.new("UIPadding", TabsFrame)
TabsPad.PaddingTop = UDim.new(0, 12)
TabsPad.PaddingLeft = UDim.new(0, 8)

-- Pages (right)
local Pages = Instance.new("Frame", Main)
Pages.Size = UDim2.new(1, -212, 1, -64)
Pages.Position = UDim2.new(0, 200, 0, 52)
Pages.BackgroundTransparency = 1
Pages.ZIndex = 12

local function newPage()
	local p = Instance.new("Frame", Pages)
	p.Size = UDim2.new(1, 0, 1, 0)
	p.BackgroundTransparency = 1
	p.Visible = false
	p.ZIndex = 13

	local scroll = Instance.new("ScrollingFrame", p)
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	pcall(function() scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 140, 255) end)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 14

	local layout = Instance.new("UIListLayout", scroll)
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local pad = Instance.new("UIPadding", scroll)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)

	return p, scroll
end

local PagePrincipal, ScrollPrincipal = newPage()
local PageESP, ScrollESP = newPage()
local PageCombat, ScrollCombat = newPage()
PagePrincipal.Visible = true

-- Tab creator
local function makeTab(name, page)
	local b = Instance.new("TextButton", TabsFrame)
	b.Size = UDim2.new(1, -16, 0, 44)
	b.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.Text = name
	makeCorner(b, 8)
	b.ZIndex = 13
	b.MouseButton1Click:Connect(function()
		for _, c in ipairs(Pages:GetChildren()) do
			if c:IsA("Frame") then c.Visible = false end
		end
		page.Visible = true
	end)
	return b
end

local TabPrincipal = makeTab("Principal ⾕", PagePrincipal)
local TabESP = makeTab("ESP", PageESP)
local TabCombat = makeTab("Combat", PageCombat)

-- UI element creators
local function CreateLabel(scroll, text)
	local label = Instance.new("TextLabel", scroll)
	label.Size = UDim2.new(0, 520, 0, 28)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(0, 170, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 14
	return label
end

local function CreateToggle(scroll, text, callback)
	local btn = Instance.new("TextButton", scroll)
	btn.Size = UDim2.new(0, 520, 0, 40)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 15
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Text = text .. " ☐"
	makeCorner(btn, 8)
	btn.ZIndex = 15
	local state = false
	btn.MouseButton1Click:Connect(function()
		state = not state
		btn.Text = text .. (state and " ☑" or " ☐")
		pcall(function() callback(state) end)
	end)
	return btn
end

local function CreateSlider(scroll, text, default, min, max, callback)
	local holder = Instance.new("Frame", scroll)
	holder.Size = UDim2.new(0, 520, 0, 68)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 14

	local label = Instance.new("TextLabel", holder)
	label.Size = UDim2.new(1, 0, 0, 22)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text .. ": " .. tostring(default)

	local bar = Instance.new("Frame", holder)
	bar.Position = UDim2.new(0, 0, 0, 30)
	bar.Size = UDim2.new(1, 0, 0, 18)
	bar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	makeCorner(bar, 8)
	bar.ZIndex = 14

	local frac = 0
	if max > min then frac = (default - min) / (max - min) end
	local fill = Instance.new("Frame", bar)
	fill.Size = UDim2.new(frac, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
	makeCorner(fill, 8)
	fill.ZIndex = 15

	local dragging = false
	local function updateFromInput(input)
		local x = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		fill.Size = UDim2.new(x, 0, 1, 0)
		local val = floor(min + (max - min) * x)
		label.Text = text .. ": " .. tostring(val)
		pcall(function() callback(val) end)
	end

	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			updateFromInput(i)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then updateFromInput(i) end
	end)

	return holder
end

local function CreateBox(scroll, text, default, callback)
	local box = Instance.new("TextBox", scroll)
	box.Size = UDim2.new(0, 520, 0, 40)
	box.Text = text .. ": " .. tostring(default)
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Font = Enum.Font.Gotham
	box.TextSize = 14
	box.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	makeCorner(box, 8)
	box.ZIndex = 14
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text:match("%-?%d+"))
		if n then pcall(function() callback(n) end) end
	end)
	return box
end

-- PRINCIPAL PAGE CONTROLS (hooked to Sprint module safely)
local okControls, errControls = pcall(function()
	CreateToggle(ScrollPrincipal, "INF Stamina", function(on)
		pcall(function() Sprint.StaminaLossDisabled = on end)
		if on then pcall(function() Sprint.Stamina = Sprint.MaxStamina end) end
	end)
	CreateSlider(ScrollPrincipal, "Max Stamina", Sprint.MaxStamina or 100, 50, 2000, function(v) pcall(function() Sprint.MaxStamina = v end) end)
	CreateSlider(ScrollPrincipal, "Stamina Loss", Sprint.StaminaLoss or 10, 0, 100, function(v) pcall(function() Sprint.StaminaLoss = v end) end)
	CreateSlider(ScrollPrincipal, "Stamina Gain", Sprint.StaminaGain or 20, 0, 100, function(v) pcall(function() Sprint.StaminaGain = v end) end)
	CreateBox(ScrollPrincipal, "Speed Sprint", Sprint.SprintSpeed or 26, function(v) pcall(function() Sprint.SprintSpeed = v end) end)
	setDebug("Controls", true)
end)
if not okControls then
	warn("[JUDESAKEN] Controls error:", errControls)
	setDebug("Controls", false)
end

-- ESP PAGE (exact structure requested)
CreateLabel(ScrollESP, "Items Esp")
CreateToggle(ScrollESP, "Medkit Esp", function(on)
	toggles.Medkit = on
	if on then
		-- scan workspace
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Tool") and obj.Name == "Medkit" then createItemESP(obj) end
		end
		-- also check ReplicatedStorage Assets
		pcall(function()
			local assets = ReplicatedStorage:FindFirstChild("Assets")
			if assets and assets:FindFirstChild("Items") then
				local f = assets.Items:FindFirstChild("Medkit")
				if f then
					for _, t in ipairs(f:GetChildren()) do if t:IsA("Tool") then createItemESP(t) end end
				end
			end
		end)
		setDebug("ESP_Items", true)
	else
		clearCategory("Medkit")
		setDebug("ESP_Items", false)
	end
end)

CreateToggle(ScrollESP, "BloxyCola Esp", function(on)
	toggles.BloxyCola = on
	if on then
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Tool") and obj.Name == "BloxyCola" then createItemESP(obj) end
		end
		pcall(function()
			local assets = ReplicatedStorage:FindFirstChild("Assets")
			if assets and assets:FindFirstChild("Items") then
				local f = assets.Items:FindFirstChild("BloxyCola")
				if f then
					for _, t in ipairs(f:GetChildren()) do if t:IsA("Tool") then createItemESP(t) end end
				end
			end
		end)
		setDebug("ESP_Items", true)
	else
		clearCategory("BloxyCola")
		setDebug("ESP_Items", false)
	end
end)

CreateLabel(ScrollESP, "Survivors/Killers Esp")
CreateToggle(ScrollESP, "Survivors Esp", function(on)
	toggles.Survivors = on
	if on then
		local folder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
		if folder then
			for _, m in ipairs(folder:GetChildren()) do if m:IsA("Model") then createPlayerESP(m, Color3.fromRGB(0,170,255)) end end
		end
		setDebug("ESP_Players", true)
	else
		clearCategory("Survivors")
		setDebug("ESP_Players", false)
	end
end)

CreateToggle(ScrollESP, "Killers Esp", function(on)
	toggles.Killers = on
	if on then
		local folder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
		if folder then
			for _, m in ipairs(folder:GetChildren()) do if m:IsA("Model") then createPlayerESP(m, Color3.fromRGB(255,70,70)) end end
		end
		setDebug("ESP_Players", true)
	else
		clearCategory("Killers")
		setDebug("ESP_Players", false)
	end
end)

CreateLabel(ScrollESP, "Generators Esp")
CreateToggle(ScrollESP, "Generators Esp", function(on)
	toggles.Generators = on
	if on then
		local ok, folder = pcall(function() return workspace:WaitForChild("Map"):WaitForChild("Ingame") end)
		if ok and folder then
			for _, g in ipairs(folder:GetChildren()) do if g:IsA("Model") and g.Name == "Generator" then createGeneratorESP(g) end end
		end
		setDebug("ESP_Generators", true)
	else
		clearCategory("Generators")
		setDebug("ESP_Generators", false)
	end
end)

-- Combat placeholder
CreateLabel(ScrollCombat, "Combat (placeholder)")

-- UPDATE distances + cleanup
RunService.RenderStepped:Connect(function()
	local camPos = Camera and Camera.CFrame.Position or workspace.CurrentCamera.CFrame.Position
	for tool, data in pairs(itemESP) do
		if tool and tool.Parent and data.part and data.label then
			local dist = floor((camPos - data.part.Position).Magnitude)
			data.label.Text = tostring(dist) .. "m | " .. tostring(tool.Name)
		else
			if itemESP[tool] then destroyItemESP(tool) end
		end
	end
	for model, data in pairs(playerESP) do
		if model and model.Parent and data.part and data.label then
			local dist = floor((camPos - data.part.Position).Magnitude)
			data.label.Text = tostring(dist) .. "m | " .. tostring(model.Name)
		else
			if playerESP[model] then destroyPlayerESP(model) end
		end
	end
end)

-- TitleBar drag only (so sliders still work)
do
	local dragging, dragStart, startPos = false, Vector2.new(), UDim2.new()
	TitleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = Main.Position
		end
	end)
	TitleBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- Minimize (hides TabsFrame + Pages) and restore
local originalSize = Main.Size
local minimized = false
BtnMin.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		TweenService:Create(Main, TweenInfo.new(0.22), { Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 44) }):Play()
		task.delay(0.22, function()
			TabsFrame.Visible = false
			Pages.Visible = false
		end)
	else
		TabsFrame.Visible = true
		Pages.Visible = true
		TweenService:Create(Main, TweenInfo.new(0.22), { Size = originalSize }):Play()
	end
end)

BtnClose.MouseButton1Click:Connect(function()
	SG:Destroy()
end)

-- Floating toggle button (open/close), draggable + keyboard RightControl
local FlyBtn = Instance.new("TextButton", SG)
FlyBtn.Name = "JudesakenFlyToggle"
FlyBtn.AnchorPoint = Vector2.new(1, 1)
FlyBtn.Size = UDim2.new(0, 56, 0, 56)
FlyBtn.Position = UDim2.new(1, -18, 1, -18)
FlyBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
FlyBtn.Text = "GUI"
FlyBtn.Font = Enum.Font.GothamBold
FlyBtn.TextSize = 14
makeCorner(FlyBtn, 28)
FlyBtn.ZIndex = 200
FlyBtn.Active = true
FlyBtn.Draggable = true

local guiOpen = true
local function setGUIVisible(v)
	if v == guiOpen then return end
	guiOpen = v
	if v then
		Main.Visible = true
		TweenService:Create(Main, TweenInfo.new(0.18), { Size = originalSize }):Play()
	else
		TweenService:Create(Main, TweenInfo.new(0.18), { Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 44) }):Play()
		task.delay(0.2, function() Main.Visible = false end)
	end
end

FlyBtn.MouseButton1Click:Connect(function()
	setGUIVisible(not guiOpen)
end)
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		setGUIVisible(not guiOpen)
	end
end)

-- Final Debug summary via TestService
local function debugSummary()
	local msg = "| GUI: " .. tostring(Debugger.GUI)
		.. " | StaminaModule: " .. tostring(Debugger.StaminaModule)
		.. " | ESP_Items: " .. tostring(Debugger.ESP_Items)
		.. " | ESP_Players: " .. tostring(Debugger.ESP_Players)
		.. " | ESP_Generators: " .. tostring(Debugger.ESP_Generators)
		.. " | Controls: " .. tostring(Debugger.Controls) .. " |"
	print("[JUDESAKEN DEBUG] " .. msg)
	pcall(function() TestService:Message("[JUDESAKEN] " .. msg) end)
end

setDebug("GUI", true)
task.delay(0.8, debugSummary)

-- Pronto
print("[JUDESAKEN] Script carregado — abas Principal e ESP ativas (desligadas por padrão), Debugger incluído.")
