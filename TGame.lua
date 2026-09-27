--// ============================================================
--// CHISATO HUB - Auto Fish (iOS Liquid Glass UI)
--// Cập nhật: Đã gộp lại tính năng Farm, xóa chữ "3 trong 1", đủ 5 đảo
--// ============================================================

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Dọn menu & UI cũ để không bị lặp
pcall(function()
	local old = CoreGui:FindFirstChild("AutoFishHubUI")
	if old then old:Destroy() end
end)

pcall(function()
	local oldMenu = PlayerGui:FindFirstChild("AutoFishMenu")
	if oldMenu then oldMenu:Destroy() end
end)

-- ==================================================
-- CẤU HÌNH LOGIC AUTO FISH
-- ==================================================

local Config = {
	TARGET_X = 716,
	TARGET_Y = 385,
	HOLD_TIME = 0.6,
	SKILL_DELAY = 0.3,
	AUTO_QTE = true,
	CLICK_OFFSET_Y = 0,
	SHOW_NOTIFICATION = true,
}

local lastFishID = ""
local isRunning = false
local isAutoSkillRunning = false
local statusLabel

-- ==================================================
-- UI HỖ TRỢ (Tạo Element & Animation)
-- ==================================================

local UITheme = {
	MainSize = UDim2.new(0, 520, 0, 340), 
	ToggleSize = 42,

	Background = Color3.fromRGB(255, 255, 255),
	Panel = Color3.fromRGB(255, 255, 255),

	Accent = Color3.fromRGB(10, 132, 255),
	AccentDark = Color3.fromRGB(0, 112, 225),

	Text = Color3.fromRGB(20, 20, 22),
	SubText = Color3.fromRGB(100, 100, 110),

	AnimationSpeed = 0.25,
}

local function Create(class, properties, parent)
	local object = Instance.new(class)
	for property, value in pairs(properties or {}) do
		object[property] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function Corner(parent, radius)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function Stroke(parent, color, transparency, thickness)
	return Create("UIStroke", {
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1
	}, parent)
end

local function Tween(object, properties, duration, style, direction)
	local tween = TweenService:Create(
		object,
		TweenInfo.new(
			duration or UITheme.AnimationSpeed,
			style or Enum.EasingStyle.Quint,
			direction or Enum.EasingDirection.Out
		),
		properties
	)
	tween:Play()
	return tween
end

-- ==================================================
-- SCREEN GUI CHÍNH
-- ==================================================

local ScreenGui = Create("ScreenGui", {
	Name = "AutoFishHubUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true
}, CoreGui)

-- ==================================================
-- HỆ THỐNG CUSTOM NOTIFICATION (CÓ ANIMATION)
-- ==================================================

local NotifContainer = Create("Frame", {
	Name = "NotifContainer",
	Size = UDim2.new(0, 260, 1, -40),
	Position = UDim2.new(1, -280, 0, 20),
	BackgroundTransparency = 1,
	ZIndex = 300
}, ScreenGui)

Create("UIListLayout", {
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Bottom
}, NotifContainer)

