--// ============================================================
--// CHISATO HUB - Auto Fish (iOS Liquid Glass UI)
--// ============================================================

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local env = (getgenv and getgenv()) or _G
if env.ChisatoHubCleanup then
	pcall(env.ChisatoHubCleanup)
end

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
	SKILL_DELAY = 0.4,
	SKILL_ENABLED = { Z = true, X = true, C = true, V = true }, -- kỹ năng nào được dùng khi Auto Farm (chỉnh ở tab Farm)
	AUTO_QTE = true,
	CLICK_OFFSET_Y = 0,
	SHOW_NOTIFICATION = true, -- luôn bật (đã bỏ công tắc)
	USE_TOUCH = true, -- luôn bật: bấm bằng cảm ứng, máy nào không hỗ trợ thì tự chuyển sang chuột (đã bỏ công tắc)
	SELL_CHECK_INTERVAL = 5,
	SELL_MAX_ATTEMPTS = 4, -- bán xong mà túi vẫn đầy thì bán lại ngay tại NPC tối đa chừng này lần / chuyến
	SELL_RETRY_DELAY = 5, -- cả chuyến bán xong túi vẫn đầy: nghỉ chừng này giây rồi đi bán lại
	SELL_RETRY_DELAY_LONG = 30, -- sau 3 chuyến liền vẫn đầy thì nghỉ lâu hơn, tránh dịch chuyển dồn dập bị kick
	BOSS_RETURN_DELAY = 3, -- boss hết: tắt câu rồi đợi chừng này giây mới tp về chỗ cũ
	ANTI_TP = true, -- chống bị game/server kéo nhân vật về chỗ cũ sau khi tp (đặt false để tắt hẳn, vd khi cần dùng dịch chuyển của chính game)
	CATCH_TIMEOUT = 60,
	SELL_POS = Vector3.new(-29.39, 19.66, 406.90),
	FIXLAG_INTERVAL = 10,
	BOSS_SCAN_INTERVAL = 15, -- bảng Boss Zone cập nhật mỗi 15 giây
	BOSS_STREAM_ALL = true, -- luôn bật: tự yêu cầu game tải các đảo xa để quét boss zone (đã bỏ công tắc)
	BOSS_STREAM_INTERVAL = 30, -- toàn bộ 6 đảo được quét lại mỗi 30 giây (quét lần lượt, cách nhau 0.6s/đảo)
	BOSS_NOTIFY_DURATION = 60, -- thông báo "Boss Zone đã spawn" hiện trong 60 giây rồi mới tự tắt
	-- Cấu hình game (menu Settings trong game) áp dụng khi bật Fix Lag.
	-- true = bật, false = tắt. Tên phải khớp đúng chữ hiển thị trong menu Settings của game.
	GAME_SETTINGS = {
		["FastMode"] = false,
		["Hide Auto Fishing Skill Visuals"] = false,
		["Skip Cutscenes"] = false,
		["Skip Loot Preview"] = true,
		["Show Damage"] = true,
		["Show VFX (self)"] = true,
		["Show VFX (Other Players)"] = true,
		["Camera Shake"] = true,
	},
}

local lastFishID = ""
local isRunning = false
local isAutoSkillRunning = false
local isAutoSellRunning = false
local mainLoopActive = false
local skillLoopActive = false
local sellLoopActive = false
local farmToggle

-- ==================================================
-- AUTO FARM: THEO DÕI Ý MUỐN CỦA NGƯỜI DÙNG + BẬT LẠI CHẮC CHẮN
-- farmUserWants chỉ đổi khi CHÍNH NGƯỜI DÙNG bấm công tắc Auto Farm. Mọi lần SCRIPT tạm tắt/bật Auto Farm
-- (đi bán cá, đi/về boss) phải đi qua farmSet để không bị tính là người dùng bấm.
-- Nhờ vậy sau chuyến đi bán / câu boss, Auto Farm được trả về đúng ý người dùng, kể cả khi lúc bắt đầu chuyến
-- nó đang bị tạm tắt vì lý do khác (trước đây chỉ nhớ "lúc bắt đầu có đang chạy không" nên có lúc không bật lại).
-- restoreFarm không chỉ bật công tắc mà còn đợi vòng câu thực sự chạy; công tắc ON mà vòng câu đã chết thì tắt rồi bật lại.
-- ==================================================
local farmUserWants = false
local farmScriptToggle = false

local function farmSet(v)
	if not farmToggle then return end
	farmScriptToggle = true
	pcall(farmToggle.Set, v)
	farmScriptToggle = false
end

-- Đưa Auto Farm về trạng thái want. want = true: bật và chắc chắn vòng câu chạy (thử tối đa 3 lần), trả về true nếu chạy.
local function restoreFarm(want)
	if not farmToggle then return false end
	if not want then
		farmSet(false)
		return true
	end
	for _ = 1, 3 do
		if farmToggle.Get() and not mainLoopActive then
			-- công tắc đang ON nhưng vòng câu không chạy (kẹt / lỗi): tắt rồi bật lại để khởi động lại vòng câu
			farmSet(false)
			task.wait(0.3)
		end
		farmSet(true)
		local t = 0
		while not mainLoopActive and t < 3 do
			task.wait(0.1)
			t += 0.1
		end
		if mainLoopActive and isRunning then return true end
		task.wait(0.5)
	end
	return false
end

local bagEstimate = nil
local lastLabelCount = nil
local bagMax = nil -- sức chứa túi THẬT của người chơi, đọc từ game (nil = chưa đọc được, không có giá trị mặc định)
local sellState = "Chờ túi đầy"
local sellBusy = false
local statusLabel
local connections = {}
-- busyUntil: trong lúc quét boss đang tải đảo xa (tới mốc thời gian này), Fix Lag tạm nhường chỗ,
-- không xử lý từng vật thể mới xuất hiện ngay lập tức, để tránh dồn việc gây giật khi nhiều đảo đổ dữ liệu về cùng lúc.
local BossScan = { busyUntil = 0 }
local catchSerial = 0
local fishScanInfo = "Chưa quét"
local fixLagStop
local antiTPStop

-- ==================================================
-- KHOÁ DỊCH CHUYỂN: mọi lần dịch chuyển (đi bán cá, đi/về boss, nút Đảo, nút Tới boss) phải xin khoá này,
-- cùng lúc chỉ có 1 bên được dịch chuyển, giữa 2 lần cách nhau tối thiểu Travel.minGap giây.
-- Trước đây bán cá / câu boss / tới đảo có thể dịch chuyển chồng lên nhau => game kick vì dịch chuyển quá nhiều.
-- ==================================================
local Travel = { owner = nil, since = 0, lastEnd = 0, minGap = 1.5, maxHold = 120 } -- maxHold: giữ khoá quá lâu (bị kẹt) thì coi như hết hạn

function Travel.try(name)
	if Travel.owner and os.clock() - Travel.since > Travel.maxHold then Travel.owner = nil end
	if Travel.owner or os.clock() - Travel.lastEnd < Travel.minGap then return false end
	Travel.owner, Travel.since = name, os.clock()
	return true
end

function Travel.wait(name, maxWait)
	local t0 = os.clock()
	while not Travel.try(name) do
		if os.clock() - t0 > (maxWait or 90) then return false end
		task.wait(0.2)
	end
	return true
end

function Travel.done(name)
	if Travel.owner == name then
		Travel.owner = nil
		Travel.lastEnd = os.clock()
	end
end

-- Đang bán cá hoặc đang có dịch chuyển nào đó
function Travel.busy()
	return sellBusy or Travel.owner ~= nil
end

-- Yêu cầu game tải khu vực quanh pos, có giới hạn thời gian cứng (không bao giờ treo mãi).
-- Trả về ok, lỗi.
local function requestStream(pos, timeout)
	local done, ok, err = false, false, nil
	task.spawn(function()
		ok, err = pcall(function()
			LocalPlayer:RequestStreamAroundAsync(pos, timeout)
		end)
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < timeout + 4 do
		task.wait(0.1)
	end
	if not done then return false, "quá thời gian chờ tải đảo" end
	return ok, err
end

-- ==================================================
-- ANTI TP: giữ nhân vật đứng yên đúng chỗ. Game / server bắt nhân vật dịch chuyển (kéo về chỗ cũ, đá về spawn...)
-- mà không phải do script này thì tự đặt lại đúng chỗ đứng ngay trước đó.
-- Cơ chế: mỗi Heartbeat nhớ CFrame hiện tại (lastCF); hễ CFrame của HumanoidRootPart bị đổi từ bên ngoài thì đặt lại lastCF.
-- Mọi lần script TỰ đặt CFrame nhân vật (tp, xoay mặt về boss, kéo lại chỗ đứng) phải đi qua setRootCFrame:
-- hàm này báo cho guard biết đó là thay đổi hợp lệ và cập nhật lastCF, nếu không guard sẽ hoàn tác luôn cú tp của chính script.
-- Config.ANTI_TP = false để tắt hẳn.
-- ==================================================
local AntiTP = { lastCF = nil, stop = false, expected = nil, expectedUntil = 0, hb = nil, cf = nil, died = nil }

local function antiTPDisconnect()
	for _, key in ipairs({ "hb", "cf", "died" }) do
		if AntiTP[key] then
			pcall(function() AntiTP[key]:Disconnect() end)
			AntiTP[key] = nil
		end
	end
end
antiTPStop = antiTPDisconnect

-- Đặt CFrame nhân vật (do script tự làm) mà không bị guard hoàn tác
local function setRootCFrame(root, cf)
	AntiTP.expected = cf
	AntiTP.expectedUntil = os.clock() + 0.5
	AntiTP.lastCF = cf
	root.CFrame = cf
end

local function antiTPAttach(char)
	antiTPDisconnect()
	if not Config.ANTI_TP then return end

	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local root = hum.RootPart
	local t0 = os.clock()
	while not root and os.clock() - t0 < 10 do
		RunService.Heartbeat:Wait()
		root = hum.RootPart
	end
	if not root or LocalPlayer.Character ~= char then return end

	AntiTP.stop = false
	AntiTP.lastCF = root.CFrame

	AntiTP.hb = RunService.Heartbeat:Connect(function()
		if AntiTP.stop then return end
		AntiTP.lastCF = root.CFrame
	end)

	AntiTP.cf = root:GetPropertyChangedSignal("CFrame"):Connect(function()
		if AntiTP.stop then return end
		local last = AntiTP.lastCF
		if not last then return end
		-- đúng chỗ script vừa tự đặt (trong vòng 0.5 giây): cho qua
		local exp = AntiTP.expected
		if exp and os.clock() < AntiTP.expectedUntil and (root.Position - exp.Position).Magnitude < 3 then
			return
		end
		AntiTP.stop = true
		root.CFrame = last
		RunService.Heartbeat:Wait()
		AntiTP.stop = false
	end)

	AntiTP.died = hum.Died:Connect(antiTPDisconnect)
end

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(char)
	task.spawn(antiTPAttach, char)
end))
table.insert(connections, LocalPlayer.CharacterRemoving:Connect(antiTPDisconnect))
if LocalPlayer.Character then
	task.spawn(antiTPAttach, LocalPlayer.Character)
end

-- ==================================================
-- TELEPORT TỨC THÌ (dùng cho Auto Sell, menu Đảo, Auto Câu Boss)
-- Nhận Vector3 hoặc CFrame. Đặt thẳng CFrame 1 lần, không tween; Anti TP giữ nhân vật ở lại chỗ mới.
-- ==================================================
local function FastTeleport(target)
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local goal
	if typeof(target) == "CFrame" then
		goal = target
	else
		goal = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
	end

	-- đích xa (đảo khác): yêu cầu game tải sẵn khu vực đó trước, không thì nhân vật rơi xuống chỗ chưa tải xong
	if (goal.Position - root.Position).Magnitude > 300 then
		BossScan.busyUntil = os.clock() + 8 -- Fix Lag nhường chỗ lúc dữ liệu khu vực mới đổ về
		requestStream(goal.Position, 3)
		char = LocalPlayer.Character
		root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end
	end

	root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	setRootCFrame(root, goal)
end

-- Nhảy đúng 1 cái sau khi tp về chỗ cũ (bán cá xong / câu boss xong), rồi mới bật lại Auto Farm.
-- Đợi nhân vật đứng vững trên mặt đất trước (vừa tp xong có thể còn đang rơi), nhảy, rồi đợi đáp xuống lại.
local function jumpOnce()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local t = 0
	while hum.FloorMaterial == Enum.Material.Air and t < 3 do
		task.wait(0.1)
		t += 0.1
	end

	hum.Jump = true
	pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
	task.wait(0.4)

	t = 0
	while hum.FloorMaterial == Enum.Material.Air and t < 3 do
		task.wait(0.1)
		t += 0.1
	end
	task.wait(0.3)
end

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
})
local okParent = pcall(function() ScreenGui.Parent = CoreGui end)
if not okParent then
	ScreenGui.Parent = PlayerGui
end

env.ChisatoHubCleanup = function()
	isRunning = false
	isAutoSkillRunning = false
	isAutoSellRunning = false
	if fixLagStop then pcall(fixLagStop) end
	if antiTPStop then pcall(antiTPStop) end
	for _, c in ipairs(connections) do
		pcall(function() c:Disconnect() end)
	end
	pcall(function() ScreenGui:Destroy() end)
end

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

