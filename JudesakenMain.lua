-- JudesakenFullWithDebugger.lua
-- LocalScript -> StarterPlayer > StarterPlayerScripts
-- Features: GUI + Sliders + Toggles + ESP (items, generators, players) + Debugger summary via TestService

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TestService = game:GetService("TestService")

local Player = Players.LocalPlayer
if not Player then
	warn("LocalPlayer not available. Run in Play (F5).")
	return
end
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- Debugger table (all start false)
local Debugger = {
	GUI = false,
	Stamina = false,
	ESP = false,
	ItemsESP = false,
	PlayersESP = false,
	GeneratorsESP = false,
	Sliders = false,
	Buttons = false
}
local function setDebug(name, val)
	if Debugger[name] ~= nil then Debugger[name] = (val == true) end
end

-- safe require Sprint module (optional)
local Sprint
do
	local ok, mod = pcall(function()
		return require(game.ReplicatedStorage:WaitForChild("Systems"):WaitForChild("Character"):WaitForChild("Game"):WaitForChild("Sprinting"))
	end)
	if ok and mod then
		Sprint = mod
		pcall(function()
			if Sprint.Init and not Sprint.DefaultsSet then Sprint:Init() end
		end)
		-- wait a little for values (non-blocking small wait)
		local t0 = tick()
		repeat task.wait() until (Sprint.MaxStamina and Sprint.SprintSpeed) or (tick() - t0 > 2)
		setDebug("Stamina", true)
	else
		-- stub so UI/controls won't break if module absent
		Sprint = {
			Stamina = 100,
			MaxStamina = 100,
			StaminaLoss = 10,
			StaminaGain = 20,
			SprintSpeed = 26
		}
		setDebug("Stamina", false) -- module missing
	end
end

-- Helpers
local function makeCorner(obj, r) local c = Instance.new("UICorner", obj); c.CornerRadius = UDim.new(0, r or 8); return c end
local function safeDestroy(inst) if inst and inst.Parent then inst:Destroy() end end
local function floor(n) return math.floor(n or 0) end