local function notifyOwnFish(fishName, rarity, weight)
	if not Config.SHOW_NOTIFICATION then return end 

	local NotifFrame = Create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = Color3.fromRGB(25, 25, 30),
		BackgroundTransparency = 0.15,
		GroupTransparency = 1,
		Position = UDim2.new(1, 100, 0, 0),
		ZIndex = 301
	}, NotifContainer)
	Corner(NotifFrame, 12)
	Stroke(NotifFrame, Color3.fromRGB(255,255,255), 0.6, 1.5)

	Create("TextLabel", {
		Size = UDim2.new(0, 40, 1, 0),
		Position = UDim2.new(0, 5, 0, 0),
		BackgroundTransparency = 1,
		Text = "🎣",
		TextSize = 25,
		ZIndex = 302
	}, NotifFrame)

	Create("TextLabel", {
		Size = UDim2.new(1, -55, 0, 25),
		Position = UDim2.new(0, 45, 0, 10),
		BackgroundTransparency = 1,
		Text = fishName,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 302
	}, NotifFrame)

	Create("TextLabel", {
		Size = UDim2.new(1, -55, 0, 20),
		Position = UDim2.new(0, 45, 0, 35),
		BackgroundTransparency = 1,
		Text = rarity .. " • " .. weight,
		TextColor3 = Color3.fromRGB(180, 180, 190),
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 302
	}, NotifFrame)

	Tween(NotifFrame, { GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0) }, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	task.delay(3.5, function()
		if NotifFrame then
			local outTween = Tween(NotifFrame, { GroupTransparency = 1, Position = UDim2.new(1, 100, 0, 0) }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			outTween.Completed:Wait()
			NotifFrame:Destroy()
		end
	end)
end

-- ==================================================
-- TRẠNG THÁI
-- ==================================================

local function setStatus(_text)
	if statusLabel then
		if isRunning then
			statusLabel.Text = "ON (Đang Auto Câu)"
			statusLabel.TextColor3 = Color3.fromRGB(52, 199, 89)
		else
			statusLabel.Text = "OFF"
			statusLabel.TextColor3 = UITheme.SubText
		end
	end
end

-- ==================================================
-- KIỂM TRA UI & LOGIC CÁ
-- ==================================================

local function isInsideBillboard(instance)
	local current = instance
	while current and current ~= PlayerGui do
		if current:IsA("BillboardGui") then return true end
		current = current.Parent
	end
	return false
end

local function checkFishUI()
	local caught = false
	pcall(function()
		for _, element in ipairs(PlayerGui:GetDescendants()) do
			if element:IsA("TextLabel") and element.Visible and not isInsideBillboard(element) then
				local text = element.Text
				if text:find("KG") or text:find("kg") then
					local container = element.Parent
					if container and container.Visible then
						local fishName, rarity = "", ""
						local weight = text

						for _, child in ipairs(container:GetChildren()) do
							if child:IsA("TextLabel") and child ~= element then
								local cText = child.Text
								if cText:find("Click anywhere") or cText == "Fish Caught!" or cText == "New!" or cText == "" then
								elseif cText:find("phổ biến") or cText:find("Hiếm") or cText:find("Thần thoại") or cText:find("Huyền thoại") then
									rarity = cText
								else
									fishName = cText
								end
							end
						end

						if fishName ~= "" then
							local fishID = fishName .. "_" .. weight
							if fishID ~= lastFishID then
								lastFishID = fishID
								caught = true
								notifyOwnFish(fishName, rarity, weight)
							end
						end
						break
					end
				end
			end
		end
	end)
	return caught
end

-- ==================================================
-- XỬ LÝ NHẤN NÚT VÀ MINIGAME
-- ==================================================

local function getFishingButton()
	return PlayerGui:FindFirstChild("FishingActionButton", true)
end

local function getButtonCenter(button)
	local pos = button.AbsolutePosition
	local size = button.AbsoluteSize
	local inset = GuiService:GetGuiInset()
	local x = pos.X + size.X / 2 + inset.X
	local y = pos.Y + size.Y / 2 + inset.Y + Config.CLICK_OFFSET_Y
	return x, y
end

local function pressFishingButton(holdTime)
	local button = getFishingButton()
	local x, y
	if button then
		x, y = getButtonCenter(button)
	else
		x, y = Config.TARGET_X, Config.TARGET_Y
	end
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
	task.wait(holdTime or 0.05)
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function simulateClick()
	pressFishingButton(nil)
end

local function getActiveReelButton()
	local reelGui = PlayerGui:FindFirstChild("ReelCounterGui", true)
	if not reelGui then return nil end
	local directionNames = {"Left", "Right", "Up", "Down"}
	for _, name in ipairs(directionNames) do
		local btn = reelGui:FindFirstChild(name)
		if btn and btn:IsA("GuiButton") and btn.Visible then
			return btn
		end
	end
	return nil
end

local function smartReelClick()
	if Config.AUTO_QTE then
		local dirButton = getActiveReelButton()
		if dirButton then
			local x, y = getButtonCenter(dirButton)
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
			return true, dirButton.Name
		end
	end

	local button = getFishingButton()
	if button then
		local x, y = getButtonCenter(button)
		VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
		task.wait(0.05)
		VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
	end
	return false, nil
end

local function pressKey(keyCode, holdTime)
	VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
	task.wait(holdTime or 0.1)
	VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function ensureRodEquipped()
	local character = LocalPlayer.Character
	if not character then return end
	local hasTool = character:FindFirstChildOfClass("Tool")
	if not hasTool then
		pressKey(Enum.KeyCode.One, 0.1)
		task.wait(0.3)
	end
end

-- VÒNG LẶP AUTO SKILL
local skillKeys = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }
local function autoSkillLoop()
	while isAutoSkillRunning do
		for _, key in ipairs(skillKeys) do
			if not isAutoSkillRunning then break end
			pressKey(key, 0.1)
			task.wait(Config.SKILL_DELAY)
		end
	end