-- Tham số duration (giây) để 1 số thông báo (vd Boss Zone) hiện lâu hơn thông báo câu cá bình thường.
-- Không truyền thì dùng mặc định 3.5 giây.
local function notifyOwnFish(fishName, rarity, weight, force, duration)
	if not Config.SHOW_NOTIFICATION and not force then return end
	duration = duration or 3.5

	local Holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundTransparency = 1,
		ZIndex = 301
	}, NotifContainer)

	local NotifFrame = Create("CanvasGroup", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(25, 25, 30),
		BackgroundTransparency = 0.15,
		GroupTransparency = 1,
		Position = UDim2.new(1, 100, 0, 0),
		ZIndex = 301
	}, Holder)
	Corner(NotifFrame, 12)
	Stroke(NotifFrame, Color3.fromRGB(255, 255, 255), 0.6, 1.5)

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

	task.delay(duration, function()
		pcall(function()
			local outTween = Tween(NotifFrame, { GroupTransparency = 1, Position = UDim2.new(1, 100, 0, 0) }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			outTween.Completed:Wait()
			Holder:Destroy()
		end)
	end)
end

-- ==================================================
-- TRẠNG THÁI
-- ==================================================

local function setStatus(_text)
	if statusLabel then
		if isRunning then
			statusLabel.Text = "ON"
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

local function isReallyVisible(gui)
	local cur = gui
	while cur and cur ~= PlayerGui do
		if cur:IsA("GuiObject") and not cur.Visible then return false end
		if cur:IsA("ScreenGui") and not cur.Enabled then return false end
		cur = cur.Parent
	end
	return true
end

local RARITY_VN = { "phổ biến", "hiếm", "thần thoại", "huyền thoại" }
local RARITY_EN = { common = true, uncommon = true, rare = true, epic = true, legendary = true, mythic = true, mythical = true, divine = true, huge = true }

local function isRarityText(text)
	local l = string.lower(text)
	if RARITY_EN[l] then return true end
	for _, w in ipairs(RARITY_VN) do
		if l:find(w, 1, true) then return true end
	end
	return false
end

local function labelText(obj)
	if obj and obj:IsA("TextLabel") then return obj.Text end
	return ""
end

-- Các GUI khác của game cũng có chữ "KG" nên phải loại ra khi quét dự phòng
local IGNORE_GUIS = {
	SatchelModal = true, Backpack = true, Index = true, Trade = true, Gift = true, Store = true, Tooltip = true,
	TopbarStandard = true, TopbarCentered = true, TopbarStandardClipped = true, TopbarCenteredClipped = true,
	Quests = true, QuestsModal = true, StatsModal = true, Equipments = true, RodShop = true, BaitShop = true,
	Gacha = true, CrateGacha = true, SessionInfo = true, AutoSell = true, DailyReward = true, Settings = true,
	FastTravel = true, Confirm = true, Events = true, Rod = true, Rod2 = true, HUD = true, Cmdr = true,
	Dialogue = true, Tutorial = true, NotificationGui = true, DamageCounterGui = true,
}

local function isInsideTemplate(element)
	local cur = element.Parent
	while cur and cur ~= PlayerGui do
		if string.find(cur.Name, "Template", 1, true) then return true end
		cur = cur.Parent
	end
	return false
end

local function scanLabels(root, filterOthers)
	for _, element in ipairs(root:GetDescendants()) do
		if element:IsA("TextLabel") and element.Visible then
			local text = element.Text
			if text ~= "" and string.find(string.lower(text), "kg", 1, true) then
				local skip = false
				if filterOthers then
					local lc = element:FindFirstAncestorWhichIsA("LayerCollector")
					if lc and (lc:IsA("BillboardGui") or lc:IsA("SurfaceGui") or IGNORE_GUIS[lc.Name] or lc == ScreenGui) then
						skip = true
					end
				end
				if not skip and not isInsideTemplate(element) and not isInsideBillboard(element) then
					local container = element.Parent
					if container and container:IsA("GuiObject") and container.Visible then
						local fishName, rarity = "", ""
						for _, child in ipairs(container:GetChildren()) do
							if child:IsA("TextLabel") and child ~= element then
								local cText = child.Text
								local lower = string.lower(cText)
								if cText == "" or lower:find("click anywhere", 1, true) or lower == "fish caught!" or lower == "new!" then
									-- bỏ qua
								elseif isRarityText(cText) then
									rarity = cText
								else
									fishName = cText
								end
							end
						end
						if fishName ~= "" then
							return { name = fishName, rarity = rarity, weight = text, shown = isReallyVisible(element) }
						end
					end
				end
			end
		end
	end
	return nil
end

local function readOwnCatch()
	local loot = PlayerGui:FindFirstChild("Loot")
	if loot then
		local fishing = loot:FindFirstChild("Fishing")
		local main = fishing and fishing:FindFirstChild("Main")
		local info = main and main:FindFirstChild("Information")
		if info and info:IsA("GuiObject") and info.Visible then
			local name = labelText(info:FindFirstChild("FishName"))
			local weight = labelText(info:FindFirstChild("Weight"))
			if name ~= "" and weight ~= "" then
				return {
					name = name,
					rarity = labelText(info:FindFirstChild("Rarity")),
					weight = weight,
					shown = isReallyVisible(info),
				}, false
			end
		end
		return scanLabels(loot, false), false
	end
	return scanLabels(PlayerGui, true), true
end

local function fishWatcher()
	local baselineDone = false
	local rearm = false
	local pendingShow = false
	local lastCatchText = "chưa có"

	while ScreenGui.Parent do
		local waitTime = 0.1
		local ok, err = pcall(function()
			local fish, usedFallback = readOwnCatch()
			if usedFallback then waitTime = 0.4 end

			if not baselineDone then
				baselineDone = true
				if fish then lastFishID = fish.name .. "_" .. fish.weight end
				fishScanInfo = "Cá gần nhất: " .. lastCatchText .. " | Bảng: đã sẵn sàng"
				return
			end

			local state = "không thấy"
			if fish then
				local fishID = fish.name .. "_" .. fish.weight
				local function count()
					lastFishID = fishID
					catchSerial = catchSerial + 1
					bagEstimate = (bagEstimate or 0) + 1
					lastCatchText = fish.name .. " (" .. fish.weight .. ")"
					local nOk, nErr = pcall(notifyOwnFish, fish.name, fish.rarity, fish.weight)
					if not nOk then
						lastCatchText = lastCatchText .. " [lỗi hiện thông báo: " .. tostring(nErr) .. "]"
					end
				end

				if fish.shown then
					state = "đang hiện"
					if fishID ~= lastFishID or rearm then count() end
					rearm = false
					pendingShow = false
				else
					state = "đang ẩn"
					if fishID ~= lastFishID then
						count()
						pendingShow = true
						rearm = false
					elseif not pendingShow then
						rearm = true
					end
				end
			end
			fishScanInfo = "Cá gần nhất: " .. lastCatchText .. " | Bảng: " .. state
		end)
		if not ok then
			fishScanInfo = "Lỗi quét: " .. tostring(err)
		end
		task.wait(waitTime)
	end
end
task.spawn(fishWatcher)

-- ==================================================
-- XỬ LÝ NHẤN NÚT VÀ MINIGAME
-- ==================================================

-- Toạ độ tâm của nút GUI theo cách đoán cũ (chỉ còn dùng dự phòng khi chưa đo được)
local function getGuiPoint(button, withInset)
	local pos = button.AbsolutePosition
	local size = button.AbsoluteSize
	if withInset == nil then
		local sg = button:FindFirstAncestorWhichIsA("ScreenGui")
		withInset = not (sg and sg.IgnoreGuiInset)
	end
	local ix, iy = 0, 0
	if withInset then
		local inset = GuiService:GetGuiInset()
		ix, iy = inset.X, inset.Y
	end
	return pos.X + size.X / 2 + ix, pos.Y + size.Y / 2 + iy
end

-- ==================================================
-- HIỆU CHỈNH BẤM (bản nhanh)
-- Đo độ lệch THẬT giữa toạ độ giả lập và vị trí nút trên màn hình bằng cách bấm thử vào ô mẫu của script.
-- Các điểm làm cho nhanh hơn:
--  - mỗi lần bấm thử chỉ chờ tới khi ô mẫu nhận được cú bấm (không chờ cố định)
--  - tỉ lệ toạ độ chỉ đo 1 lần rồi dùng lại cho mọi loại giao diện, các lần sau chỉ đo độ lệch (ít lần bấm hơn hẳn)
--  - thử ngay độ lệch đã đo ở giao diện trước, nên thường trúng ngay lần đầu
--  - có cảm ứng thì không đo chuột nữa (chuột chỉ đo khi cần dùng dự phòng)
-- ==================================================
local Calib = {}
local calibBusy = false
local CalibInfo = { scale = {}, touchDead = false, grid = {} }
for gy = -240, 240, 60 do
	for gx = -240, 240, 60 do
		table.insert(CalibInfo.grid, { gx, gy })
	end
end
-- lưới quét dự phòng: điểm gần tâm thử trước, điểm xa thử sau
table.sort(CalibInfo.grid, function(a, b)
	return a[1] * a[1] + a[2] * a[2] < b[1] * b[1] + b[2] * b[2]
end)

local function pointerPress(x, y, holdTime)
	pcall(function() VirtualInputManager:SendMouseMoveEvent(x, y, game) end)
	task.wait(0.03)
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
	task.wait(holdTime or 0.05)
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local touchSeq = 0
local function touchPress(x, y, holdTime)
	touchSeq = (touchSeq % 10) + 1
	local id = touchSeq
	local ok = pcall(function() VirtualInputManager:SendTouchEvent(id, 0, x, y) end)
	if not ok then return false end
	task.wait(holdTime or 0.05)
	pcall(function() VirtualInputManager:SendTouchEvent(id, 2, x, y) end)
	return true
end

local function probeKeyOf(sg)
	local ignore = false
	local insets = nil
	if sg then
		ignore = sg.IgnoreGuiInset
		pcall(function() insets = sg.ScreenInsets end)
	end
	return tostring(ignore) .. "|" .. tostring(insets), ignore, insets
end

-- Trả về bảng { sx, sy, tx, ty } (toạ độ bấm = toạ độ nút * tỉ lệ + độ lệch) hoặc false nếu không bấm được
-- knownScale: tỉ lệ đã đo trước đó (nil = chưa biết, phải đo bằng 2 ô mẫu)
-- hints: danh sách độ lệch {tx, ty} đã đo ở các giao diện khác, thử trước
local function runCalibration(ignore, insets, method, knownScale, hints)
	if method == "touch" then
		local exists = pcall(function() return VirtualInputManager.SendTouchEvent end)
		if not exists then return false end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ChisatoCalib"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2147483000
	gui.IgnoreGuiInset = ignore
	if insets ~= nil then pcall(function() gui.ScreenInsets = insets end) end
	if not pcall(function() gui.Parent = CoreGui end) then gui.Parent = PlayerGui end

	local function makeBox(size, pos, z)
		local b = Instance.new("TextButton")
		b.Size = size
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = pos
		b.BackgroundTransparency = 1
		b.Text = ""
		b.AutoButtonColor = false
		b.ZIndex = z
		b.Parent = gui
		return b
	end
	-- sink phủ kín màn hình để mọi lần bấm thử đều bị chặn lại, không rơi vào giao diện của game
	makeBox(UDim2.new(1, 0, 1, 0), UDim2.new(0.5, 0, 0.5, 0), 1)
	local m1 = makeBox(UDim2.new(0, 80, 0, 80), UDim2.new(0.3, 0, 0.3, 0), 2)
	local m2 = nil
	if not knownScale then
		m2 = makeBox(UDim2.new(0, 80, 0, 80), UDim2.new(0.8, 0, 0.8, 0), 2)
	end

	local hitBy = nil
	local function watch(box)
		box.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then hitBy = box end
		end)
	end
	watch(m1)
	if m2 then watch(m2) end

	-- đo thời gian 1 khung hình để biết mỗi lần bấm thử cần chờ tối đa bao lâu (~3 khung hình)
	local frames = 0
	for _ = 1, 4 do frames += task.wait() end
	local probeTimeout = math.clamp(frames / 4 * 3, 0.05, 0.15)
	task.wait(0.05)

	local unsupported = false
	-- bấm thử tại (vx, vy): trúng ô `box` thì trả về true; thoát sớm ngay khi ô nhận được cú bấm
	local function tryAt(box, vx, vy)
		hitBy = nil
		local id = nil
		if method == "touch" then
			touchSeq = (touchSeq % 10) + 1
			id = touchSeq
			if not pcall(function() VirtualInputManager:SendTouchEvent(id, 0, vx, vy) end) then
				unsupported = true
				return false
			end
		else
			pcall(function() VirtualInputManager:SendMouseMoveEvent(vx, vy, game) end)
			task.wait()
			VirtualInputManager:SendMouseButtonEvent(vx, vy, 0, true, game, 0)
		end
		local t0 = os.clock()
		repeat task.wait() until hitBy == box or os.clock() - t0 >= probeTimeout
		local hit = (hitBy == box)
		if method == "touch" then
			pcall(function() VirtualInputManager:SendTouchEvent(id, 2, vx, vy) end)
		else
			VirtualInputManager:SendMouseButtonEvent(vx, vy, 0, false, game, 0)
		end
		return hit
	end

	local function center(box)
		return box.AbsolutePosition.X + box.AbsoluteSize.X / 2, box.AbsolutePosition.Y + box.AbsoluteSize.Y / 2
	end

	-- khoảng cách từ điểm trúng tới cạnh ô mẫu theo hướng (dx, dy), sai số dưới 5px
	-- d0 = khoảng cách thử đầu tiên (bằng bề rộng ô mẫu); trúng thì nhân đôi dần, trượt thì chia đôi dần
	local function edge(box, px, py, dx, dy, d0, tol)
		tol = tol or 5
		local lo, hi = 0, nil
		local d = d0
		for _ = 1, 4 do
			if tryAt(box, px + dx * d, py + dy * d) then
				lo = d
				d = d * 2
			else
				hi = d
				break
			end
		end
		if not hi then return lo end
		while hi - lo > tol do
			local mid = (lo + hi) / 2
			if tryAt(box, px + dx * mid, py + dy * mid) then lo = mid else hi = mid end
		end
		return (lo + hi) / 2
	end

	-- tìm 1 điểm bấm trúng ô mẫu: thử các điểm dự đoán trước, không được thì quét lưới quanh điểm dự đoán đầu tiên
	local function locate(box, cands)
		for _, c in ipairs(cands) do
			if unsupported then return nil end
			if tryAt(box, c[1], c[2]) then return c[1], c[2] end
		end
		if unsupported then return nil end
		local bx, by = cands[1][1], cands[1][2]
		for _, o in ipairs(CalibInfo.grid) do
			if unsupported then return nil end
			if not (o[1] == 0 and o[2] == 0) and tryAt(box, bx + o[1], by + o[2]) then
				return bx + o[1], by + o[2]
			end
		end
		return nil
	end

	local result = false
	local ok, err = pcall(function()
		local inset = GuiService:GetGuiInset()
		local ax1, ay1 = center(m1)
		local sx0 = knownScale and knownScale.sx or 1
		local sy0 = knownScale and knownScale.sy or 1

		-- các độ lệch dự đoán: đã đo ở giao diện khác (kể cả lệch thêm/bớt 1 thanh inset), rồi tới các giá trị thường gặp
		local offsets = {}
		for _, h in ipairs(hints or {}) do table.insert(offsets, { h[1], h[2] }) end
		for _, h in ipairs(hints or {}) do
			table.insert(offsets, { h[1], h[2] + inset.Y })
			table.insert(offsets, { h[1], h[2] - inset.Y })
		end
		table.insert(offsets, { 0, 0 })
		table.insert(offsets, { inset.X, inset.Y })
		table.insert(offsets, { 0, inset.Y })

		local cands, seen = {}, {}
		for _, o in ipairs(offsets) do
			local k = math.floor(o[1] + 0.5) .. "," .. math.floor(o[2] + 0.5)
			if not seen[k] then
				seen[k] = true
				table.insert(cands, { ax1 * sx0 + o[1], ay1 * sy0 + o[2] })
			end
		end
		-- chưa biết tỉ lệ: thử thêm vài tỉ lệ màn hình hay gặp (ô mẫu to ra theo tỉ lệ nên lệch vài chục px vẫn trúng)
		if not knownScale then
			for _, sc in ipairs({ 2, 3, 1.5, 2.625 }) do
				table.insert(cands, { ax1 * sc, ay1 * sc })
				table.insert(cands, { ax1 * sc, ay1 * sc + inset.Y })
			end
		end

		local px, py = locate(m1, cands)
		if not px then return end
		local w, h = m1.AbsoluteSize.X, m1.AbsoluteSize.Y

		-- ĐÃ BIẾT tỉ lệ: chỉ cần tìm cạnh phải và cạnh dưới, suy ra tâm (tổng cộng khoảng 10-12 lần bấm thử)
		if knownScale then
			local re = edge(m1, px, py, 1, 0, w * sx0)
			local de = edge(m1, px, py, 0, 1, h * sy0)
			local cx = px + re - (w / 2) * sx0
			local cy = py + de - (h / 2) * sy0
			result = { sx = sx0, sy = sy0, tx = cx - ax1 * sx0, ty = cy - ay1 * sy0 }
			return
		end

		-- CHƯA biết tỉ lệ (lần đầu): đo đủ 4 cạnh của ô 1 để có tâm + ước lượng tỉ lệ
		local re = edge(m1, px, py, 1, 0, w, 2.5)
		local le = edge(m1, px, py, -1, 0, w, 2.5)
		local de = edge(m1, px, py, 0, 1, h, 2.5)
		local ue = edge(m1, px, py, 0, -1, h, 2.5)
		local cx1, cy1 = px + (re - le) / 2, py + (de - ue) / 2
		local sx, sy = (re + le) / w, (de + ue) / h
		if math.abs(sx - 1) < 0.15 then sx = 1 end
		if math.abs(sy - 1) < 0.15 then sy = 1 end
		local tx, ty = cx1 - ax1 * sx, cy1 - ay1 * sy

		-- đo thêm ô 2 ở xa ô 1 để có tỉ lệ chính xác
		local ax2, ay2 = center(m2)
		local x2, y2 = locate(m2, { { ax2 * sx + tx, ay2 * sy + ty } })
		if x2 then
			local re2 = edge(m2, x2, y2, 1, 0, w * sx, 2.5)
			local le2 = edge(m2, x2, y2, -1, 0, w * sx, 2.5)
			local de2 = edge(m2, x2, y2, 0, 1, h * sy, 2.5)
			local ue2 = edge(m2, x2, y2, 0, -1, h * sy, 2.5)
			local cx2, cy2 = x2 + (re2 - le2) / 2, y2 + (de2 - ue2) / 2
			local dax, day = ax2 - ax1, ay2 - ay1
			if math.abs(dax) > 1 then sx = (cx2 - cx1) / dax end
			if math.abs(day) > 1 then sy = (cy2 - cy1) / day end
			if math.abs(sx - 1) < 0.03 then sx = 1 end
			if math.abs(sy - 1) < 0.03 then sy = 1 end
			tx = cx1 - ax1 * sx
			ty = cy1 - ay1 * sy
		end
		result = { sx = sx, sy = sy, tx = tx, ty = ty }
	end)
	pcall(function() gui:Destroy() end)
	if not ok then
		return false
	end
	return result