-- Build GUI (wrapped in pcall to mark debug)
local buildOk, buildErr = pcall(function()
	-- ScreenGui
	local SG = Instance.new("ScreenGui")
	SG.Name = "JudesakenFullUI"
	SG.ResetOnSpawn = false
	SG.Parent = PlayerGui

	-- Main
	local Main = Instance.new("Frame", SG)
	Main.Name = "Main"
	Main.Size = UDim2.new(0, 640, 0, 500)
	Main.Position = UDim2.new(0.5, 0, 0.12, 0)
	Main.AnchorPoint = Vector2.new(0.5, 0)
	Main.BackgroundColor3 = Color3.fromRGB(22,22,22)
	Main.BorderSizePixel = 0
	makeCorner(Main, 12)
	Main.ZIndex = 2

	-- TitleBar
	local TitleBar = Instance.new("Frame", Main)
	TitleBar.Name = "TitleBar"
	TitleBar.Size = UDim2.new(1, 0, 0, 44)
	TitleBar.Position = UDim2.new(0, 0, 0, 0)
	TitleBar.BackgroundColor3 = Color3.fromRGB(18,18,18)
	makeCorner(TitleBar, 8)

	local TitleLabel = Instance.new("TextLabel", TitleBar)
	TitleLabel.Size = UDim2.new(1, -140, 1, 0)
	TitleLabel.Position = UDim2.new(0, 12, 0, 0)
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.Text = "Judesaken"
	TitleLabel.TextColor3 = Color3.fromRGB(255,255,255)
	TitleLabel.Font = Enum.Font.GothamBold
	TitleLabel.TextSize = 18
	TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

	local BtnMin = Instance.new("TextButton", TitleBar)
	BtnMin.Size = UDim2.new(0, 40, 1, 0); BtnMin.Position = UDim2.new(1, -88, 0, 0)
	BtnMin.Text = "–"; BtnMin.Font = Enum.Font.GothamBold; BtnMin.TextSize = 20
	BtnMin.BackgroundColor3 = Color3.fromRGB(35,35,35); makeCorner(BtnMin, 6)

	local BtnClose = Instance.new("TextButton", TitleBar)
	BtnClose.Size = UDim2.new(0, 40, 1, 0); BtnClose.Position = UDim2.new(1, -44, 0, 0)
	BtnClose.Text = "X"; BtnClose.Font = Enum.Font.GothamBold; BtnClose.TextSize = 18
	BtnClose.TextColor3 = Color3.fromRGB(255,80,80); BtnClose.BackgroundColor3 = Color3.fromRGB(35,35,35)
	makeCorner(BtnClose, 6)

	-- Confirm overlay
	local Confirm = Instance.new("Frame", SG)
	Confirm.Size = UDim2.new(1,0,1,0); Confirm.BackgroundColor3 = Color3.new(0,0,0)
	Confirm.BackgroundTransparency = 0.45; Confirm.Visible = false; Confirm.ZIndex = 50
	local ConfirmBox = Instance.new("Frame", Confirm)
	ConfirmBox.Size = UDim2.new(0, 360, 0, 150); ConfirmBox.AnchorPoint = Vector2.new(0.5,0.5)
	ConfirmBox.Position = UDim2.new(0.5,0,0.5,0); ConfirmBox.BackgroundColor3 = Color3.fromRGB(30,30,30); makeCorner(ConfirmBox, 10)
	local ConfirmLabel = Instance.new("TextLabel", ConfirmBox)
	ConfirmLabel.Size = UDim2.new(1, -20, 0, 86); ConfirmLabel.Position = UDim2.new(0,10,0,8)
	ConfirmLabel.BackgroundTransparency = 1; ConfirmLabel.Text = "Deseja realmente fechar?"
	ConfirmLabel.Font = Enum.Font.GothamBold; ConfirmLabel.TextSize = 18; ConfirmLabel.TextColor3 = Color3.new(1,1,1)
	ConfirmLabel.TextWrapped = true; ConfirmLabel.TextXAlignment = Enum.TextXAlignment.Center; ConfirmLabel.TextYAlignment = Enum.TextYAlignment.Center
	local ConfirmYes = Instance.new("TextButton", ConfirmBox)
	ConfirmYes.Size = UDim2.new(0.4,0,0,36); ConfirmYes.Position = UDim2.new(0.06,0,0.72,0); ConfirmYes.Text = "Sim"; ConfirmYes.Font = Enum.Font.GothamBold; ConfirmYes.BackgroundColor3 = Color3.fromRGB(255,70,70); makeCorner(ConfirmYes,8)
	local ConfirmNo = Instance.new("TextButton", ConfirmBox)
	ConfirmNo.Size = UDim2.new(0.4,0,0,36); ConfirmNo.Position = UDim2.new(0.54,0,0.72,0); ConfirmNo.Text = "Não"; ConfirmNo.Font = Enum.Font.GothamBold; ConfirmNo.BackgroundColor3 = Color3.fromRGB(70,70,70); makeCorner(ConfirmNo,8)

	-- Left tabs
	local TabsFrame = Instance.new("Frame", Main)
	TabsFrame.Size = UDim2.new(0, 180, 1, -64); TabsFrame.Position = UDim2.new(0, 12, 0, 52)
	TabsFrame.BackgroundColor3 = Color3.fromRGB(18,18,18); makeCorner(TabsFrame, 8)
	local TabsLayout = Instance.new("UIListLayout", TabsFrame); TabsLayout.Padding = UDim.new(0,10)
	local TabsPad = Instance.new("UIPadding", TabsFrame); TabsPad.PaddingTop = UDim.new(0,12); TabsPad.PaddingLeft = UDim.new(0,8)

	-- Pages (right)
	local Pages = Instance.new("Frame", Main)
	Pages.Size = UDim2.new(1, -212, 1, -64); Pages.Position = UDim2.new(0, 200, 0, 52); Pages.BackgroundTransparency = 1

	local function newPage()
		local p = Instance.new("Frame", Pages); p.Size = UDim2.new(1,0,1,0); p.BackgroundTransparency = 1; p.Visible = false
		local scroll = Instance.new("ScrollingFrame", p)
		scroll.Size = UDim2.new(1,0,1,0); scroll.BackgroundTransparency = 1; scroll.ScrollBarThickness = 6
		pcall(function() scroll.ScrollBarImageColor3 = Color3.fromRGB(0,140,255) end)
		scroll.ScrollBarImageTransparency = 0; scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		local layout = Instance.new("UIListLayout", scroll); layout.Padding = UDim.new(0,8); layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local pad = Instance.new("UIPadding", scroll); pad.PaddingTop = UDim.new(0,8); pad.PaddingLeft = UDim.new(0,6); pad.PaddingRight = UDim.new(0,6)
		return p, scroll
	end

	local PagePrincipal, ScrollPrincipal = newPage()
	local PageESP, ScrollESP = newPage()
	PagePrincipal.Visible = true

	-- Tab btn helper
	local function makeTabButton(name, page)
		local b = Instance.new("TextButton", TabsFrame)
		b.Size = UDim2.new(1, -16, 0, 44)
		b.BackgroundColor3 = Color3.fromRGB(40,40,40); b.TextColor3 = Color3.new(1,1,1)
		b.Font = Enum.Font.GothamBold; b.TextSize = 16; b.Text = name
		makeCorner(b, 8)
		b.MouseButton1Click:Connect(function()
			for _, c in ipairs(Pages:GetChildren()) do if c:IsA("Frame") then c.Visible = false end end
			page.Visible = true
		end)
		return b
	end

	local TabMainBtn = makeTabButton("Principal ⾕", PagePrincipal)
	local TabESPBtn = makeTabButton("ESP", PageESP)

	-- UI creators
	local function CreateToggle(parent, text, callback)
		local btn = Instance.new("TextButton", parent)
		btn.Size = UDim2.new(0, 520, 0, 44)
		btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
		btn.Font = Enum.Font.GothamBold; btn.TextSize = 15; btn.TextColor3 = Color3.new(1,1,1)
		btn.Text = text .. " ☐"
		makeCorner(btn, 8)
		local on = false
		btn.MouseButton1Click:Connect(function()
			on = not on
			btn.Text = text .. " " .. (on and "☑" or "☐")
			callback(on)
		end)
		return btn
	end

	local function CreateSlider(parent, text, default, min, max, callback)
		local holder = Instance.new("Frame", parent)
		holder.Size = UDim2.new(0, 520, 0, 68); holder.BackgroundTransparency = 1
		local label = Instance.new("TextLabel", holder)
		label.Size = UDim2.new(1, 0, 0, 22); label.Position = UDim2.new(0,0,0,0)
		label.BackgroundTransparency = 1; label.Font = Enum.Font.Gotham; label.TextSize = 14; label.TextColor3 = Color3.new(1,1,1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = text .. ": " .. tostring(default)
		local bar = Instance.new("Frame", holder); bar.Position = UDim2.new(0,0,0,30); bar.Size = UDim2.new(1,0,0,18); bar.BackgroundColor3 = Color3.fromRGB(60,60,60)
		makeCorner(bar, 8)
		local frac = 0
		if max > min then frac = (default - min) / (max - min) end
		local fill = Instance.new("Frame", bar); fill.Size = UDim2.new(frac,0,1,0); fill.BackgroundColor3 = Color3.fromRGB(0,140,255); makeCorner(fill, 8)

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
		UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
		UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then updateFromInput(i) end end)

		return holder
	end

	local function CreateBox(parent, text, default, callback)
		local box = Instance.new("TextBox", parent)
		box.Size = UDim2.new(0, 520, 0, 40)
		box.Text = text .. ": " .. tostring(default)
		box.ClearTextOnFocus = false
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.Font = Enum.Font.Gotham; box.TextSize = 14
		box.BackgroundColor3 = Color3.fromRGB(45,45,45)
		makeCorner(box, 8)
		box.FocusLost:Connect(function()
			local n = tonumber(box.Text:match("%-?%d+"))
			if n then pcall(function() callback(n) end) end
		end)
		return box
	end

	-- Principal content
	local createButtonsOk, createButtonsErr = pcall(function()
		local infToggle = CreateToggle(ScrollPrincipal, "INF Stamina", function(on)
			pcall(function() Sprint.StaminaLossDisabled = on end)
			if on then pcall(function() Sprint.Stamina = Sprint.MaxStamina end) end
		end)
		local sMax = CreateSlider(ScrollPrincipal, "Max Stamina", Sprint.MaxStamina or 100, 50, 2000, function(v) pcall(function() Sprint.MaxStamina = v end) end)
		local sLoss = CreateSlider(ScrollPrincipal, "Stamina Loss", Sprint.StaminaLoss or 10, 0, 100, function(v) pcall(function() Sprint.StaminaLoss = v end) end)
		local sGain = CreateSlider(ScrollPrincipal, "Stamina Gain", Sprint.StaminaGain or 20, 0, 100, function(v) pcall(function() Sprint.StaminaGain = v end) end)
		local sSpeed = CreateBox(ScrollPrincipal, "Speed Sprint", Sprint.SprintSpeed or 26, function(v) pcall(function() Sprint.SprintSpeed = v end) end)
		setDebug("Buttons", true)
		setDebug("Sliders", true)
	end)
	if not createButtonsOk then
		warn("Erro criando botões/controls:", createButtonsErr)
		setDebug("Buttons", false)
		setDebug("Sliders", false)
	end

	-- keep INF stamina when toggled (safe)
	task.spawn(function()
		while task.wait(0.12) do
			local ok, val = pcall(function()
				-- check first INF toggle label existence
				for _, c in ipairs(ScrollPrincipal:GetChildren()) do
					if c:IsA("TextButton") and c.Text:find("INF Stamina") and c.Text:find("☑") then
						return true
					end
				end
				return false
			end)
			if ok and val then
				pcall(function() Sprint.Stamina = Sprint.MaxStamina end)
			end
		end
	end)

	-- ESP system (wrapped)
	local espOk, espErr = pcall(function()
		-- data stores
		local itemNames = { Medkit = true, BloxyCola = true }
		local itemESP = {}     -- tool -> {billboard, label, highlight, handle}
		local generatorESP = {}-- model -> highlight
		local playerESP = {}   -- model -> {highlight, billboard, label, part}

		-- helper to create billboard text
		local function makeBill(handlePart, initialText, color)
			local bill = Instance.new("BillboardGui")
			bill.Name = "JudesakenBill"
			bill.Adornee = handlePart
			bill.AlwaysOnTop = true
			bill.Size = UDim2.new(0, 180, 0, 40)
			bill.StudsOffset = Vector3.new(0, 2.2, 0)
			bill.Parent = handlePart

			local lbl = Instance.new("TextLabel", bill)
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamBold
			lbl.TextScaled = true
			lbl.Text = initialText
			lbl.TextColor3 = color or Color3.new(1,1,1)
			lbl.TextStrokeTransparency = 0.5
			return bill, lbl
		end

		-- item ESP create/remove
		local function createItemESP(tool)
			if not tool or not tool:IsA("Tool") then return end
			if itemESP[tool] then return end
			local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart") or tool
			if not handle then return end
			local hl = Instance.new("Highlight")
			hl.Name = "JudesakenItemHL"; hl.Adornee = tool
			hl.FillColor = Color3.fromRGB(0,200,0); hl.FillTransparency = 0.5; hl.OutlineColor = Color3.new(1,1,1)
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = tool
			local bill, lbl = makeBill(handle, "0m | "..tool.Name, Color3.fromRGB(0,200,0))
			itemESP[tool] = {billboard = bill, label = lbl, highlight = hl, handle = handle}
		end

		local function removeItemESP(tool)
			local d = itemESP[tool]
			if d then safeDestroy(d.billboard); safeDestroy(d.highlight); itemESP[tool] = nil end
		end

		-- scan existing tools
		for _, o in ipairs(workspace:GetDescendants()) do
			if o:IsA("Tool") and itemNames[o.Name] then createItemESP(o) end
		end

		-- react to tool adds/removes
		workspace.DescendantAdded:Connect(function(d)
			if d:IsA("Tool") and itemNames[d.Name] then task.wait(0.05); createItemESP(d) end
		end)
		workspace.DescendantRemoving:Connect(function(d)
			if d:IsA("Tool") and itemESP[d] then removeItemESP(d) end
		end)

		-- Generator ESP
		local genFolder
		pcall(function() genFolder = workspace:WaitForChild("Map"):WaitForChild("Ingame") end)
		local function createGenESP(model)
			if not model or not model:IsA("Model") then return end
			if generatorESP[model] then return end
			local hl = Instance.new("Highlight")
			hl.Name = "JudesakenGenHL"; hl.Adornee = model
			hl.FillColor = Color3.fromRGB(255,200,0); hl.FillTransparency = 0.45; hl.OutlineColor = Color3.new(1,1,1)
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = workspace
			generatorESP[model] = hl
		end
		local function removeGenESP(model) if generatorESP[model] then safeDestroy(generatorESP[model]); generatorESP[model] = nil end end
		if genFolder then
			for _, g in ipairs(genFolder:GetChildren()) do if g:IsA("Model") and g.Name == "Generator" then createGenESP(g) end end
			genFolder.ChildAdded:Connect(function(c) if c:IsA("Model") and c.Name == "Generator" then createGenESP(c) end end)
			genFolder.ChildRemoved:Connect(removeGenESP)
		end

		-- Players ESP (Survivors / Killers folders)
		local playersFolder = workspace:FindFirstChild("Players")
		local survivorsFolder = playersFolder and playersFolder:FindFirstChild("Survivors")
		local killersFolder = playersFolder and playersFolder:FindFirstChild("Killers")

		local function createPlayerESP(model, color)
			if not model or not model:IsA("Model") then return end
			if playerESP[model] then return end
			local hl = Instance.new("Highlight"); hl.Name = "JudesakenPlayerHL"
			hl.Adornee = model; hl.FillColor = color; hl.FillTransparency = 0.5; hl.OutlineColor = Color3.new(1,1,1)
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = workspace
			local attachPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
			local bill, lbl
			if attachPart then bill, lbl = makeBill(attachPart, "0m | " .. (model.Name or "Player"), color) end
			playerESP[model] = { highlight = hl, billboard = bill, label = lbl, part = attachPart }
		end

		local function removePlayerESP(model)
			local d = playerESP[model]; if d then safeDestroy(d.highlight); safeDestroy(d.billboard); playerESP[model] = nil end
		end

		if survivorsFolder then
			for _, s in ipairs(survivorsFolder:GetChildren()) do if s:IsA("Model") then createPlayerESP(s, Color3.fromRGB(0,170,255)) end end
			survivorsFolder.ChildAdded:Connect(function(c) if c:IsA("Model") then createPlayerESP(c, Color3.fromRGB(0,170,255)) end end)
			survivorsFolder.ChildRemoved:Connect(removePlayerESP)
		end
		if killersFolder then
			for _, k in ipairs(killersFolder:GetChildren()) do if k:IsA("Model") then createPlayerESP(k, Color3.fromRGB(255,70,70)) end end
			killersFolder.ChildAdded:Connect(function(c) if c:IsA("Model") then createPlayerESP(c, Color3.fromRGB(255,70,70)) end end)
			killersFolder.ChildRemoved:Connect(removePlayerESP)
		end

		-- Update distances in RenderStepped
		RunService.RenderStepped:Connect(function()
			local camPos = (Camera and Camera.CFrame.Position) or workspace.CurrentCamera.CFrame.Position
			-- update items
			for tool, data in pairs(itemESP) do
				if tool and tool.Parent and data.handle and data.label then
					local dist = floor((camPos - data.handle.Position).Magnitude)
					data.label.Text = tostring(dist) .. "m | " .. tostring(tool.Name)
				else
					if itemESP[tool] then removeItemESP(tool) end
				end
			end
			-- players
			for model, data in pairs(playerESP) do
				if model and model.Parent and data.part and data.label then
					local dist = floor((camPos - data.part.Position).Magnitude)
					local displayName = (model.Name or "Player")
					data.label.Text = tostring(dist) .. "m | " .. displayName
				else
					if playerESP[model] then removePlayerESP(model) end
				end
			end
		end)

		-- Expose creators to outer scope by storing in SG for toggles (attach to SG so closures accessible)
		SG:SetAttribute("Judesaken_itemESP", true) -- marker
		-- save local tables to SG for possible external debug (not required)
		SG:SetAttribute("Judesaken_meta", "esp-ready")
		setDebug("ItemsESP", true)
		setDebug("GeneratorsESP", true)
		setDebug("PlayersESP", true)
	end)
	if not espOk then
		warn("ESP init failed:", espErr)
		setDebug("ESP", false)
		setDebug("ItemsESP", false)
		setDebug("PlayersESP", false)
		setDebug("GeneratorsESP", false)
	else
		setDebug("ESP", true)
	end

	-- TitleBar drag (manual) and buttons functionality
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
			if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
		end)
		UIS.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position - dragStart
				Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)

		-- Minimize/Close hooks
		local originalSize = Main.Size
		local minimized = false
		BtnMin.MouseButton1Click:Connect(function()
			minimized = not minimized
			local target = minimized and UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 44) or originalSize
			TweenService:Create(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = target}):Play()
		end)
		BtnClose.MouseButton1Click:Connect(function() Confirm.Visible = true end)
		ConfirmYes.MouseButton1Click:Connect(function() SG:Destroy() end)
		ConfirmNo.MouseButton1Click:Connect(function() Confirm.Visible = false end)
	end

	-- success: mark GUI ok
	setDebug("GUI", true)
end)

if not buildOk then
	warn("GUI build failed:", buildErr)
	setDebug("GUI", false)
end

-- Final debug summary print and TestService message
local function debugSummary()
	local msg = "| ESP: " .. tostring(Debugger.ESP)
		.. " | ItemsESP: " .. tostring(Debugger.ItemsESP)
		.. " | PlayersESP: " .. tostring(Debugger.PlayersESP)
		.. " | GeneratorsESP: " .. tostring(Debugger.GeneratorsESP)
		.. " | StaminaModule: " .. tostring(Debugger.Stamina)
		.. " | GUI: " .. tostring(Debugger.GUI)
		.. " | Sliders: " .. tostring(Debugger.Sliders)
		.. " | Buttons: " .. tostring(Debugger.Buttons) .. " |"
	print("[JUDESAKEN DEBUG] " .. msg)
	-- TestService message (studio only)
	pcall(function() TestService:Message("[JUDESAKEN] " .. msg) end)
end

-- small delay to ensure systems initialized, then print
task.delay(0.6, debugSummary)