end

-- VÒNG LẶP MAIN CÂU CÁ
local function mainLoop()
	while isRunning do
		ensureRodEquipped()
		if not isRunning then break end
		pressFishingButton(Config.HOLD_TIME)

		if not isRunning then break end
		task.wait(1)

		if not isRunning then break end
		local isFishCaught = false

		while isRunning and not isFishCaught do
			isFishCaught = checkFishUI()
			if not isFishCaught then
				smartReelClick()
				task.wait(0.1)
			end
		end

		if not isRunning then break end
		for i = 1, 6 do
			simulateClick()
			task.wait(0.2)
		end
		task.wait(0.3)
	end
end

-- ==================================================
-- HÀM KÉO THẢ UI
-- ==================================================
local function MakeDraggable(object, dragArea)
	local dragging, dragStart, startPosition, hasDragged = false, nil, nil, false
	dragArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, hasDragged = true, false
			dragStart = input.Position
			startPosition = object.Position
		end
	end)
	dragArea.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			if delta.Magnitude > 10 then
				hasDragged = true
				object.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
			end
		end
	end)
	return function() return hasDragged end
end

-- ==================================================
-- NÚT BẬT TẮT UI VÀ KHUNG CHÍNH
-- ==================================================

local ToggleButton = Create("TextButton", {
	Name = "ToggleButton",
	Size = UDim2.new(0, UITheme.ToggleSize, 0, UITheme.ToggleSize),
	Position = UDim2.new(0, 25, 0.5, -29),
	BackgroundColor3 = Color3.fromRGB(35, 35, 40),
	BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 100
}, ScreenGui)
Corner(ToggleButton, 100)
Stroke(ToggleButton, Color3.fromRGB(255,255,255), 0.3, 1.5)

local ToggleIcon = Create("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "🎣",
	TextColor3 = Color3.fromRGB(255,255,255), TextSize = 20, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 101
}, ToggleButton)

local CheckToggleDrag = MakeDraggable(ToggleButton, ToggleButton)

local MainFrame = Create("Frame", {
	Name = "MainFrame", Size = UDim2.new(0,0,0,0),
	Position = UDim2.new(0.5, -UITheme.MainSize.X.Offset / 2, 0.5, -UITheme.MainSize.Y.Offset / 2),
	BackgroundColor3 = UITheme.Background, BackgroundTransparency = 1,
	BorderSizePixel = 0, Visible = false, ClipsDescendants = true, ZIndex = 10
}, ScreenGui)
Corner(MainFrame, 16)
Stroke(MainFrame, Color3.fromRGB(255,255,255), 0.15, 1)

local Shadow = Create("ImageLabel", {
	Name = "Shadow", Size = UDim2.new(1,60,1,60), Position = UDim2.new(0,-30,0,-30),
	BackgroundTransparency = 1, Image = "rbxassetid://6014261993", ImageColor3 = Color3.fromRGB(0,0,0),
	ImageTransparency = 0.7, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49,49,450,450), ZIndex = 5
}, MainFrame)

local TitleBar = Create("Frame", {
	Size = UDim2.new(1,0,0,62), BackgroundColor3 = Color3.fromRGB(255,255,255),
	BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 20
}, MainFrame)
Corner(TitleBar, 16)
Create("Frame", { Size = UDim2.new(1,0,0,20), Position = UDim2.new(0,0,1,-20), BackgroundColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 20}, TitleBar)

local avatarImage = "rbxasset://textures/ui/GuiImagePlaceholder.png"
pcall(function() avatarImage = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end)
local Logo = Create("ImageLabel", { Size = UDim2.new(0,36,0,36), Position = UDim2.new(0,14,0.5,-18), BackgroundColor3 = UITheme.Accent, BackgroundTransparency = 0.1, Image = avatarImage, ZIndex = 21 }, TitleBar)
Corner(Logo, 10)