end

-- Các độ lệch đã đo thành công (dùng làm điểm thử đầu tiên cho giao diện kế tiếp)
local function collectHints()
	local hints, seen = {}, {}
	for _, e in pairs(Calib) do
		for _, m in ipairs({ "touch", "mouse" }) do
			local v = e[m]
			if type(v) == "table" then
				local k = math.floor(v.tx + 0.5) .. "," .. math.floor(v.ty + 0.5)
				if not seen[k] then
					seen[k] = true
					table.insert(hints, { v.tx, v.ty })
				end
			end
		end
	end
	return hints
end

-- Lấy bảng hiệu chỉnh cho 1 loại ScreenGui (đo 1 lần rồi nhớ lại). Trả về nil nếu phương thức bấm này không dùng được.
local function getMap(sg, method)
	if method == "touch" and CalibInfo.touchDead then return nil end
	local key, ignore, insets = probeKeyOf(sg)
	local entry = Calib[key]
	if not entry then
		entry = {}
		Calib[key] = entry
	end
	if entry[method] == nil then
		while calibBusy do task.wait(0.1) end
		entry = Calib[key]
		if not entry then
			entry = {}
			Calib[key] = entry
		end
		if entry[method] == nil then
			if method == "touch" and CalibInfo.touchDead then return nil end
			calibBusy = true
			local ok, res = pcall(runCalibration, ignore, insets, method, CalibInfo.scale[method], collectHints())
			calibBusy = false
			entry[method] = (ok and res) or false
			if ok and res then
				if not CalibInfo.scale[method] then
					CalibInfo.scale[method] = { sx = res.sx, sy = res.sy }
				end
			elseif method == "touch" then
				-- máy không nhận cảm ứng giả lập: khỏi tốn thời gian đo lại ở các giao diện khác
				CalibInfo.touchDead = true
			end
		end
	end
	return entry[method] or nil
end

local function applyMap(map, ax, ay)
	return ax * map.sx + map.tx, ay * map.sy + map.ty
end

-- Bấm chính giữa 1 nút GUI: cảm ứng nếu bật và đo được, không thì chuột (đã hiệu chỉnh), cuối cùng mới tới cách đoán cũ
local function pressGui(button, holdTime)
	holdTime = holdTime or 0.05
	local sg = button:FindFirstAncestorWhichIsA("ScreenGui")
	local ax = button.AbsolutePosition.X + button.AbsoluteSize.X / 2
	local ay = button.AbsolutePosition.Y + button.AbsoluteSize.Y / 2 + Config.CLICK_OFFSET_Y

	if Config.USE_TOUCH then
		local tmap = getMap(sg, "touch")
		if tmap then
			local x, y = applyMap(tmap, ax, ay)
			if touchPress(x, y, holdTime) then return "touch" end
		end
	end

	local mmap = getMap(sg, "mouse")
	local x, y
	if mmap then
		x, y = applyMap(mmap, ax, ay)
	else
		x, y = getGuiPoint(button)
		y = y + Config.CLICK_OFFSET_Y
	end
	pointerPress(x, y, holdTime)
	return "mouse"
end

local function describeMap(m)
	if m == nil then return "chưa đo" end
	if m == false then return "không dùng được" end
	local scale = ""
	if math.abs(m.sx - 1) > 0.01 or math.abs(m.sy - 1) > 0.01 then
		scale = string.format(", tỉ lệ %.2f/%.2f", m.sx, m.sy)
	end
	return string.format("OK (lệch %+.0f,%+.0f%s)", m.tx, m.ty, scale)
end

local function getFishingButton()
	return PlayerGui:FindFirstChild("FishingActionButton", true)
end

local function calibSummary()
	if calibBusy then return "Đang hiệu chỉnh bấm, đừng chạm màn hình..." end
	local entry = nil
	local fb = getFishingButton()
	if fb then entry = Calib[(probeKeyOf(fb:FindFirstAncestorWhichIsA("ScreenGui")))] end
	if not entry then
		for _, v in pairs(Calib) do
			entry = v
			break
		end
	end
	if not entry then return "Bấm: chưa hiệu chỉnh" end
	local mouseText = describeMap(entry.mouse)
	if entry.mouse == nil then mouseText = "chưa cần (dự phòng)" end
	return "Chuột: " .. mouseText .. "\nCảm ứng: " .. describeMap(entry.touch)
end

-- Hiệu chỉnh trước cho các loại giao diện mà script sẽ bấm vào
-- Có cảm ứng thì chỉ đo cảm ứng; chuột chỉ đo khi cảm ứng không dùng được
local function preCalibrate()
	local list = {}
	local function add(inst) if inst then table.insert(list, inst) end end
	add(getFishingButton())
	add(PlayerGui:FindFirstChild("ReelCounterGui", true))
	add(PlayerGui:FindFirstChild("SellAll", true))
	add(PlayerGui:FindFirstChild("Dialogue"))

	local function calibOne(sg)
		local tmap = nil
		if Config.USE_TOUCH then tmap = getMap(sg, "touch") end
		if not tmap then getMap(sg, "mouse") end
	end

	local seen = {}
	for _, inst in ipairs(list) do
		local sg = inst:IsA("ScreenGui") and inst or inst:FindFirstAncestorWhichIsA("ScreenGui")
		local key = probeKeyOf(sg)
		if not seen[key] then
			seen[key] = true
			calibOne(sg)
		end
	end
	if next(seen) == nil then
		calibOne(nil)
	end
end

local function pressFishingButton(holdTime)
	local button = getFishingButton()
	if button then
		pressGui(button, holdTime)
	else
		pointerPress(Config.TARGET_X, Config.TARGET_Y, holdTime)
	end
end

local function simulateClick()
	pressFishingButton(nil)
end

local function getActiveReelButton()
	local reelGui = PlayerGui:FindFirstChild("ReelCounterGui", true)
	if not reelGui then return nil end
	local directionNames = { "Left", "Right", "Up", "Down" }
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
			pressGui(dirButton, 0.05)
			return true, dirButton.Name
		end
	end

	local button = getFishingButton()
	if button then
		pressGui(button, 0.05)
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

-- ==================================================
-- AUTO SELL: tp tới NPC bán cá, thử nhiều cách bán, rồi tp về đúng chỗ đang câu
-- ==================================================

-- Cách 1: kích hoạt thẳng sự kiện của nút (không phụ thuộc toạ độ), cần executor có firesignal/getconnections
local function signalClick(button)
	local fired = false
	local function fire(signal)
		if firesignal then
			if pcall(firesignal, signal) then fired = true end
		elseif getconnections then
			local ok, conns = pcall(getconnections, signal)
			if ok and conns then
				for _, c in ipairs(conns) do
					pcall(function() c:Fire() end)
					fired = true
				end
			end
		end
	end
	fire(button.MouseButton1Click)
	fire(button.Activated)
	return fired
end

-- Cách 2: chọn nút bằng GuiService rồi nhấn Enter (cũng không phụ thuộc toạ độ)
local function selectClick(button)
	return pcall(function()
		GuiService.SelectedObject = button
		task.wait(0.1)
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
		task.wait(0.05)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
		task.wait(0.05)
		GuiService.SelectedObject = nil
	end)
end

-- Bấm 1 nút GUI. mode: "auto" (mặc định) | "signal" | "select" | "noinset" | "inset"
local function clickButton(button, mode)
	if not button or not button:IsA("GuiButton") then return false end
	mode = mode or "auto"
	if mode == "signal" then return signalClick(button) end
	if mode == "select" then return selectClick(button) end

	if mode == "noinset" or mode == "inset" then
		local x, y = getGuiPoint(button, mode == "inset")
		pointerPress(x, y, 0.05)
		return true
	end
	pressGui(button, 0.05)
	return true
end

-- Bấm nút "Bán tất cả" ở HUD
local function guiSell()
	local button = PlayerGui:FindFirstChild("HUD")
		and PlayerGui.HUD:FindFirstChild("Frame")
		and PlayerGui.HUD.Frame:FindFirstChild("SellAll")
		and PlayerGui.HUD.Frame.SellAll:FindFirstChild("Button")
	if button and button:IsA("GuiButton") then
		clickButton(button)
		return true
	end
	return false
end

local function normalizeText(s)
	local r = string.lower(tostring(s))
	r = r:gsub("^%s+", "")
	r = r:gsub("[%p%s]+$", "")
	return r
end