-- TIÊU ĐỀ CHISATO HUB
Create("TextLabel", { Size = UDim2.new(0,300,0,25), Position = UDim2.new(0,63,0,11), BackgroundTransparency = 1, Text = "CHISATO HUB", TextColor3 = UITheme.Text, TextSize = 17, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, TitleBar)
Create("TextLabel", { Size = UDim2.new(0,300,0,20), Position = UDim2.new(0,63,0,34), BackgroundTransparency = 1, Text = LocalPlayer.DisplayName, TextColor3 = UITheme.SubText, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, TitleBar)

local CloseButton = Create("TextButton", { Size = UDim2.new(0,30,0,30), Position = UDim2.new(1,-45,0.5,-15), BackgroundColor3 = Color3.fromRGB(255,59,48), BackgroundTransparency = 0.2, Text = "×", TextColor3 = Color3.fromRGB(255,255,255), TextSize = 22, Font = Enum.Font.GothamMedium, AutoButtonColor = false, ZIndex = 22 }, TitleBar)
Corner(CloseButton, 8)
MakeDraggable(MainFrame, TitleBar)

local Sidebar = Create("Frame", { Size = UDim2.new(0,145,1,-62), Position = UDim2.new(0,0,0,62), BackgroundColor3 = Color3.fromRGB(240,240,245), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 15 }, MainFrame)
Create("UIPadding", { PaddingTop = UDim.new(0,18), PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10) }, Sidebar)
Create("UIListLayout", { Padding = UDim.new(0,7), SortOrder = Enum.SortOrder.LayoutOrder }, Sidebar)

local Content = Create("CanvasGroup", { Size = UDim2.new(1,-145,1,-62), Position = UDim2.new(0,145,0,62), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 16 }, MainFrame)

-- ==================================================
-- HỆ THỐNG TẠO TAB VÀ CHỨC NĂNG
-- ==================================================

local Tabs, TabButtons, CurrentTab = {}, {}, nil

local function CreateTab(tabName, icon)
	local TabButton = Create("TextButton", { Size = UDim2.new(1,0,0,40), BackgroundColor3 = UITheme.Accent, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = #TabButtons + 1, ZIndex = 20 }, Sidebar)
	Corner(TabButton, 10)
	local Icon = Create("TextLabel", { Size = UDim2.new(0,30,1,0), Position = UDim2.new(0,5,0,0), BackgroundTransparency = 1, Text = icon, TextColor3 = UITheme.SubText, TextSize = 16, Font = Enum.Font.GothamMedium, ZIndex = 21 }, TabButton)
	local Label = Create("TextLabel", { Size = UDim2.new(1,-42,1,0), Position = UDim2.new(0,40,0,0), BackgroundTransparency = 1, Text = tabName, TextColor3 = UITheme.SubText, TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, TabButton)
	local TabFrame = Create("ScrollingFrame", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = UITheme.Accent, CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 18 }, Content)
	Create("UIPadding", { PaddingTop = UDim.new(0,15), PaddingLeft = UDim.new(0,15), PaddingRight = UDim.new(0,15), PaddingBottom = UDim.new(0,15) }, TabFrame)
	Create("UIListLayout", { Padding = UDim.new(0,10), SortOrder = Enum.SortOrder.LayoutOrder }, TabFrame)
	
	Tabs[tabName] = TabFrame
	TabButtons[tabName] = { Button = TabButton, Icon = Icon, Label = Label }
	
	TabButton.MouseButton1Click:Connect(function()
		if CurrentTab == tabName then return end
		CurrentTab = tabName
		Tween(Content, { GroupTransparency = 1, Position = UDim2.new(0, 145, 0, 72) }, 0.15)
		task.delay(0.15, function()
			for name, frame in pairs(Tabs) do frame.Visible = (name == tabName) end
			Tween(Content, { GroupTransparency = 0, Position = UDim2.new(0, 145, 0, 62) }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end)
		for name, data in pairs(TabButtons) do
			if name == tabName then
				Tween(data.Button, { BackgroundTransparency = 0.1 }); Tween(data.Icon, { TextColor3 = Color3.fromRGB(255, 255, 255) }); Tween(data.Label, { TextColor3 = Color3.fromRGB(255, 255, 255) })
			else
				Tween(data.Button, { BackgroundTransparency = 1 }); Tween(data.Icon, { TextColor3 = UITheme.SubText }); Tween(data.Label, { TextColor3 = UITheme.SubText })
			end
		end
	end)
	return TabFrame
end

local function CreateSection(parent, title)
	local Section = Create("Frame", { Size = UDim2.new(1,0,0,26), BackgroundTransparency = 1, ZIndex = 20 }, parent)
	Create("TextLabel", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = string.upper(title), TextColor3 = UITheme.SubText, TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, Section)
	return Section
end

local function CreateToggle(parent, text, default, callback)
	local State = default or false
	local Holder = Create("Frame", { Size = UDim2.new(1,0,0,46), BackgroundColor3 = UITheme.Panel, BackgroundTransparency = 0.5, ZIndex = 20 }, parent)
	Corner(Holder, 10); Stroke(Holder, Color3.fromRGB(255,255,255), 0.2, 1)
	Create("TextLabel", { Size = UDim2.new(1,-80,1,0), Position = UDim2.new(0,15,0,0), BackgroundTransparency = 1, Text = text, TextColor3 = UITheme.Text, TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, Holder)
	
	local Switch = Create("TextButton", { Size = UDim2.new(0,46,0,26), Position = UDim2.new(1,-60,0.5,-13), BackgroundColor3 = Color3.fromRGB(210,210,220), Text = "", AutoButtonColor = false, ZIndex = 22 }, Holder)
	Corner(Switch, 100)
	local Knob = Create("Frame", { Size = UDim2.new(0,22,0,22), Position = UDim2.new(0,2,0.5,-11), BackgroundColor3 = Color3.fromRGB(255,255,255), ZIndex = 23 }, Switch)
	Corner(Knob, 100); Stroke(Knob, Color3.fromRGB(0,0,0), 0.85, 1)

	local function Update()
		if State then
			Tween(Switch, { BackgroundColor3 = UITheme.Accent }, 0.2); Tween(Knob, { Position = UDim2.new(1, -24, 0.5, -11) }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		else
			Tween(Switch, { BackgroundColor3 = Color3.fromRGB(210, 210, 220) }, 0.2); Tween(Knob, { Position = UDim2.new(0, 2, 0.5, -11) }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end

	Switch.MouseButton1Click:Connect(function()
		State = not State
		Tween(Switch, { Size = UDim2.new(0, 52, 0, 22), Position = UDim2.new(1, -63, 0.5, -11) }, 0.1)
		task.delay(0.1, function() Tween(Switch, { Size = UDim2.new(0, 46, 0, 26), Position = UDim2.new(1, -60, 0.5, -13) }, 0.2, Enum.EasingStyle.Bounce) end)
		Update()
		if callback then callback(State) end
	end)
	Update()
end

-- ==================================================
-- TAB 1: TRẠNG THÁI
-- ==================================================
local StatusTab = CreateTab("Trạng Thái", "📊")
CreateSection(StatusTab, "Chisato Hub Status")
statusLabel = Create("TextLabel", { Size = UDim2.new(1,0,0,70), BackgroundTransparency = 1, Text = "OFF", TextColor3 = UITheme.SubText, TextSize = 19, Font = Enum.Font.GothamBold, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 21 }, StatusTab)

-- ==================================================
-- TAB 2: FARM (Gộp chung, bỏ chữ "3 trong 1")
-- ==================================================
local FarmTab = CreateTab("Farm", "⚙")
CreateSection(FarmTab, "Tự Động Hoá")

CreateToggle(FarmTab, "Auto Farm", false, function(v)
	isRunning = v
	isAutoSkillRunning = v
	Config.AUTO_QTE = v
	if isRunning then
		setStatus("")
		task.spawn(mainLoop)
		task.spawn(autoSkillLoop)
	else
		setStatus("")
	end
end)

-- ==================================================
-- TAB 3: ĐẢO (Đủ 1 - 5 đảo)
-- ==================================================
local IslandTab = CreateTab("Đảo", "🏝️")
CreateSection(IslandTab, "Chọn Đảo")

local function TeleportToIsland(pos)
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local root = char.HumanoidRootPart
	local twInfo = TweenInfo.new(0.4, Enum.EasingStyle.Linear)
	for i = 1, 7 do
		root.Velocity = Vector3.new(0,0,0); root.AssemblyLinearVelocity = Vector3.new(0,0,0)
		local tw = TweenService:Create(root, twInfo, { CFrame = CFrame.new(pos) }); tw:Play(); tw.Completed:Wait(); task.wait(0.1)
	end
end

CreateToggle(IslandTab, "Đảo 1", false, function(v) if v then task.spawn(function() TeleportToIsland(Vector3.new(-42.06, 11.09, 333.26)) end) end end)
CreateToggle(IslandTab, "Đảo 2", false, function(v) if v then task.spawn(function() TeleportToIsland(Vector3.new(-32.03, 9.40, -1013.22)) end) end end)
CreateToggle(IslandTab, "Đảo 3", false, function(v) if v then task.spawn(function() TeleportToIsland(Vector3.new(1210.61, 9.72, -331.24)) end) end end)
CreateToggle(IslandTab, "Đảo 4", false, function(v) if v then task.spawn(function() TeleportToIsland(Vector3.new(1861.87, 9.65, 1087.61)) end) end end)
CreateToggle(IslandTab, "Đảo 5", false, function(v) if v then task.spawn(function() TeleportToIsland(Vector3.new(-564.92, 10.55, 2227.39)) end) end end)

-- ==================================================
-- TAB 4: SETTING
-- ==================================================
local SettingTab = CreateTab("Setting", "🛠️")
CreateSection(SettingTab, "Cài đặt UI")
CreateToggle(SettingTab, "Thông báo câu được cá", Config.SHOW_NOTIFICATION, function(v) Config.SHOW_NOTIFICATION = v end)

-- ==================================================
-- KHỞI TẠO TAB MẶC ĐỊNH
-- ==================================================
Tabs["Trạng Thái"].Visible = true
TabButtons["Trạng Thái"].Button.BackgroundTransparency = 0.1
TabButtons["Trạng Thái"].Icon.TextColor3 = Color3.fromRGB(255,255,255)
TabButtons["Trạng Thái"].Label.TextColor3 = Color3.fromRGB(255,255,255)
CurrentTab = "Trạng Thái"

-- ==================================================
-- ANIMATION MỞ / ĐÓNG MENU
-- ==================================================
local MenuOpen, OriginalSize, ClosedSize = false, UITheme.MainSize, UDim2.new(0,0,0,0)

local function OpenMenu()
	if MenuOpen then return end
	MenuOpen, MainFrame.Visible, MainFrame.Size, MainFrame.Position, MainFrame.BackgroundTransparency, ToggleIcon.Text = true, true, ClosedSize, UDim2.new(0.5, 0, 0.5, 0), 1, "×"
	Tween(MainFrame, { Size = OriginalSize, Position = UDim2.new(0.5, -OriginalSize.X.Offset / 2, 0.5, -OriginalSize.Y.Offset / 2), BackgroundTransparency = 0.65 }, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Tween(ToggleButton, { Rotation = 180 }, 0.3, Enum.EasingStyle.Back)
end

local function CloseMenu()
	if not MenuOpen then return end
	MenuOpen = false
	Tween(MainFrame, { Size = ClosedSize, Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Tween(ToggleButton, { Rotation = 0 }, 0.3, Enum.EasingStyle.Back)
	task.delay(0.3, function() if not MenuOpen then MainFrame.Visible = false end end)
end

ToggleButton.MouseButton1Click:Connect(function()
	if CheckToggleDrag() then return end
	if MenuOpen then CloseMenu() else OpenMenu() end
	Tween(ToggleButton, { Size = UDim2.new(0, UITheme.ToggleSize - 6, 0, UITheme.ToggleSize - 6) }, 0.1)
	task.delay(0.1, function() Tween(ToggleButton, { Size = UDim2.new(0, UITheme.ToggleSize, 0, UITheme.ToggleSize) }, 0.2, Enum.EasingStyle.Bounce) end)
end)
CloseButton.MouseButton1Click:Connect(CloseMenu)