local function isDialogueOpen()
	local dialogue = PlayerGui:FindFirstChild("Dialogue")
	if not dialogue then return false end
	if dialogue:IsA("ScreenGui") and not dialogue.Enabled then return false end
	local frame = dialogue:FindFirstChild("Frame")
	return frame ~= nil and frame.Visible
end

-- Bấm 1 nút trong hộp thoại NPC (Dialogue.Frame.Actions)
local function dialogueClick(targets, mode)
	if type(targets) == "string" then targets = { targets } end
	if not isDialogueOpen() then return false end

	local actions = PlayerGui.Dialogue.Frame:FindFirstChild("Actions")
	if not actions then return false end

	for _, obj in ipairs(actions:GetDescendants()) do
		if obj:IsA("GuiButton") and obj.Visible and not (obj.Parent and obj.Parent:IsA("UIListLayout")) then
			local title = obj:FindFirstChild("Title")
			local text = (title and title:IsA("TextLabel")) and title.Text or (obj:IsA("TextButton") and obj.Text or "")
			if text == "" then
				for _, d in ipairs(obj:GetDescendants()) do
					if d:IsA("TextLabel") and d.Text ~= "" then
						text = d.Text
						break
					end
				end
			end
			local norm = normalizeText(text)
			for _, target in ipairs(targets) do
				if norm == normalizeText(target) then
					clickButton(obj, mode)
					return true
				end
			end
		end
	end
	return false
end

local CLICK_MODES = { "auto", "select", "signal", "noinset", "inset" }

-- Thoát khỏi NPC: bấm "Goodbye." / "Tạm biệt." — mỗi lần thử dùng 1 cách bấm khác nhau cho tới khi hộp thoại đóng
local function closeDialogue()
	for attempt = 1, 10 do
		if not isDialogueOpen() then return true end
		local mode = CLICK_MODES[(attempt - 1) % #CLICK_MODES + 1]
		dialogueClick({ "Goodbye", "Tạm biệt" }, mode)
		task.wait(0.5)
	end
	return not isDialogueOpen()
end

local function controllerSell()
	local controllers = ReplicatedStorage:FindFirstChild("Controllers")
	if not controllers then return false end
	local module = controllers:FindFirstChild("SellController")
	if not module or not module:IsA("ModuleScript") then return false end

	local ok, controller = pcall(require, module)
	if not ok or type(controller) ~= "table" then return false end

	local found = false
	for name, func in pairs(controller) do
		if type(func) == "function" and string.find(string.lower(tostring(name)), "sell") then
			pcall(function() func(controller) end)
			found = true
		end
	end
	return found
end

local function packetSell()
	local packetFolder = ReplicatedStorage:FindFirstChild("Stardust")
	if not packetFolder then return false end
	local packages = packetFolder:FindFirstChild("Packages")
	if not packages then return false end
	local packetModule = packages:FindFirstChild("Packet")
	if not packetModule or not packetModule:IsA("ModuleScript") then return false end

	local ok, packet = pcall(require, packetModule)
	if not ok or type(packet) ~= "table" then return false end

	local found = false
	for name, value in pairs(packet) do
		if type(value) == "function" then
			local n = string.lower(tostring(name))
			if string.find(n, "sellall") or string.find(n, "sellheld") or string.find(n, "sell") then
				pcall(function() value(packet) end)
				found = true
			end
		end
	end
	return found
end

local function rawRemote()
	local remote = ReplicatedStorage:FindFirstChild("Stardust")
	if not remote then return end
	local packages = remote:FindFirstChild("Packages")
	if not packages then return end
	local packet = packages:FindFirstChild("Packet")
	if not packet then return end
	local event = packet:FindFirstChild("RemoteEvent")
	if not event or not event:IsA("RemoteEvent") then return end

	pcall(function() event:FireServer(90) end)
	task.wait(0.15)
	pcall(function() event:FireServer(91) end)
end

-- Tách "đang có / tối đa" từ chữ dạng "12/50". Trả về (đang có, tối đa) hoặc nil, nil.
local function parseBagText(text)
	local c, m = tostring(text):match("(%d+)%s*/%s*(%d+)")
	if not c or not m then return nil, nil end
	local cur, max = tonumber(c), tonumber(m)
	if not max or max <= 0 then return nil, nil end
	return cur, max
end

-- Đọc nhãn sức chứa túi của game (SatchelModal.Frame.Capacity, chữ dạng "đang có/tối đa").
-- Đây là nguồn DUY NHẤT của sức chứa túi: số tối đa là của chính tài khoản đang chơi (túi đã nâng cấp thì tự cập nhật),
-- không có giá trị mặc định nào cả. Đọc không được thì trả về nil, nil.
local function readBagLabel()
	local satchel = PlayerGui:FindFirstChild("SatchelModal")
	local label = nil
	if satchel then
		local frame = satchel:FindFirstChild("Frame")
		label = frame and frame:FindFirstChild("Capacity")
	end
	if not label then
		label = PlayerGui:FindFirstChild("Capacity", true)
	end
	if label and label:IsA("TextLabel") then
		local c, m = parseBagText(label.Text)
		if c then return c, m end
	end

	-- dự phòng: nhãn bị đổi tên thì tìm nhãn chỉ gồm dạng "số/số" ngay trong SatchelModal
	if satchel then
		for _, d in ipairs(satchel:GetDescendants()) do
			if d:IsA("TextLabel") and not isInsideTemplate(d) and string.match(d.Text, "^%s*%d+%s*/%s*%d+%s*$") then
				local c, m = parseBagText(d.Text)
				if c then return c, m end
			end
		end
	end
	return nil, nil
end

-- Mỗi con cá trong túi là 1 Tool có tên dạng GUID nằm trong Backpack, đếm thẳng số cá thật
local function isGuidName(name)
	return string.match(name, "^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil
end

local function countFishTools()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not backpack then return nil end
	local n = 0
	for _, t in ipairs(backpack:GetChildren()) do
		if t:IsA("Tool") and isGuidName(t.Name) then n += 1 end
	end
	local char = LocalPlayer.Character
	if char then
		for _, t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") and isGuidName(t.Name) then n += 1 end
		end
	end
	return n
end

local function countFishInList()
	local satchel = PlayerGui:FindFirstChild("SatchelModal")
	local frame = satchel and satchel:FindFirstChild("Frame")
	local list = frame and frame:FindFirstChild("List")
	local scroll = list and list:FindFirstChild("ScrollingFrame")
	if not scroll then return 0 end
	local n = 0
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") and not string.find(child.Name, "Template", 1, true) then
			local button = child:FindFirstChild("Button")
			if button and button:FindFirstChild("FishWeightLabel") then n += 1 end
		end
	end
	return n
end

-- Trả về (số cá đang có, sức chứa túi thật của người chơi).
-- Sức chứa là nil nếu chưa đọc được từ game (không có giá trị mặc định): nơi dùng phải tự xử lý trường hợp nil.
-- Đã từng đọc được thì giữ số đó cho tới khi đọc được số mới (vd nâng cấp túi).
local function getInventoryFullness()
	local _, labelMax = readBagLabel()
	if labelMax then bagMax = labelMax end

	local count
	local tools = countFishTools()
	if tools then
		count = math.max(tools, countFishInList())
	else
		local labelCount = readBagLabel()
		count = labelCount or bagEstimate or 0
	end
	bagEstimate = count
	return count, bagMax
end

-- Bấm 1 nút trong hộp thoại lần lượt bằng nhiều cách; dừng khi hết thấy nút hoặc stopFn() trả về true
local function dialogueClickTry(targets, modes, stopFn)
	for _, mode in ipairs(modes) do
		if not isDialogueOpen() then return end
		if not dialogueClick(targets, mode) then return end
		task.wait(0.5)
		if stopFn and stopFn() then return end
	end
end

local function runSellStrategies()
	pcall(controllerSell)
	task.wait(0.1)
	pcall(packetSell)
	task.wait(0.1)
	pcall(guiSell)
	task.wait(0.1)
	pcall(function()
		dialogueClickTry({ "Sell All", "Bán tất cả" }, { "auto", "select", "signal", "noinset" }, function()
			local c = getInventoryFullness()
			return c == 0
		end)
	end)
	task.wait(0.2)
	pcall(function() dialogueClickTry({ "Xác nhận bán", "Confirm" }, { "auto", "signal" }) end)
	task.wait(0.3)
	pcall(rawRemote)
	task.wait(0.1)
end

local function findSellerPrompt(root)
	local best, bestScore = nil, math.huge
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			local parent = d.Parent
			local pos = nil
			if parent and parent:IsA("BasePart") then
				pos = parent.Position
			elseif parent and parent:IsA("Attachment") then
				pos = parent.WorldPosition
			end
			if pos then
				local dist = (pos - root.Position).Magnitude
				if dist <= 40 then
					local score = dist
					local name = string.lower(d:GetFullName())
					if name:find("seller") or name:find("merchant") or name:find("fish") then
						score = score - 1000
					end
					if score < bestScore then
						best, bestScore = d, score
					end
				end
			end
		end
	end
	return best
end

local function sellTrip()
	-- Bấm tương tác NPC bán cá (ProximityPrompt) rồi chờ hộp thoại mở
	local function openSellerDialogue()
		local newChar = LocalPlayer.Character
		local newRoot = newChar and newChar:FindFirstChild("HumanoidRootPart")
		local prompt = newRoot and findSellerPrompt(newRoot)
		if prompt then
			if fireproximityprompt then
				pcall(function() fireproximityprompt(prompt) end)
			else
				pcall(function() pressKey(Enum.KeyCode.E, (prompt.HoldDuration or 0) + 0.15) end)
			end
		else
			sellState = "Không thấy prompt NPC quanh toạ độ, vẫn thử bán..."
		end

		local t = 0
		while not isDialogueOpen() and t < 3 do
			task.wait(0.1)
			t += 0.1
		end
		task.wait(0.15)
	end

	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		sellState = "Lỗi: không thấy nhân vật"
		return
	end

	local originalCFrame = root.CFrame
	local wasFarming = isRunning

	if wasFarming and farmToggle then
		sellState = "Đang tắt Auto Farm..."
		farmSet(false)
		local waited = 0
		while mainLoopActive and waited < 5 do
			task.wait(0.1)
			waited += 0.1
		end
	end

	local ok, err = pcall(function()
		sellState = "Đang tp tới NPC..."
		FastTeleport(Config.SELL_POS)
		task.wait(0.6)

		openSellerDialogue()

		-- Bán; túi vẫn đầy thì bán lại ngay tại NPC (không đi về rồi đi lại nhiều lần), hết đầy thì thôi
		for attempt = 1, Config.SELL_MAX_ATTEMPTS do
			if attempt == 1 then
				sellState = "Đang bán cá..."
			else
				sellState = "Túi vẫn đầy, bán lại lần " .. attempt .. "..."
			end
			runSellStrategies()
			task.wait(1.5)
			local c, m = getInventoryFullness()
			if not (m and c >= m) then break end
			if attempt < Config.SELL_MAX_ATTEMPTS and not isDialogueOpen() then
				openSellerDialogue()
			end
		end

		sellState = "Đang thoát NPC..."
		closeDialogue()
		task.wait(0.2)
	end)
	if not ok then
		sellState = "Lỗi: " .. tostring(err)
	end

	if ok then sellState = "Đang về chỗ cũ..." end
	pcall(FastTeleport, originalCFrame)

	-- Về tới chỗ cũ: nhảy 1 cái cho nhân vật đứng vững rồi mới bật lại Auto Farm
	task.wait(0.5)
	if ok then sellState = "Nhảy 1 cái rồi bật lại câu..." end
	pcall(jumpOnce)

	task.wait(0.5)
	local c, m = getInventoryFullness()
	if ok then
		if m and c >= m then
			sellState = "Đã chạy xong nhưng túi vẫn " .. c .. "/" .. m .. " (có thể chưa bán được)"
		else
			sellState = "Bán xong lúc " .. os.date("%H:%M:%S") .. " (còn " .. c .. "/" .. (m or "?") .. ")"
		end
	end

	if wasFarming and farmToggle then
		task.wait(0.3)
		restoreFarm(true)
	end
end

-- Cả chuyến bán giữ khoá dịch chuyển; Auto Câu Boss thấy sellBusy là đứng yên nhường chỗ cho tới khi bán xong và về chỗ cũ
local function sellAtNPC()
	if sellBusy then return end
	sellBusy = true -- đặt trước để Auto Câu Boss dừng ngay từ lúc này, không tranh dịch chuyển
	if not Travel.wait("sell", 90) then
		sellState = "Đang bận dịch chuyển, chưa đi bán được, sẽ thử lại"
		sellBusy = false
		return
	end
	local ok, err = pcall(sellTrip)
	Travel.done("sell")
	if not ok then
		sellState = "Lỗi: " .. tostring(err)
	end
	sellBusy = false
end

-- Túi đầy thì đi bán; bán xong mà túi vẫn đầy thì bán lại (nghỉ vài giây giữa các chuyến), hết đầy thì thôi.
local function autoSellLoop()
	if sellLoopActive then return end
	sellLoopActive = true
	local ok, err = pcall(function()
		local failStreak = 0
		while isAutoSellRunning do
			local current, max = getInventoryFullness()
			if not max then
				-- chưa đọc được sức chứa túi thật của người chơi thì không đoán, không tự bán
				sellState = "Chưa đọc được sức chứa túi (nhãn Capacity), chưa thể tự bán"
				failStreak = 0
			elseif current >= max then
				sellAtNPC()
				task.wait(2)
				local after, afterMax = getInventoryFullness()
				if afterMax and after >= afterMax then
					failStreak += 1
					local delay = (failStreak <= 3) and Config.SELL_RETRY_DELAY or Config.SELL_RETRY_DELAY_LONG
					sellState = "Túi vẫn đầy " .. after .. "/" .. afterMax .. ", bán lại sau " .. delay .. "s (lần " .. failStreak .. ")"
					local w = 0
					while isAutoSellRunning and w < delay do
						task.wait(0.5)
						w += 0.5
					end
				else
					failStreak = 0
				end
			else
				failStreak = 0
			end
			task.wait(Config.SELL_CHECK_INTERVAL)
		end
	end)
	sellLoopActive = false
end

-- VÒNG LẶP AUTO SKILL (chỉ bấm những phím đang được bật trong Config.SKILL_ENABLED)
-- phần tử thứ 3 chỉ là nhãn hiển thị trên nút ở tab Farm; phím thật được bấm vẫn là phần tử thứ 2
local skillKeys = {
	{ "Z", Enum.KeyCode.Z, "1" },
	{ "X", Enum.KeyCode.X, "2" },
	{ "C", Enum.KeyCode.C, "3" },
	{ "V", Enum.KeyCode.V, "4" },
}
local function autoSkillLoop()
	if skillLoopActive then return end
	skillLoopActive = true
	local ok, err = pcall(function()
		while isAutoSkillRunning do
			local pressed = false
			for _, sk in ipairs(skillKeys) do
				if not isAutoSkillRunning then break end
				if Config.SKILL_ENABLED[sk[1]] then
					pressKey(sk[2], 0.1)
					task.wait(Config.SKILL_DELAY)
					pressed = true
				end
			end
			-- tắt hết kỹ năng thì nghỉ một chút, tránh vòng lặp chạy không nghỉ
			if not pressed then task.wait(0.3) end
		end
	end)
	skillLoopActive = false
end

-- VÒNG LẶP MAIN CÂU CÁ
local function mainLoop()
	if mainLoopActive then return end
	mainLoopActive = true

	local ok, err = pcall(function()
		while isRunning do
			ensureRodEquipped()
			if not isRunning then break end
			local serialAtCast = catchSerial
			pressFishingButton(Config.HOLD_TIME)

			if not isRunning then break end
			task.wait(1)

			if not isRunning then break end
			local isFishCaught = false
			local startedAt = os.clock()

			while isRunning and not isFishCaught do
				isFishCaught = (catchSerial ~= serialAtCast)
				if not isFishCaught then
					if os.clock() - startedAt > Config.CATCH_TIMEOUT then break end
					smartReelClick()
					task.wait(0.1)
				end
			end

			if isRunning and isFishCaught then
				for _ = 1, 6 do
					simulateClick()
					task.wait(0.2)
				end
				task.wait(0.3)
			end
		end
	end)

	mainLoopActive = false
end

-- ==================================================
-- CẤU HÌNH GAME (menu Settings trong game)
-- Menu Settings của game nằm ở PlayerGui.Settings.Frame.List, gồm nhiều khối con tên "toggle" (trùng tên nhau),
-- mỗi khối có toggle.text (nhãn) và toggle.button (ImageLabel chứa TextButton để bấm + TextLabel "On"/"Off").
-- Đọc/ghi thẳng vào các khối này theo Config.GAME_SETTINGS để giảm hiệu ứng hình ảnh gây lag (VFX, damage số, camera shake...).
-- ==================================================
local gameSettingsStatus = "Chưa áp dụng"

local function hasSignalClick()
	return firesignal ~= nil or getconnections ~= nil
end

-- Tìm khối toggle có nhãn khớp `label`. Trả về (nút bấm, nhãn trạng thái On/Off) hoặc nil.
local function findSettingsToggle(label)
	local settingsGui = PlayerGui:FindFirstChild("Settings")
	local frame = settingsGui and settingsGui:FindFirstChild("Frame")
	local list = frame and frame:FindFirstChild("List")
	if not list then return nil end
	local wanted = normalizeText(label)
	for _, child in ipairs(list:GetChildren()) do
		if child.Name == "toggle" and child:IsA("Frame") then
			local textLabel = child:FindFirstChild("text")
			if textLabel and textLabel:IsA("TextLabel") and normalizeText(textLabel.Text) == wanted then
				local btn = child:FindFirstChild("button")
				local textButton = btn and btn:FindFirstChild("TextButton")
				local stateLabel = btn and btn:FindFirstChild("TextLabel")
				if textButton and stateLabel then
					return textButton, stateLabel
				end
			end
		end
	end
	return nil
end

-- Mở menu Settings trong game bằng cách bấm nút Settings ở HUD (chỉ cần khi máy không hỗ trợ bấm bằng tín hiệu)
local function openGameSettingsMenu()
	local settingsGui = PlayerGui:FindFirstChild("Settings")
	local frame = settingsGui and settingsGui:FindFirstChild("Frame")
	if frame and frame.Visible and settingsGui.Enabled then return true end

	local openBtn = PlayerGui:FindFirstChild("HUD")
		and PlayerGui.HUD:FindFirstChild("Frame")
		and PlayerGui.HUD.Frame:FindFirstChild("Buttons")
		and PlayerGui.HUD.Frame.Buttons:FindFirstChild("Settings")
	if not openBtn then return false end
	pressGui(openBtn, 0.05)

	local t = 0
	while t < 3 do
		settingsGui = PlayerGui:FindFirstChild("Settings")
		frame = settingsGui and settingsGui:FindFirstChild("Frame")
		if frame and frame.Visible then return true end
		task.wait(0.5)
		t += 0.1
	end
	return false
end

local function closeGameSettingsMenu()
	local settingsGui = PlayerGui:FindFirstChild("Settings")
	local frame = settingsGui and settingsGui:FindFirstChild("Frame")
	local closeBtn = frame and frame:FindFirstChild("Close")
	if closeBtn then pressGui(closeBtn, 0.05) end
end

-- Đặt 1 công tắc trong Settings về đúng trạng thái mong muốn (want = true/false). Không làm gì nếu đã đúng sẵn.
local function setGameToggle(label, want)
	local textButton, stateLabel = findSettingsToggle(label)
	if not textButton then return false, "không tìm thấy trong menu Settings" end
	if (normalizeText(stateLabel.Text) == "on") == want then return true end

	local clicked = false
	if hasSignalClick() then clicked = signalClick(textButton) end
	if not clicked then clicked = clickButton(textButton, "auto") end
	task.wait(0.2)

	local _, verifyLabel = findSettingsToggle(label)
	if verifyLabel and (normalizeText(verifyLabel.Text) == "on") == want then return true end
	return false, "bấm rồi nhưng chưa xác nhận được trạng thái mới"
end

-- Áp toàn bộ Config.GAME_SETTINGS. Máy có firesignal/getconnections thì bấm ngầm, không cần mở menu lên màn hình;
-- không có thì phải tự mở menu Settings ra để bấm theo toạ độ, xong đóng lại.
local function applyGameSettings()
	local openedByUs = false
	if not hasSignalClick() then
		openedByUs = openGameSettingsMenu()
		if not openedByUs then
			gameSettingsStatus = "Không mở được menu Settings để chỉnh"
			return
		end
	end

	local okCount, failList = 0, {}
	for label, want in pairs(Config.GAME_SETTINGS) do
		local ok, err = setGameToggle(label, want)
		if ok then
			okCount += 1
		else
			table.insert(failList, label .. (err and (" (" .. err .. ")") or ""))
		end
		task.wait(0.1)
	end

	if openedByUs then closeGameSettingsMenu() end

	local total = okCount + #failList
	if #failList == 0 then
		gameSettingsStatus = "Đã áp dụng " .. okCount .. "/" .. total .. " mục lúc " .. os.date("%H:%M:%S")
	else
		gameSettingsStatus = "Áp dụng " .. okCount .. "/" .. total .. " mục, lỗi: " .. table.concat(failList, "; ")
	end
end

-- ==================================================
-- FIX LAG: ẩn toàn bộ map / model / hiệu ứng (chỉ ẩn phía client, không xoá gì của game)
-- Quét lại mỗi Config.FIXLAG_INTERVAL giây và ẩn tiếp thứ mới xuất hiện. Lần bật đầu tiên cũng tự áp
-- Config.GAME_SETTINGS (tắt VFX/damage số/camera shake trong menu Settings của game) để giảm lag thêm.
-- Tắt công tắc thì trả mọi thứ về như cũ (không tự bật lại các cài đặt game đã tắt).
-- ==================================================
local fixLagOn = false
local fixLagConn = nil
local fixLagLoopActive = false
local fixLagRecord = {}
local fixLagSaved = nil

local function fixLagSet(inst, prop, hidden)
	local rec = fixLagRecord[inst]
	if rec then
		if inst[prop] ~= hidden then inst[prop] = hidden end
	else
		fixLagRecord[inst] = { prop, inst[prop], hidden }
		inst[prop] = hidden
	end
end

local function fixLagHide(inst)
	if inst:IsA("Terrain") then return end
	local prop, hidden
	if inst:IsA("BasePart") then
		prop, hidden = "LocalTransparencyModifier", 1
	elseif inst:IsA("Decal") then
		prop, hidden = "Transparency", 1
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Fire")
		or inst:IsA("Smoke") or inst:IsA("Sparkles") or inst:IsA("Light")
		or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
		prop, hidden = "Enabled", false
	else
		return
	end
	local char = LocalPlayer.Character
	if char and inst:IsDescendantOf(char) then return end
	fixLagSet(inst, prop, hidden)
end

local function fixLagLighting()
	if not fixLagSaved then
		fixLagSaved = { shadows = Lighting.GlobalShadows }
		pcall(function() fixLagSaved.quality = settings().Rendering.QualityLevel end)
	end
	Lighting.GlobalShadows = false
	pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("PostEffect") then
			pcall(fixLagSet, e, "Enabled", false)
		elseif e:IsA("Atmosphere") then
			pcall(fixLagSet, e, "Density", 0)
		end
	end
end

local function fixLagScan()
	pcall(fixLagLighting)
	local n = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		if not fixLagOn then return end
		pcall(fixLagHide, inst)
		n += 1
		if n % 300 == 0 then task.wait() end
	end
end

local function fixLagLoop()
	if fixLagLoopActive then return end
	fixLagLoopActive = true
	while fixLagOn and ScreenGui.Parent do
		fixLagScan()
		-- máy bấm được bằng tín hiệu (không cần mở menu) thì đối chiếu lại cấu hình Settings mỗi vòng, rất rẻ
		if hasSignalClick() then pcall(applyGameSettings) end
		local waited = 0
		while fixLagOn and waited < Config.FIXLAG_INTERVAL do
			task.wait(0.5)
			waited += 0.5
		end
	end
	fixLagLoopActive = false
end

local function fixLagStart()
	if fixLagOn then return end
	fixLagOn = true
	if fixLagConn then fixLagConn:Disconnect() end
	fixLagConn = workspace.DescendantAdded:Connect(function(inst)
		-- đang tải đảo xa để quét boss: bỏ qua, vòng quét định kỳ (có nghỉ giữa chừng) sẽ xử lý sau, tránh dồn hàng nghìn tác vụ một lúc
		if os.clock() < BossScan.busyUntil then return end
		task.defer(function()
			if fixLagOn then pcall(fixLagHide, inst) end
		end)
	end)
	task.spawn(function() pcall(applyGameSettings) end)
	task.spawn(fixLagLoop)
end

fixLagStop = function()
	fixLagOn = false
	if fixLagConn then
		fixLagConn:Disconnect()
		fixLagConn = nil
	end
	local old = fixLagRecord
	fixLagRecord = {}
	for inst, rec in pairs(old) do
		pcall(function() inst[rec[1]] = rec[2] end)
	end
	if fixLagSaved then
		pcall(function() Lighting.GlobalShadows = fixLagSaved.shadows end)
		if fixLagSaved.quality then
			pcall(function() settings().Rendering.QualityLevel = fixLagSaved.quality end)
		end
		fixLagSaved = nil
	end
end

-- ==================================================
-- HÀM KÉO THẢ UI
-- ==================================================
local function MakeDraggable(object, dragArea)
	local dragging, dragStart, startPosition, hasDragged = false, nil, nil, false
	table.insert(connections, dragArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, hasDragged = true, false
			dragStart = input.Position
			startPosition = object.Position
		end
	end))
	table.insert(connections, dragArea.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			if delta.Magnitude > 10 then
				hasDragged = true
				object.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
			end
		end
	end))
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
Stroke(ToggleButton, Color3.fromRGB(255, 255, 255), 0.3, 1.5)

local ToggleIcon = Create("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "🎣",
	TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 20, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 101
}, ToggleButton)

local CheckToggleDrag = MakeDraggable(ToggleButton, ToggleButton)

local MainFrame = Create("Frame", {
	Name = "MainFrame", Size = UDim2.new(0, 0, 0, 0),
	Position = UDim2.new(0.5, -UITheme.MainSize.X.Offset / 2, 0.5, -UITheme.MainSize.Y.Offset / 2),
	BackgroundColor3 = UITheme.Background, BackgroundTransparency = 1,
	BorderSizePixel = 0, Visible = false, ClipsDescendants = true, ZIndex = 10
}, ScreenGui)
Corner(MainFrame, 16)
Stroke(MainFrame, Color3.fromRGB(255, 255, 255), 0.15, 1)

local Shadow = Create("ImageLabel", {
	Name = "Shadow", Size = UDim2.new(1, 60, 1, 60), Position = UDim2.new(0, -30, 0, -30),
	BackgroundTransparency = 1, Image = "rbxassetid://6014261993", ImageColor3 = Color3.fromRGB(0, 0, 0),
	ImageTransparency = 0.7, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450), ZIndex = 5
}, MainFrame)

local TitleBar = Create("Frame", {
	Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 20
}, MainFrame)
Corner(TitleBar, 16)
Create("Frame", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 20 }, TitleBar)

local avatarImage = "rbxasset://textures/ui/GuiImagePlaceholder.png"
pcall(function() avatarImage = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end)
local Logo = Create("ImageLabel", { Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(0, 14, 0.5, -18), BackgroundColor3 = UITheme.Accent, BackgroundTransparency = 0.1, Image = avatarImage, ZIndex = 21 }, TitleBar)
Corner(Logo, 10)

Create("TextLabel", { Size = UDim2.new(0, 300, 0, 25), Position = UDim2.new(0, 63, 0, 11), BackgroundTransparency = 1, Text = "CHISATO HUB", TextColor3 = UITheme.Text, TextSize = 17, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, TitleBar)
Create("TextLabel", { Size = UDim2.new(0, 300, 0, 20), Position = UDim2.new(0, 63, 0, 34), BackgroundTransparency = 1, Text = LocalPlayer.DisplayName, TextColor3 = UITheme.SubText, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, TitleBar)

local CloseButton = Create("TextButton", { Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -45, 0.5, -15), BackgroundColor3 = Color3.fromRGB(255, 59, 48), BackgroundTransparency = 0.2, Text = "×", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 22, Font = Enum.Font.GothamMedium, AutoButtonColor = false, ZIndex = 22 }, TitleBar)
Corner(CloseButton, 8)
MakeDraggable(MainFrame, TitleBar)

local Sidebar = Create("Frame", { Size = UDim2.new(0, 145, 1, -62), Position = UDim2.new(0, 0, 0, 62), BackgroundColor3 = Color3.fromRGB(240, 240, 245), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 15 }, MainFrame)
Create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, Sidebar)
Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, Sidebar)

local Content = Create("CanvasGroup", { Size = UDim2.new(1, -145, 1, -62), Position = UDim2.new(0, 145, 0, 62), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 16 }, MainFrame)

-- ==================================================
-- HỆ THỐNG TẠO TAB VÀ CHỨC NĂNG
-- ==================================================

local Tabs, TabButtons, CurrentTab = {}, {}, nil

local function CreateTab(tabName, icon)
	local TabButton = Create("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = UITheme.Accent, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = #TabButtons + 1, ZIndex = 20 }, Sidebar)
	Corner(TabButton, 10)
	local Icon = Create("TextLabel", { Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, Text = icon, TextColor3 = UITheme.SubText, TextSize = 16, Font = Enum.Font.GothamMedium, ZIndex = 21 }, TabButton)
	local Label = Create("TextLabel", { Size = UDim2.new(1, -42, 1, 0), Position = UDim2.new(0, 40, 0, 0), BackgroundTransparency = 1, Text = tabName, TextColor3 = UITheme.SubText, TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, TabButton)
	local TabFrame = Create("ScrollingFrame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = UITheme.Accent, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 18 }, Content)
	Create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }, TabFrame)
	Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, TabFrame)

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
	local Section = Create("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, ZIndex = 20 }, parent)
	Create("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = string.upper(title), TextColor3 = UITheme.SubText, TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, Section)
	return Section
end

local function CreateToggle(parent, text, default, callback)
	local State = default or false
	local Holder = Create("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = UITheme.Panel, BackgroundTransparency = 0.5, ZIndex = 20 }, parent)
	Corner(Holder, 10); Stroke(Holder, Color3.fromRGB(255, 255, 255), 0.2, 1)
	Create("TextLabel", { Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1, Text = text, TextColor3 = UITheme.Text, TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, Holder)

	local Switch = Create("TextButton", { Size = UDim2.new(0, 46, 0, 26), Position = UDim2.new(1, -58, 0.5, -13), BackgroundColor3 = Color3.fromRGB(210, 210, 220), Text = "", AutoButtonColor = false, ZIndex = 22 }, Holder)
	Corner(Switch, 100)
	local Knob = Create("Frame", { Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(0, 2, 0.5, -11), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 23 }, Switch)
	Corner(Knob, 100); Stroke(Knob, Color3.fromRGB(0, 0, 0), 0.85, 1)

	local function Update()
		if State then
			Tween(Switch, { BackgroundColor3 = UITheme.Accent }, 0.2); Tween(Knob, { Position = UDim2.new(1, -24, 0.5, -11) }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		else
			Tween(Switch, { BackgroundColor3 = Color3.fromRGB(210, 210, 220) }, 0.2); Tween(Knob, { Position = UDim2.new(0, 2, 0.5, -11) }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end

	Switch.MouseButton1Click:Connect(function()
		State = not State
		Tween(Switch, { Size = UDim2.new(0, 52, 0, 22), Position = UDim2.new(1, -61, 0.5, -11) }, 0.1)
		task.delay(0.1, function() Tween(Switch, { Size = UDim2.new(0, 46, 0, 26), Position = UDim2.new(1, -58, 0.5, -13) }, 0.2, Enum.EasingStyle.Bounce) end)
		Update()
		if callback then callback(State) end
	end)
	Update()

	return {
		Set = function(newState)
			if State == newState then return end
			State = newState
			Update()
			if callback then callback(State) end
		end,
		Get = function() return State end,
	}
end

local function CreateButton(parent, text, callback)
	local Btn = Create("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = UITheme.Panel, BackgroundTransparency = 0.5, Text = text, TextColor3 = UITheme.Text, TextSize = 12, Font = Enum.Font.GothamMedium, AutoButtonColor = false, ZIndex = 20 }, parent)
	Corner(Btn, 10); Stroke(Btn, Color3.fromRGB(255, 255, 255), 0.2, 1)
	Btn.MouseButton1Click:Connect(function()
		Tween(Btn, { BackgroundTransparency = 0.2 }, 0.1)
		task.delay(0.1, function() Tween(Btn, { BackgroundTransparency = 0.5 }, 0.2) end)
		if callback then callback() end
	end)
	return Btn
end

-- ==================================================
-- TAB 1: TRẠNG THÁI
-- ==================================================
local StatusTab = CreateTab("Trạng Thái", "📊")
CreateSection(StatusTab, "Chisato Hub Status")
statusLabel = Create("TextLabel", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "OFF", TextColor3 = UITheme.SubText, TextSize = 19, Font = Enum.Font.GothamBold, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 21 }, StatusTab)

local bagLabel = Create("TextLabel", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "", TextColor3 = UITheme.Text, TextSize = 13, Font = Enum.Font.GothamMedium, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 21 }, StatusTab)
local calibLabel = Create("TextLabel", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", TextColor3 = UITheme.SubText, TextSize = 11, Font = Enum.Font.Gotham, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 21 }, StatusTab)
task.spawn(function()
	while ScreenGui.Parent do
		local cur, mx = getInventoryFullness()
		if mx then
			bagLabel.Text = string.format("Túi đồ: %d/%d", cur, mx)
		else
			bagLabel.Text = string.format("Túi đồ: %d/? (chưa đọc được sức chứa túi)", cur)
		end
		calibLabel.Text = calibSummary()
		task.wait(1)
	end
end)

-- ==================================================
-- TAB 2: FARM
-- ==================================================
local FarmTab = CreateTab("Farm", "⚙")
CreateSection(FarmTab, "Tự Động Hoá")

farmToggle = CreateToggle(FarmTab, "Auto Farm", false, function(v)
	-- chỉ khi NGƯỜI DÙNG bấm công tắc mới ghi nhận ý muốn (script tạm tắt/bật thì đi qua farmSet, không tính)
	if not farmScriptToggle then farmUserWants = v end
	isRunning = v
	isAutoSkillRunning = v
	Config.AUTO_QTE = v
	setStatus("")
	if isRunning then
		task.spawn(mainLoop)
		task.spawn(autoSkillLoop)
	end
end)

-- Auto Câu Boss: khi có Boss Zone spawn thì tp tức thì tới đảo có boss, tìm chỗ đứng trên đảo gần boss nhất, rồi bật Auto Farm để ném cần.
-- Logic nằm ở cuối phần "TAB 4: BOSS ZONE" (cần dữ liệu quét boss), ở đây chỉ tạo công tắc.
local autoBossSetEnabled
CreateToggle(FarmTab, "Auto Câu Boss (tới Boss Zone)", false, function(v)
	if autoBossSetEnabled then autoBossSetEnabled(v) end
end)

-- Ô tuỳ chỉnh kỹ năng: bấm vào từng phím để bật/tắt (sáng xanh = dùng, xám = không dùng)
CreateSection(FarmTab, "Kỹ Năng Khi Auto Farm")
local SkillGrid = Create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, ZIndex = 20 }, FarmTab)
Create("UIGridLayout", { CellSize = UDim2.new(0.25, -5, 0, 34), CellPadding = UDim2.new(0, 6, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, SkillGrid)
for order, sk in ipairs(skillKeys) do
	local keyName = sk[1]
	local btn = Create("TextButton", { LayoutOrder = order, Size = UDim2.new(0, 60, 0, 34), BackgroundColor3 = UITheme.Accent, BackgroundTransparency = 0.1, Text = sk[3] or keyName, TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 15, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 20 }, SkillGrid)
	Corner(btn, 10)
	Stroke(btn, Color3.fromRGB(255, 255, 255), 0.2, 1)
	local function paint()
		if Config.SKILL_ENABLED[keyName] then
			Tween(btn, { BackgroundColor3 = UITheme.Accent, BackgroundTransparency = 0.1, TextColor3 = Color3.fromRGB(255, 255, 255) }, 0.15)
		else
			Tween(btn, { BackgroundColor3 = Color3.fromRGB(210, 210, 220), BackgroundTransparency = 0.3, TextColor3 = UITheme.SubText }, 0.15)
		end
	end
	paint()
	btn.MouseButton1Click:Connect(function()
		Config.SKILL_ENABLED[keyName] = not Config.SKILL_ENABLED[keyName]
		paint()
	end)
end

CreateSection(FarmTab, "Bán Cá")
CreateToggle(FarmTab, "Auto Sell (full đồ sẽ bán)", false, function(v)
	isAutoSellRunning = v
	if isAutoSellRunning then
		task.spawn(autoSellLoop)
	end
end)

-- ==================================================
-- TAB 3: ĐẢO (6 đảo, nút bấm xếp 2 cột)
-- ==================================================
local IslandTab = CreateTab("Đảo", "🏝️")
CreateSection(IslandTab, "Chọn Đảo")

local Islands = {
	{ "Đảo 1", Vector3.new(-42.06, 11.09, 333.26) },
	{ "Đảo 2", Vector3.new(-1219.25, 10.53, -96.02) },
	{ "Đảo 3", Vector3.new(-32.03, 9.40, -1013.22) },
	{ "Đảo 4", Vector3.new(1210.61, 9.72, -331.24) },
	{ "Đảo 5", Vector3.new(1861.87, 9.65, 1087.61) },
	{ "Đảo 6", Vector3.new(-564.92, 10.55, 2227.39) },
}

local IslandGrid = Create("Frame", { Size = UDim2.new(1, 0, 0, 104), BackgroundTransparency = 1, ZIndex = 20 }, IslandTab)
Create("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 0, 32), CellPadding = UDim2.new(0, 6, 0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, IslandGrid)

for _, island in ipairs(Islands) do
	local name, pos = island[1], island[2]
	CreateButton(IslandGrid, "Tới " .. name, function()
		if not Travel.try("island") then return end -- đang bán cá / đang dịch chuyển khác: bỏ qua cú bấm
		task.spawn(function()
			pcall(FastTeleport, pos)
			Travel.done("island")
		end)
	end)
end

-- ==================================================
-- TAB 4: BOSS ZONE
-- Boss zone của game nằm ở World.Islands.<đảo>.BossRegions (mỗi vùng là 1 Part, bên trong có hiệu ứng BossSpawnerFX).
-- Đảo xa chưa được game tải ra (chỉ còn khung SpawnPoint/Zones, chưa có BossRegions) nên script yêu cầu game tải
-- từng đảo (RequestStreamAroundAsync) rồi quét và nhớ kết quả, không cần bay tới đảo.
-- Các đảo được quét lần lượt (cách đều nhau), mỗi đảo xa quét lại sau ~30 giây; đợi lúc máy mượt mới tải đảo để không giật.
--
-- FIX "lâu lâu không quét được nữa":
--  1) Trước đây 3 lần tải đảo lỗi liền nhau (vd hết thời gian chờ) là tắt hẳn quét đảo xa vĩnh viễn. Giờ lỗi chỉ là tạm thời, lần quét sau thử lại.
--  2) RequestStreamAroundAsync có thể treo rất lâu làm cả đợt quét bị kẹt mãi. Giờ mỗi lần tải có giới hạn thời gian cứng,
--     và đợt quét bị kẹt quá 150 giây sẽ tự được thay bằng đợt mới.
--  3) Vòng quét trước đây ghi đè kết quả của đảo xa bằng dữ liệu rỗng ngay khi game gỡ đảo đó khỏi bộ nhớ
--     (làm boss vừa thấy đã biến mất). Giờ đảo xa chỉ được cập nhật khi vùng boss đang thực sự được tải.
--  4) Mỗi thư mục đảo chỉ được gán cho đúng 1 đảo (đảo gần nhất) và được nhớ lại, tránh đảo chưa tải bị gán nhầm thư mục của đảo bên cạnh.
-- ==================================================
local BossTab = CreateTab("Boss Zone", "👹")
CreateSection(BossTab, "Trạng thái spawn")

local BOSS_GREEN = Color3.fromRGB(52, 199, 89)
local BOSS_GREY = UITheme.SubText

local bossRows = {}
local bossButtons = {}
local teleportToBoss -- gán ở dưới (cần các hàm quét boss)
for i, island in ipairs(Islands) do
	local holder = Create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = UITheme.Panel, BackgroundTransparency = 0.5, ZIndex = 20 }, BossTab)
	Corner(holder, 8)
	local row = Create("TextLabel", { Size = UDim2.new(1, -66, 1, 0), BackgroundTransparency = 1, Text = island[1] .. ": đang quét", TextColor3 = BOSS_GREY, TextSize = 11, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21 }, holder)
	Create("UIPadding", { PaddingLeft = UDim.new(0, 10) }, row)
	local goBtn = Create("TextButton", { Size = UDim2.new(0, 52, 0, 22), Position = UDim2.new(1, -58, 0.5, -11), BackgroundColor3 = UITheme.Accent, BackgroundTransparency = 0.65, Text = "Tới", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 12, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 22 }, holder)
	Corner(goBtn, 8)
	goBtn.MouseButton1Click:Connect(function()
		if teleportToBoss then teleportToBoss(i) end
	end)
	bossRows[i] = row
	bossButtons[i] = goBtn
end

local bossInfo = Create("TextLabel", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", TextColor3 = UITheme.SubText, TextSize = 11, Font = Enum.Font.Gotham, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 21 }, BossTab)

local bossMemory = {}
local bossStreamSupported = nil
local bossStreamStatus = "Chưa quét đảo xa"
-- trạng thái của Auto Câu Boss (công tắc ở tab Farm, logic ở cuối phần Boss Zone)
local autoBossOn = false
local autoBossState = ""

-- Vị trí đại diện của 1 folder đảo: lấy toạ độ 1 BasePart bất kỳ bên trong, không cần biết tên
local function anyPartPosition(folder)
	if folder:IsA("BasePart") then return folder.Position end
	local part = folder:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

-- Với mỗi đảo đã biết toạ độ (Islands[i]), tìm folder đảo trong Workspace.World.Islands.
-- Mỗi folder chỉ thuộc về ĐÚNG 1 đảo (đảo gần nó nhất), và folder đã tìm thấy được nhớ lại.
local ISLAND_MATCH_RADIUS = 1500
local islandFolderCache = {}
local function findIslandFolder(i)
	local cached = islandFolderCache[i]
	if cached and cached.Parent then return cached end

	local world = workspace:FindFirstChild("World")
	local islandsFolder = world and world:FindFirstChild("Islands")
	if not islandsFolder then return nil end

	local best, bestDist = nil, ISLAND_MATCH_RADIUS
	for _, folder in ipairs(islandsFolder:GetChildren()) do
		local pos = anyPartPosition(folder)
		if pos then
			-- đảo nào gần folder này nhất?
			local nearestIdx, nearestDist = nil, math.huge
			for k, isl in ipairs(Islands) do
				local d = (pos - isl[2]).Magnitude
				if d < nearestDist then nearestIdx, nearestDist = k, d end
			end
			if nearestIdx == i and nearestDist < bestDist then
				best, bestDist = folder, nearestDist
			end
		end
	end
	if best then islandFolderCache[i] = best end
	return best
end

-- Quét boss zone. Luôn trả về đủ kết quả cho cả 6 đảo (kể cả đảo chưa tìm thấy folder), theo đúng thứ tự 1-6.
-- onlyIndex (tuỳ chọn): chỉ quét thật 1 đảo, các đảo còn lại trả về mục rỗng (nhanh hơn khi chỉ cần 1 đảo).
-- entry.present: có thư mục BossRegions; entry.loaded: nội dung vùng boss đã thực sự được tải (Part/hiệu ứng có mặt).
local function scanBossZones(onlyIndex)
	local result = {}
	for i in ipairs(Islands) do
		local entry = { present = false, loaded = false, active = {}, pos = nil }
		result[i] = entry
		if not onlyIndex or onlyIndex == i then
			local folder = findIslandFolder(i)
			if folder then
				local regions = folder:FindFirstChild("BossRegions")
				if regions then
					entry.present = true
					for _, region in ipairs(regions:GetChildren()) do
						if region:IsA("BasePart") then entry.loaded = true end
						for _, d in ipairs(region:GetDescendants()) do
							local isFx = d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")
							if isFx or d:IsA("BasePart") then entry.loaded = true end
							if isFx and d.Enabled then
								table.insert(entry.active, region.Name)
								-- nhớ vị trí vùng boss đầu tiên đang spawn để nút "Tới" dịch chuyển đến
								if not entry.pos then
									if region:IsA("BasePart") then
										entry.pos = region.Position
									elseif region:IsA("Model") then
										entry.pos = region:GetPivot().Position
									else
										local part = d:FindFirstAncestorWhichIsA("BasePart")
										if part then entry.pos = part.Position end
									end
								end
								break
							end
						end
					end
				end
			end
		end
	end
	return result
end

local function nearIsland(i)
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	return (root.Position - Islands[i][2]).Magnitude < 900
end

local function rememberBoss(result, i, remote)
	local e = result[i]
	if not e then return end
	bossMemory[i] = { present = e.present, active = e.active, pos = e.pos, t = os.clock(), remote = remote }
end

-- Đọc boss zone của đảo i sau khi đã yêu cầu tải. Đảo xa: chờ tối đa maxWait giây cho tới khi vùng boss tải xong.
-- Đảo xa mà vùng boss chưa tải được thì KHÔNG ghi đè dữ liệu cũ (tránh biến "đã spawn" thành "chưa spawn" oan);
-- chỉ khi chưa có dữ liệu gì mới ghi nhận "chưa thấy boss zone". Trả về true nếu đọc được dữ liệu thật.
local function readIslandWhenLoaded(i, remote, maxWait)
	local waited = 0
	local r = scanBossZones(i)
	while remote and not (r[i] and r[i].present and r[i].loaded) and waited < maxWait do
		task.wait(0.25)
		waited += 0.25
		r = scanBossZones(i)
	end
	if r[i] and r[i].present and (r[i].loaded or not remote) then
		rememberBoss(r, i, remote)
		return true
	end
	if remote and not bossMemory[i] then
		rememberBoss(r, i, true)
	end
	return false
end

-- Làm mới dữ liệu 1 đảo ngay lúc này (đảo xa thì yêu cầu game tải đảo trước)
local function refreshBossIsland(i)
	local remote = not nearIsland(i)
	if remote then
		BossScan.busyUntil = os.clock() + 12
		requestStream(Islands[i][2], 4)
	end
	readIslandWhenLoaded(i, remote, 2)
	return bossMemory[i]
end

-- Dịch chuyển tới vùng boss đang spawn của đảo i.
-- Đảo xa thì yêu cầu game tải đảo và quét lại trước để chắc chắn boss vẫn còn (thông tin cũ có thể đã hết hạn).
teleportToBoss = function(i)
	if sellBusy or not Travel.try("bosstp") then return end -- tránh tp chồng lên lúc đang đi bán cá / dịch chuyển khác
	task.spawn(function()
		local ok, err = pcall(function()
			local island = Islands[i]
			local mem = refreshBossIsland(i)
			if not (mem and mem.present and #mem.active > 0 and mem.pos) then
				pcall(notifyOwnFish, "Boss Zone", island[1], "chưa có boss spawn", true)
				return
			end
			FastTeleport(mem.pos + Vector3.new(0, 6, 0))
		end)
		Travel.done("bosstp")
	end)
end

-- Quét 1 đảo XA: yêu cầu game tải đảo rồi đọc boss zone (xem runBossBatch bên dưới).
local function scanRemoteIsland(i)
	local island = Islands[i]
	if bossStreamSupported == false then return end

	local reqOk, reqErr = requestStream(island[2], 3)
	if reqOk then
		bossStreamSupported = true
	else
		local msg = string.lower(tostring(reqErr))
		if string.find(msg, "not a valid member", 1, true) or string.find(msg, "nil value", 1, true) then
			-- chỉ khi game/executor hoàn toàn không có hàm này mới tắt hẳn
			bossStreamSupported = false
			bossStreamStatus = "Game không hỗ trợ tải đảo xa: " .. tostring(reqErr)
			return
		end
		-- lỗi tạm thời (hết thời gian chờ, ...): không tắt quét, lần quét sau thử lại; vẫn thử đọc phần đã có sẵn
		bossStreamStatus = island[1] .. ": tải đảo lỗi tạm thời, sẽ thử lại ở lần quét sau"
	end

	readIslandWhenLoaded(i, true, 2)
end

-- Quét TẤT CẢ đảo 1-6 LẦN LƯỢT (cách nhau 0.6s/đảo, không bắn hết yêu cầu tải đảo cùng lúc để đỡ giật lag):
-- đảo xa được tải và đọc từng đảo một, đảo gần thì đọc thẳng. Không quét khi đang đi bán ở NPC, đang dịch chuyển đảo
-- hoặc đang dịch chuyển tới boss, vì lúc đó nhân vật vừa đổi chỗ nên vị trí chưa ổn định, dễ
-- khiến 1 vài đảo bị tính sai gần/xa hoặc việc tải đảo báo lỗi.
local bossBatchRunning = false
local bossBatchStartedAt = 0
local function runBossBatch()
	-- đợt quét cũ bị kẹt quá 150 giây thì cho phép đợt mới thay thế
	if bossBatchRunning and os.clock() - bossBatchStartedAt < 150 then return end
	bossBatchRunning = true
	bossBatchStartedAt = os.clock()
	local myRun = bossBatchStartedAt

	local ok, err = pcall(function()
		local waited = 0
		while Travel.busy() and ScreenGui.Parent and waited < 60 do
			bossStreamStatus = "Đang bán cá / dịch chuyển, hoãn quét boss..."
			task.wait(1)
			waited += 1
		end
		if not ScreenGui.Parent or Travel.busy() then return end

		local remoteIslands = {}
		for i in ipairs(Islands) do
			if nearIsland(i) then
				pcall(function() rememberBoss(scanBossZones(i), i, false) end)
			else
				table.insert(remoteIslands, i)
			end
		end

		if #remoteIslands > 0 and bossStreamSupported ~= false then
			for idx, i in ipairs(remoteIslands) do
				if not ScreenGui.Parent or Travel.busy() or bossStreamSupported == false then break end
				-- Fix Lag nhường chỗ trong lúc dữ liệu từng đảo lần lượt đổ về
				BossScan.busyUntil = os.clock() + 12
				bossStreamStatus = "Đang tải đảo xa " .. idx .. "/" .. #remoteIslands .. " để quét..."
				pcall(scanRemoteIsland, i)
				if idx < #remoteIslands then task.wait(0.6) end
			end
			BossScan.busyUntil = os.clock() + 2
		end

		bossStreamStatus = "Quét xong lúc " .. os.date("%H:%M:%S")
	end)
	if not ok then bossStreamStatus = "Lỗi quét đảo xa: " .. tostring(err) end
	if bossBatchStartedAt == myRun then bossBatchRunning = false end
end

task.spawn(function()
	local wasActive = {}
	local baselineDone = false
	while ScreenGui.Parent do
		local ok, err = pcall(function()
			local result = scanBossZones()
			for i, island in ipairs(Islands) do
				local e = result[i]
				if e and (e.present or nearIsland(i)) then
					if nearIsland(i) then
						rememberBoss(result, i, false)
					elseif e.loaded then
						-- đảo xa: chỉ cập nhật khi vùng boss đang thực sự được tải, không thì giữ kết quả của lần quét trước
						rememberBoss(result, i, true)
					end
				end
				local mem = bossMemory[i]
				local row = bossRows[i]
				local active = false
				if not mem then
					row.Text = island[1] .. ": chưa quét"
					row.TextColor3 = BOSS_GREY
				else
					local age = ""
					if mem.remote then age = " · " .. math.floor(os.clock() - mem.t) .. "s trước" end
					if mem.present and #mem.active > 0 then
						active = true
						row.Text = island[1] .. ": ĐÃ SPAWN (zone " .. table.concat(mem.active, ", ") .. ")" .. age
						row.TextColor3 = BOSS_GREEN
					elseif mem.present then
						row.Text = island[1] .. ": chưa spawn" .. age
						row.TextColor3 = BOSS_GREY
					else
						row.Text = island[1] .. (mem.remote and ": chưa thấy boss zone" or ": chưa spawn") .. age
						row.TextColor3 = BOSS_GREY
					end
				end
				if bossButtons[i] then
					bossButtons[i].BackgroundTransparency = active and 0.1 or 0.65
				end
				-- Thông báo boss vừa spawn hiện lâu hơn hẳn (Config.BOSS_NOTIFY_DURATION = 60 giây) rồi mới tự tắt,
				-- thay vì chỉ ~3.5 giây như thông báo câu cá bình thường. Chỉ bắn 1 lần đúng lúc chuyển từ "chưa spawn" -> "đã spawn".
				if baselineDone and active and not wasActive[i] then
					pcall(notifyOwnFish, "Boss Zone", island[1], "đã spawn", true, Config.BOSS_NOTIFY_DURATION)
				end
				wasActive[i] = active
			end
			baselineDone = true
			local info = bossStreamStatus
			if autoBossOn and autoBossState ~= "" then
				info = info .. "\nAuto Câu Boss: " .. autoBossState
			end
			bossInfo.Text = info
		end)
		task.wait(Config.BOSS_SCAN_INTERVAL)
	end
end)

-- ==================================================
-- AUTO CÂU BOSS (công tắc ở tab Farm)
-- Khi có boss zone đang spawn: tp tức thì tới đảo đó, tìm điểm đứng được TRÊN ĐẢO gần vùng boss nhất
-- (bắn tia xuống đất theo các vòng tròn lớn dần quanh vùng boss), quay mặt về phía boss rồi bật Auto Farm để ném cần.
-- TRÌNH TỰ (Auto Farm, Auto Câu Boss, Auto Sell chạy lần lượt, không dịch chuyển chồng nhau nhờ khoá dịch chuyển):
--   Có boss : tắt Auto Farm -> tp tới chỗ đứng gần boss -> xoay mặt + camera về boss -> bật Auto Farm ném cần
--             -> KHOÁ vị trí và hướng nhìn (shift lock hay xoay lệch thì tự chỉnh lại mỗi giây; Anti TP chặn game kéo về chỗ cũ)
--   Túi đầy : Auto Câu Boss đứng yên, Auto Sell tắt câu -> đi bán (bán lại nếu còn đầy) -> về đúng chỗ đang đứng -> nhảy 1 cái -> bật lại câu
--   Boss hết: (liên tục ~8 giây) tắt câu -> đợi BOSS_RETURN_DELAY giây -> tp về chỗ farm cũ -> nhảy 1 cái
--             -> bật lại Auto Farm theo ý người dùng (farmUserWants) và đợi vòng câu chạy thật (restoreFarm)
-- ==================================================
do
	local loopActive = false

	-- Tắt Auto Farm và đợi vòng câu dừng hẳn trước khi dịch chuyển (giống lúc đi bán cá)
	local function pauseFarmForTravel()
		if isRunning and farmToggle then
			farmSet(false)
			local waited = 0
			while mainLoopActive and waited < 5 do
				task.wait(0.1)
				waited += 0.1
			end
		end
	end

	-- Chọn đảo có boss đang spawn gần người chơi nhất (bỏ qua đảo đang trong thời gian nghỉ skipUntil)
	local function pickActiveBossIsland(skipUntil)
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local best, bestDist = nil, math.huge
		for i in ipairs(Islands) do
			local mem = bossMemory[i]
			if mem and mem.present and #mem.active > 0 and mem.pos and os.clock() >= (skipUntil[i] or 0) then
				local d = root and (root.Position - mem.pos).Magnitude or 0
				if d < bestDist then best, bestDist = i, d end
			end
		end
		return best
	end

	-- Tìm điểm đứng được trên đảo i gần bossPos nhất. Trả về vị trí mặt đất hoặc nil.
	local function findStandSpot(i, bossPos)
		local refY = Islands[i][2].Y
		local folder = findIslandFolder(i)

		local ignore = {}
		local char = LocalPlayer.Character
		if char then table.insert(ignore, char) end
		local regions = folder and folder:FindFirstChild("BossRegions")
		if regions then table.insert(ignore, regions) end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.IgnoreWater = true

		local function groundAt(x, z)
			local origin = Vector3.new(x, math.max(bossPos.Y, refY) + 200, z)
			local hit = workspace:Raycast(origin, Vector3.new(0, -500, 0), params)
			if not hit then return nil end
			if hit.Normal.Y < 0.7 then return nil end -- chỉ nhận mặt phẳng, không đứng trên dốc đứng
			if hit.Position.Y < refY - 8 then return nil end -- thấp hơn mặt đảo nhiều = đáy biển
			local inst = hit.Instance
			if inst:IsA("Terrain") then return hit.Position end
			if inst.CanCollide and (not folder or inst:IsDescendantOf(folder)) then return hit.Position end
			return nil
		end

		local tested = 0
		for radius = 0, 600, 15 do
			local n = (radius == 0) and 1 or math.max(8, math.floor(radius / 6))
			for k = 0, n - 1 do
				local ang = (k / n) * math.pi * 2
				local g = groundAt(bossPos.X + math.cos(ang) * radius, bossPos.Z + math.sin(ang) * radius)
				if g then return g end
				tested += 1
				if tested % 40 == 0 then task.wait() end
			end
		end
		return nil
	end

	-- Quay nhân vật VÀ camera về phía pos. Shift lock xoay nhân vật theo hướng camera, nên nếu chỉ xoay nhân vật
	-- thì lát sau nó bị xoay lệch lại; chỉnh cả camera (giữ nguyên độ ngẩng/cúi) thì hướng nhìn được giữ vững.
	local function aimAt(pos)
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local flat = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
		if flat.Magnitude < 1 then return end
		local dir = flat.Unit
		setRootCFrame(root, CFrame.lookAt(root.Position, root.Position + dir))
		local cam = workspace.CurrentCamera
		if cam then
			local cf = cam.CFrame
			local py = cf.LookVector.Y
			local h = math.sqrt(math.max(0, 1 - py * py))
			cam.CFrame = CFrame.lookAt(cf.Position, cf.Position + dir * h + Vector3.new(0, py, 0))
		end
	end

	-- Nhân vật đang nhìn lệch bao nhiêu độ so với hướng về pos
	local function facingOff(root, pos)
		local flat = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
		if flat.Magnitude < 1 then return 0 end
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if look.Magnitude < 0.01 then return 180 end
		return math.deg(math.acos(math.clamp(look.Unit:Dot(flat.Unit), -1, 1)))
	end

	-- Khoá vị trí + hướng nhìn lúc câu boss (gọi mỗi giây). Trả về "ok" | "left" (người chơi tự đi chỗ khác, buông khoá) | "nochar".
	local function holdPosition(standCF, bossPos)
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return "nochar" end
		local drift = (root.Position - standCF.Position).Magnitude
		if drift > 60 then return "left" end
		if drift > 6 then
			-- bị đẩy / kéo lệch chỗ: đặt lại đúng chỗ đứng
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			setRootCFrame(root, standCF)
			aimAt(bossPos)
		elseif facingOff(root, bossPos) > 12 then
			aimAt(bossPos)
		end
		return "ok"
	end

	-- Đi tới boss của đảo i (mem = dữ liệu boss vừa làm mới): tìm chỗ đứng, tp tức thì tới đó, quay mặt về boss.
	-- Trả về arrived, chỗ đứng (CFrame), vị trí boss. Gọi khi đang giữ khoá dịch chuyển.
	local function travelToBoss(i, mem)
		local island = Islands[i]
		local arrived, goal, bossPos = false, nil, nil
		local ok, err = pcall(function()
			local char = LocalPlayer.Character
			if not (char and char:FindFirstChild("HumanoidRootPart")) then return end

			bossPos = mem.pos
			if not nearIsland(i) then
				BossScan.busyUntil = os.clock() + 12
				requestStream(bossPos, 4)
			end

			autoBossState = "Tìm chỗ đứng gần boss " .. island[1] .. "..."
			local ground = findStandSpot(i, bossPos)
			local standPos = ground and (ground + Vector3.new(0, 3.5, 0)) or island[2]
			local flat = Vector3.new(bossPos.X, standPos.Y, bossPos.Z)
			goal = ((flat - standPos).Magnitude > 1) and CFrame.lookAt(standPos, flat) or CFrame.new(standPos)

			autoBossState = "Đang tới boss " .. island[1] .. "..."
			FastTeleport(goal)
			task.wait(0.3)
			aimAt(bossPos) -- xoay cả nhân vật lẫn camera về phía boss
			arrived = true
		end)
		return arrived, goal, bossPos
	end

	local function autoBossLoop()
		if loopActive then return end
		loopActive = true

		local skipUntil = {} -- đảo vừa kiểm tra thấy hết boss / không tới được: nghỉ 30 giây rồi mới thử lại
		local atIsland, originCF, farmWasOn, goneSince, standCF, bossPos = nil, nil, false, nil, nil, nil
		local ok, err = pcall(function()
			while autoBossOn and ScreenGui.Parent do
				if Travel.busy() then
					-- đang bán cá / đang có dịch chuyển khác: đứng yên nhường chỗ, xong mới làm tiếp
					task.wait(1)
				elseif not atIsland then
					autoBossState = "Chờ boss spawn"
					local i = pickActiveBossIsland(skipUntil)
					if i and Travel.try("boss") then
						local island = Islands[i]
						local char = LocalPlayer.Character
						local root = char and char:FindFirstChild("HumanoidRootPart")
						local before = root and root.CFrame -- chỗ đang farm, để quay về sau khi hết boss
						local wasOn = isRunning

						local tOk, tErr = pcall(function()
							-- kiểm tra lại boss còn không trước khi động vào Auto Farm
							autoBossState = "Kiểm tra boss " .. island[1] .. "..."
							local mem = refreshBossIsland(i)
							if not (mem and mem.present and #mem.active > 0 and mem.pos) then
								skipUntil[i] = os.clock() + 30
								return
							end

							-- tắt Auto Farm -> tp tới boss -> bật lại Auto Farm để ném cần
							pauseFarmForTravel()
							local arrived, goal, bp = travelToBoss(i, mem)
							if arrived then
								atIsland, originCF, farmWasOn, goneSince, standCF, bossPos = i, before, wasOn, nil, goal, bp
								if autoBossOn then restoreFarm(true) end
								autoBossState = "Đang câu boss " .. island[1]
							else
								skipUntil[i] = os.clock() + 30
							end
						end)
						Travel.done("boss")
						if not tOk then
							skipUntil[i] = os.clock() + 30
						end
						-- không tới được boss (hoặc lỗi giữa chừng): trả Auto Farm về như cũ
						if not atIsland and (wasOn or farmUserWants) and autoBossOn and not isRunning then
							restoreFarm(true)
						end
					end
					task.wait(2)
				else
					local mem = bossMemory[atIsland]
					local active = mem and mem.present and #mem.active > 0
					if active then
						goneSince = nil
						local st = holdPosition(standCF, bossPos)
						if st == "left" then
							-- người chơi tự dịch chuyển đi chỗ khác: buông khoá, không kéo về nữa
							atIsland, originCF, goneSince, standCF, bossPos = nil, nil, nil, nil, nil
							autoBossState = "Chờ boss spawn"
						else
							autoBossState = "Đang câu boss " .. Islands[atIsland][1]
						end
					else
						goneSince = goneSince or os.clock()
						autoBossState = "Boss đã hết, chuẩn bị quay về..."
						if os.clock() - goneSince >= 8 and Travel.try("boss") then
							local rOk, rErr = pcall(function()
								-- tắt câu -> đợi chút -> tp về chỗ farm cũ -> nhảy 1 cái -> bật lại Auto Farm theo ý người dùng
								autoBossState = "Tắt câu, đợi rồi quay về chỗ cũ..."
								pauseFarmForTravel()
								task.wait(Config.BOSS_RETURN_DELAY)
								if originCF then FastTeleport(originCF) end
								task.wait(0.5)
								autoBossState = "Nhảy 1 cái rồi bật lại câu..."
								pcall(jumpOnce)
								task.wait(0.3)
								-- trả Auto Farm về đúng ý người dùng (đang farm thì farm tiếp) và đợi vòng câu chạy thật, không chạy thì tắt bật lại
								if autoBossOn then
									autoBossState = "Đang bật lại Auto Farm..."
									restoreFarm(farmUserWants)
								end
							end)
							Travel.done("boss")
							atIsland, originCF, goneSince, standCF, bossPos = nil, nil, nil, nil, nil
							autoBossState = "Chờ boss spawn"
						end
					end
					task.wait(1)
				end
			end
		end)
		loopActive = false
	end

	autoBossSetEnabled = function(v)
		autoBossOn = v
		if v then
			autoBossState = "Chờ boss spawn"
			task.spawn(autoBossLoop)
		else
			autoBossState = ""
		end
	end
end

-- Quét lại toàn bộ đảo 1-6 (tuần tự) mỗi Config.BOSS_STREAM_INTERVAL giây
task.spawn(function()
	task.wait(4)
	while ScreenGui.Parent do
		local startedAt = os.clock()
		if Config.BOSS_STREAM_ALL then pcall(runBossBatch) end
		while ScreenGui.Parent and os.clock() - startedAt < Config.BOSS_STREAM_INTERVAL do
			task.wait(1)
		end
	end
end)

-- ==================================================
-- TAB 5: SETTING
-- ==================================================
local SettingTab = CreateTab("Setting", "🛠️")
CreateSection(SettingTab, "Cài đặt UI")
CreateButton(SettingTab, "Hiệu chỉnh lại bấm", function()
	if calibBusy then return end
	Calib = {}
	CalibInfo.scale = {}
	CalibInfo.touchDead = false
	task.spawn(preCalibrate)
end)

CreateSection(SettingTab, "Hiệu Năng")
CreateToggle(SettingTab, "Fix Lag", false, function(v)
	if v then
		fixLagStart()
	else
		fixLagStop()
	end
end)

task.spawn(function()
	task.wait(1)
	pcall(preCalibrate)
end)

-- ==================================================
-- KHỞI TẠO TAB MẶC ĐỊNH
-- ==================================================
Tabs["Trạng Thái"].Visible = true
TabButtons["Trạng Thái"].Button.BackgroundTransparency = 0.1
TabButtons["Trạng Thái"].Icon.TextColor3 = Color3.fromRGB(255, 255, 255)
TabButtons["Trạng Thái"].Label.TextColor3 = Color3.fromRGB(255, 255, 255)
CurrentTab = "Trạng Thái"

-- ==================================================
-- ANIMATION MỞ / ĐÓNG MENU
-- ==================================================
local MenuOpen, OriginalSize, ClosedSize = false, UITheme.MainSize, UDim2.new(0, 0, 0, 0)

local function OpenMenu()
	if MenuOpen then return end
	MenuOpen, MainFrame.Visible, MainFrame.Size, MainFrame.Position, MainFrame.BackgroundTransparency, ToggleIcon.Text = true, true, ClosedSize, UDim2.new(0.5, 0, 0.5, 0), 1, "×"
	Tween(MainFrame, { Size = OriginalSize, Position = UDim2.new(0.5, -OriginalSize.X.Offset / 2, 0.5, -OriginalSize.Y.Offset / 2), BackgroundTransparency = 0.65 }, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Tween(ToggleButton, { Rotation = 180 }, 0.3, Enum.EasingStyle.Back)
end

local function CloseMenu()
	if not MenuOpen then return end
	MenuOpen = false
	ToggleIcon.Text = "🎣"
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
