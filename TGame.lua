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
	ANTI_TP = true, -- chống bị game/server kéo nhân vật về chỗ cũ sau khi tp (bật/tắt ở tab Setting, hoặc đặt false ở đây để tắt hẳn)
	ANTI_TP_MIN_DISTANCE = 25, -- Anti TP chỉ hoàn tác khi nhân vật bị kéo đi xa hơn chừng này (stud) trong 1 khung hình; đi bộ / nhảy / rơi bình thường không bị chặn
	TP_VERIFY_TIME = 0.8, -- sau mỗi lần script tp: theo dõi chừng này giây xem server có kéo nhân vật về chỗ cũ không
	TP_VERIFY_RADIUS = 12, -- lệch ngang quá chừng này (stud) so với chỗ vừa tp tới = coi là bị kéo lại
	TP_RETRY = 3, -- bị kéo lại thì đặt lại chỗ tp tối đa chừng này lần
	TP_RESET_WATCH = 3, -- tp XA (đổi đảo): theo dõi chừng này giây xem game có reset / giết nhân vật vì tp quá xa không
	TP_RESET_RETRY = 3, -- bị reset hoặc bị kéo về chỗ cũ: hồi sinh rồi tp lại đúng chỗ đó, tối đa chừng này lần
	TP_HOP_DISTANCE = 120, -- các lần tp lại dùng cách chia nhỏ: mỗi bước nhảy tối đa chừng này stud (tránh game thấy 1 cú nhảy quá xa)
	TP_HOP_DELAY = 0.15, -- nghỉ giữa 2 bước nhảy (giây)
	TP_RESPAWN_TIMEOUT = 20, -- đợi nhân vật mới sau khi reset tối đa chừng này giây
	CATCH_TIMEOUT = 60,
	SELL_POS = Vector3.new(-29.39, 19.66, 406.90),
	BOAT_CHOICE = 1, -- xe gọi ra: 1 = Truck (miễn phí), 2 = Red Truck (chọn ở tab Farm)
	BOAT_TIMEOUT = 360, -- lái tối đa chừng này giây mỗi lượt (xe tự né vật cản, lạc đường thì lập lại lộ trình)
	BOAT_RETRIES = 3, -- gọi xe / lên xe / lái hỏng giữa chừng: thử lại tối đa chừng này lượt
	BOAT_TOTAL_TIMEOUT = 700, -- cả chuyến đi xe (gồm các lần thử lại) tối đa chừng này giây
	SELL_WALK = true, -- bán cá bằng cách ĐI BỘ tới NPC bán cá gần nhất (không tp). false = tp tới SELL_POS như cũ
	SELL_WALK_TIMEOUT = 90, -- đi bộ tới NPC / đi bộ về chỗ cũ: tối đa chừng này giây mỗi chặng
	SELL_WALK_STOP = 6, -- dừng cách NPC chừng này stud rồi mới bấm tương tác
	FIXLAG_INTERVAL = 10,
	BOSS_SCAN_INTERVAL = 15, -- bảng Boss Zone cập nhật mỗi 15 giây
	BOSS_STREAM_ALL = true, -- luôn bật: tự yêu cầu game tải các đảo xa để quét boss zone (đã bỏ công tắc)
	BOSS_STREAM_INTERVAL = 30, -- toàn bộ 6 đảo được quét lại mỗi 30 giây (quét lần lượt, cách nhau 0.6s/đảo)
	BOSS_NOTIFY_DURATION = 60, -- thông báo "Boss Zone đã spawn" hiện trong 60 giây rồi mới tự tắt
	REDEEM_CODES = { "LOVE10KCCU", "1MVISITS", "2MVISITS", "UPD1FM" }, -- nút "Nhập tất cả Code" ở tab Setting nhập lần lượt các code này (thêm code mới vào đây)
	REDEEM_DELAY = 1.5, -- nghỉ giữa 2 code (giây), nhập quá nhanh server có thể bỏ qua
	LOCK_FISH_MIN_RARITY = "Legendary", -- khoá cá từ độ hiếm này trở lên. Thứ tự thấp -> cao: Common, Uncommon, Rare, Epic, Legendary (Huyền thoại), Mythical (Thần thoại), Divine, Secret
	LOCK_FISH_INTERVAL = 15, -- công tắc "Tự khoá cá" bật: cứ chừng này giây kiểm tra túi 1 lần
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

-- Khoá cá trong túi đồ (xem phần "KHOÁ CÁ" bên dưới). Gộp mọi trạng thái + hàm vào 1 bảng để không tốn thêm biến local ở cấp cao nhất
-- (Lua giới hạn 200 biến local mỗi khối).
local LockFish = { on = false, busy = false, fails = 0, pauseUntil = 0, loopActive = false, index = nil }

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
local Travel = { owner = nil, since = 0, lastEnd = 0, minGap = 1.5, maxHold = 1500 } -- maxHold: giữ khoá quá lâu (bị kẹt) thì coi như hết hạn

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
-- ANTI TP: giữ nhân vật không bị game / server kéo đi (về chỗ cũ, về spawn...) khi KHÔNG phải do script này tp.
-- Cơ chế: mỗi Heartbeat so vị trí hiện tại với khung hình trước (lastCF).
--   - Đi bộ, nhảy, rơi chỉ nhích vài stud mỗi khung hình => cho qua (không còn bị "đóng băng" tại chỗ như bản cũ,
--     bản cũ hoàn tác MỌI thay đổi CFrame nên đi bộ / nhảy cũng bị kéo lại).
--   - Nhảy xa >= Config.ANTI_TP_MIN_DISTANCE stud trong 1 khung hình mà không phải do script => coi là bị kéo đi, đặt lại chỗ cũ.
--   - Hoàn tác >= 4 lần trong 2 giây mà server vẫn kéo tiếp => tạm nghỉ 4 giây, không đấu với server mãi (dễ bị kick).
-- Mọi lần script TỰ đặt CFrame nhân vật (tp, xoay mặt về boss, kéo lại chỗ đứng) phải đi qua setRootCFrame:
-- hàm này báo cho guard biết đó là thay đổi hợp lệ và cập nhật lastCF, nếu không guard sẽ hoàn tác luôn cú tp của chính script.
-- AntiTP.verify: sau mỗi cú tp của script, theo dõi xem server có kéo nhân vật về chỗ cũ không, bị kéo thì đặt lại (tối đa Config.TP_RETRY lần).
-- Bật/tắt ở tab Setting (AntiTP.setEnabled). Tắt khi cần dùng dịch chuyển của chính game (Fast Travel, nút Spawn...).
-- ==================================================
local AntiTP = { lastCF = nil, expected = nil, expectedUntil = 0, allowUntil = 0, reverts = {}, hb = nil, died = nil, onFail = nil }

local function antiTPDisconnect()
	for _, key in ipairs({ "hb", "died" }) do
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

	AntiTP.lastCF = root.CFrame
	AntiTP.reverts = {}

	AntiTP.hb = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local cf = root.CFrame
		local last = AntiTP.lastCF

		if last and now >= AntiTP.allowUntil and (cf.Position - last.Position).Magnitude >= Config.ANTI_TP_MIN_DISTANCE then
			local exp = AntiTP.expected
			local byScript = exp ~= nil and now < AntiTP.expectedUntil and (cf.Position - exp.Position).Magnitude < 3
			if not byScript then
				-- giữ lại các lần hoàn tác trong 2 giây gần nhất
				local keep = {}
				for _, tm in ipairs(AntiTP.reverts) do
					if now - tm < 2 then table.insert(keep, tm) end
				end
				table.insert(keep, now)
				AntiTP.reverts = keep
				if #keep >= 4 then
					-- server kéo liên tục: nghỉ 4 giây, theo vị trí mới
					AntiTP.allowUntil = now + 4
					AntiTP.reverts = {}
				else
					root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					root.CFrame = last
					return
				end
			end
		end
		AntiTP.lastCF = root.CFrame
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

-- Bật / tắt Anti TP lúc đang chạy (công tắc ở tab Setting)
function AntiTP.setEnabled(v)
	Config.ANTI_TP = v and true or false
	if Config.ANTI_TP then
		local char = LocalPlayer.Character
		if char then task.spawn(antiTPAttach, char) end
	else
		antiTPDisconnect()
	end
end

-- Sau khi script đặt CFrame tới goal: theo dõi `watch` giây (mặc định Config.TP_VERIFY_TIME).
-- Trả về:
--   "ok"     đứng đúng chỗ
--   "reset"  nhân vật chết / bị thay bằng nhân vật mới (game reset vì tp quá xa)
--   "pulled" server kéo nhân vật lệch khỏi goal quá Config.TP_VERIFY_RADIUS, đặt lại Config.TP_RETRY lần vẫn không giữ được
function AntiTP.verify(goal, watch)
	local char0 = LocalPlayer.Character
	local retries = 0
	local t0 = os.clock()
	watch = watch or Config.TP_VERIFY_TIME
	while os.clock() - t0 < watch do
		RunService.Heartbeat:Wait()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if char ~= char0 or not hum or not root or hum.Health <= 0 then return "reset" end
		local dx = root.Position.X - goal.Position.X
		local dz = root.Position.Z - goal.Position.Z
		if math.sqrt(dx * dx + dz * dz) > Config.TP_VERIFY_RADIUS then
			if retries >= Config.TP_RETRY then return "pulled" end
			retries = retries + 1
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			setRootCFrame(root, goal)
			t0 = os.clock()
		end
	end
	return "ok"
end

-- Đợi nhân vật MỚI (khác oldChar) xuất hiện, còn sống và có HumanoidRootPart. Trả về char, root (nil nếu quá thời gian).
function AntiTP.waitNew(oldChar, timeout)
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		local char = LocalPlayer.Character
		if char and char ~= oldChar then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then return char, root end
		end
		task.wait(0.1)
	end
	return nil, nil
end

-- Tp chia nhỏ: đi từng bước <= Config.TP_HOP_DISTANCE stud, nghỉ Config.TP_HOP_DELAY giữa các bước.
function AntiTP.hop(goal)
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local from = root.Position
	local steps = math.max(1, math.ceil((goal.Position - from).Magnitude / Config.TP_HOP_DISTANCE))
	local rot = goal - goal.Position
	for s = 1, steps do
		char = LocalPlayer.Character
		root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return false end
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		setRootCFrame(root, (s == steps) and goal or (CFrame.new(from:Lerp(goal.Position, s / steps)) * rot))
		if s < steps then task.wait(Config.TP_HOP_DELAY) end
	end
	return true
end

-- ==================================================
-- TELEPORT TỨC THÌ (dùng cho Auto Sell, menu Đảo, Auto Câu Boss)
-- Nhận Vector3 hoặc CFrame. Đặt thẳng CFrame 1 lần, không tween; sau đó theo dõi xem game có phản ứng không (AntiTP.verify).
-- Game có cơ chế reset nhân vật / kéo về chỗ cũ khi tp quá xa. Script không đọc được phía server nên KHÔNG chặn tận gốc được;
-- thay vào đó xử lý theo cách người dùng yêu cầu:
--   bị reset (chết / nhân vật mới) hoặc bị kéo về chỗ cũ => reset nhân vật (nếu chưa), đợi hồi sinh, rồi tp lại ĐÚNG chỗ vừa tp tới.
--   Lần tp lại xen kẽ: chia nhỏ từng bước (hopTeleport) <-> tp thẳng, tối đa Config.TP_RESET_RETRY lần.
-- Trả về true nếu cuối cùng đã đứng đúng chỗ.
-- ==================================================
local function FastTeleport(target)
	local useHops = false
	local resets = 0
	for attempt = 0, Config.TP_RESET_RETRY do
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			char, root = AntiTP.waitNew(nil, Config.TP_RESPAWN_TIMEOUT)
			if not root then return false end
		end

		local goal
		if typeof(target) == "CFrame" then
			goal = target
		else
			goal = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
		end
		local far = (goal.Position - root.Position).Magnitude > 300

		-- đích xa (đảo khác): yêu cầu game tải sẵn khu vực đó trước, không thì nhân vật rơi xuống chỗ chưa tải xong
		if far then
			BossScan.busyUntil = os.clock() + 8 -- Fix Lag nhường chỗ lúc dữ liệu khu vực mới đổ về
			requestStream(goal.Position, 3)
			char = LocalPlayer.Character
			root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then
				char, root = AntiTP.waitNew(nil, Config.TP_RESPAWN_TIMEOUT)
				if not root then return false end
			end
		end

		if useHops and far then
			if not AntiTP.hop(goal) then return false end
		else
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			setRootCFrame(root, goal)
		end

		local sent = LocalPlayer.Character
		local res = AntiTP.verify(goal, far and Config.TP_RESET_WATCH or Config.TP_VERIFY_TIME)
		if res == "ok" then
			if resets > 0 and AntiTP.onReset then AntiTP.onReset("đã hồi sinh và tp lại đúng chỗ (" .. resets .. " lần reset)") end
			return true
		end

		if attempt >= Config.TP_RESET_RETRY then
			if AntiTP.onFail then
				AntiTP.onFail(res == "reset" and "game reset nhân vật liên tục, đã thử lại hết lượt" or "server kéo lại, đặt lại vẫn không giữ được")
			end
			return false
		end

		resets = resets + 1
		if res == "pulled" then
			-- bị kéo về chỗ cũ: reset nhân vật rồi tp lại chỗ vừa tp tới
			local hum = sent and sent:FindFirstChildOfClass("Humanoid")
			if hum then pcall(function() hum.Health = 0 end) end
		end
		local newChar = AntiTP.waitNew(sent, Config.TP_RESPAWN_TIMEOUT)
		if not newChar then return false end
		task.wait(1) -- để nhân vật mới và khu vực quanh nó tải xong
		useHops = not useHops
	end
	return false
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
-- ĐI BỘ (Nav): dùng PathfindingService đi tới 1 điểm, tự nhảy khi bị kẹt. Không tp nên không bị game reset vì "tp quá xa".
-- Nav.walkTo(pos, {stop, timeout}) -> true nếu tới nơi (cách pos <= stop stud theo mặt phẳng)
-- Nav.findSeller(fromPos) -> vị trí NPC bán cá GẦN NHẤT đang được tải (mỗi đảo có 1 NPC "npc_fish_seller_*")
-- ==================================================
Travel.Nav = {}
do
local Nav = Travel.Nav
local PathfindingService = game:GetService("PathfindingService")

local function navParts()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then return hum, root end
	return nil, nil
end
Nav.parts = navParts

local function flatDist(a, b)
	return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
end

function Nav.walkTo(pos, opts)
	opts = opts or {}
	local stop = opts.stop or 5
	local timeout = opts.timeout or 60
	local t0 = os.clock()

	local function arrived()
		local _, root = navParts()
		return root ~= nil and flatDist(root.Position, pos) <= stop and math.abs(root.Position.Y - pos.Y) < 15
	end

	-- đi thẳng tới pos (không đường dẫn), nhảy khi kẹt; dùng khi không dựng được đường
	local function direct(maxTime)
		local ws = os.clock()
		local lastPos, lastMove = nil, os.clock()
		while os.clock() - ws < maxTime and os.clock() - t0 < timeout do
			local hum, root = navParts()
			if not hum then return false end
			if arrived() then return true end
			hum:MoveTo(pos)
			if lastPos and (root.Position - lastPos).Magnitude < 0.5 then
				if os.clock() - lastMove > 0.8 then hum.Jump = true end
			else
				lastMove = os.clock()
			end
			lastPos = root.Position
			task.wait(0.15)
		end
		return arrived()
	end

	local rebuilds = 0
	while os.clock() - t0 < timeout do
		local hum, root = navParts()
		if not hum then return false end
		if arrived() then return true end

		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
		local okPath = pcall(function() path:ComputePath(root.Position, pos) end)
		if not (okPath and path.Status == Enum.PathStatus.Success) then
			-- không dựng được đường (NPC nằm trong vật cản, hoặc khác đảo): thử đi thẳng một lúc, không được thì báo thất bại
			return direct(8)
		end

		local wps = path:GetWaypoints()
		for k = 2, #wps do
			local wp = wps[k]
			local h2, r2 = navParts()
			if not h2 then return false end
			if wp.Action == Enum.PathWaypointAction.Jump then h2.Jump = true end
			h2:MoveTo(wp.Position)
			local reached = false
			local conn = h2.MoveToFinished:Connect(function() reached = true end)
			local ws, lastPos, lastMove = os.clock(), r2.Position, os.clock()
			while not reached and os.clock() - ws < 5 and os.clock() - t0 < timeout do
				task.wait(0.1)
				local _, r3 = navParts()
				if not r3 then break end
				if flatDist(r3.Position, pos) <= stop then break end
				if (r3.Position - lastPos).Magnitude > 0.8 then
					lastPos, lastMove = r3.Position, os.clock()
				elseif os.clock() - lastMove > 1 then
					h2.Jump = true
					lastMove = os.clock()
				end
			end
			conn:Disconnect()
			if arrived() then return true end
			if not reached then break end -- kẹt: dựng lại đường từ chỗ hiện tại
		end
		rebuilds = rebuilds + 1
		if rebuilds > 6 then break end
	end
	return arrived()
end

function Nav.findSeller(fromPos)
	local world = workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Islands") or workspace
	local best, bestD = nil, math.huge
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("Model") then
			local n = string.lower(d.Name)
			if n:find("fish_seller") or n:find("fishseller") then
				local part = d:FindFirstChild("HumanoidRootPart") or d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
				if part then
					local dd = (part.Position - fromPos).Magnitude
					if dd < bestD then best, bestD = part.Position, dd end
				end
			end
		end
	end
	return best, bestD
end
end -- do (Nav)

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
	if Travel.Boat then Travel.Boat.stop = true end
	isRunning = false
	isAutoSkillRunning = false
	isAutoSellRunning = false
	LockFish.on = false
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

-- Báo khi script tp mà server kéo nhân vật lại, đặt lại nhiều lần vẫn không giữ được (AntiTP.verify gọi)
AntiTP.onFail = function(msg)
	pcall(notifyOwnFish, "Dịch chuyển", "lỗi", msg, true, 6)
end
AntiTP.onReset = function(msg)
	pcall(notifyOwnFish, "Dịch chuyển", "reset", msg, true, 6)
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
		dialogueClick({ "Goodbye", "Tạm biệt", "Để sau nhé" }, mode)
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

-- ==================================================
-- MỞ HỘP THOẠI NPC (ProximityPrompt) — phải mở được NGAY LẦN ĐẦU
-- Bản cũ chỉ kích hoạt prompt MỘT lần rồi đợi: lúc vừa tới nơi nhân vật còn đang trượt, hoặc prompt chưa tải xong / chưa bật,
-- thì lần kích hoạt đó vô tác dụng và phải đợi vòng sau mới được (đúng lỗi "bấm NPC lần đầu không gọi, lần 2 mới gọi").
-- Giờ mỗi lượt: đợi prompt có mặt (yêu cầu game tải khu vực nếu chưa có) và đang bật -> tới sát NPC -> đợi nhân vật đứng yên
-- -> kích hoạt bằng 1 trong 3 cách (mỗi cách thử 2 lượt rồi đổi: fireproximityprompt / InputHoldBegin-End / bấm phím tương tác)
-- -> KIỂM TRA hộp thoại có mở thật không; chưa mở thì thử lại ngay (cách khác), tối đa opts.attempts lượt.
-- Cách đã có tác dụng được nhớ cho lần sau (Travel.promptMethod).
-- resolve(): hàm trả về ProximityPrompt cần bấm (gọi lại mỗi lượt vì prompt có thể vừa mới tải xong).
-- Trả về true nếu hộp thoại đã mở.
-- ==================================================
Travel.promptMethod = 1
function Travel.openPrompt(resolve, opts)
	opts = opts or {}
	local attempts = opts.attempts or 7
	local Nav = Travel.Nav

	local function promptPos(prompt)
		local p = prompt.Parent
		if p and p:IsA("BasePart") then return p.Position end
		if p and p:IsA("Attachment") then return p.WorldPosition end
		local model = prompt:FindFirstAncestorOfClass("Model")
		local part = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"))
		return part and part.Position or nil
	end

	local function fire(prompt, method)
		if method == 1 then
			if not fireproximityprompt then return false end
			return pcall(fireproximityprompt, prompt)
		elseif method == 2 then
			return pcall(function()
				prompt:InputHoldBegin()
				task.wait((prompt.HoldDuration or 0) + 0.12)
				prompt:InputHoldEnd()
			end)
		end
		local key = prompt.KeyboardKeyCode
		if not key or key == Enum.KeyCode.Unknown then key = Enum.KeyCode.E end
		return pcall(pressKey, key, (prompt.HoldDuration or 0) + 0.2)
	end

	local walks = 0
	for attempt = 1, attempts do
		if isDialogueOpen() then return true end
		local _, root = Nav.parts()
		if not root then return false, "không thấy nhân vật" end

		local prompt = resolve and resolve() or nil
		if not (prompt and prompt.Parent) then
			-- prompt chưa tải (StreamingEnabled): yêu cầu game tải khu vực quanh nhân vật rồi đợi
			if attempt <= 2 then pcall(requestStream, root.Position, 2) end
			task.wait(0.6)
		else
			local pos = promptPos(prompt)
			local reach = prompt.MaxActivationDistance or 10

			-- 1) đứng trong tầm kích hoạt (gần hơn ~85% tầm). Chỉ đi bộ lại khi thật sự ngoài tầm, tối đa 2 lần (đỡ tốn thời gian)
			if pos and walks < 2 and (root.Position - pos).Magnitude > reach * 0.85 then
				walks = walks + 1
				Nav.walkTo(pos, { stop = math.max(3, reach * 0.5), timeout = 20 })
				_, root = Nav.parts()
				if not root then return false, "mất nhân vật" end
			end

			-- 2) prompt chưa bật (NPC đang bận / chưa tải xong): đợi tối đa 3 giây
			local waited = 0
			while not prompt.Enabled and waited < 3 do
				task.wait(0.2)
				waited = waited + 0.2
			end

			-- 3) đợi nhân vật đứng yên liên tục 0.35 giây (vừa đi tới còn đang trượt thì kích hoạt hay không ăn)
			local still, t, lastPos = 0, 0, root.Position
			while still < 0.35 and t < 2 do
				task.wait(0.1)
				t = t + 0.1
				local _, r2 = Nav.parts()
				if not r2 then return false, "mất nhân vật" end
				if (r2.Position - lastPos).Magnitude < 0.15 then still = still + 0.1 else still = 0 end
				lastPos = r2.Position
			end

			-- 4) kích hoạt rồi kiểm tra hộp thoại có mở thật
			if not isDialogueOpen() then
				local method = ((Travel.promptMethod - 1 + math.floor((attempt - 1) / 2)) % 3) + 1 -- mỗi cách thử 2 lượt rồi mới đổi cách khác
				fire(prompt, method)
				local w = 0
				while not isDialogueOpen() and w < 1.6 do
					task.wait(0.1)
					w = w + 0.1
				end
				if isDialogueOpen() then
					Travel.promptMethod = method
				end
			end
			if isDialogueOpen() then
				task.wait(0.25) -- để hộp thoại dựng xong các nút
				return true
			end
		end
	end
	return isDialogueOpen()
end

local function sellTrip()
	local Nav = Travel.Nav
	local navParts = Nav.parts
	-- Mở hộp thoại NPC bán cá bằng Travel.openPrompt: kiểm tra hộp thoại có mở thật, chưa mở thì thử lại ngay (không bỏ lỡ lần đầu)
	local function openSellerDialogue()
		if isDialogueOpen() then return true end
		local opened = Travel.openPrompt(function()
			local newChar = LocalPlayer.Character
			local newRoot = newChar and newChar:FindFirstChild("HumanoidRootPart")
			return newRoot and findSellerPrompt(newRoot)
		end, { attempts = 6 })
		if not opened then
			sellState = "Không mở được hộp thoại NPC bán cá, vẫn thử bán..."
		end
		task.wait(0.15)
		return opened
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

	-- Công tắc "Tự khoá cá" đang bật: khoá cá Huyền thoại trở lên trong túi TRƯỚC khi bán (cá đã khoá không bị "Bán tất cả" bán)
	if LockFish.on and LockFish.run then
		sellState = "Đang khoá cá hiếm trước khi bán..."
		pcall(LockFish.run, { force = true })
	end

	local ok, err = pcall(function()
		if Config.SELL_WALK then
			local sellerPos = Nav.findSeller(root.Position)
			if not sellerPos then error("không thấy NPC bán cá nào đang tải quanh đây") end
			sellState = "Đang đi bộ tới NPC bán cá..."
			if not Nav.walkTo(sellerPos, { stop = Config.SELL_WALK_STOP, timeout = Config.SELL_WALK_TIMEOUT }) then
				error("không đi bộ tới được NPC bán cá")
			end
			task.wait(0.4)
		else
			sellState = "Đang tp tới NPC..."
			FastTeleport(Config.SELL_POS)
			task.wait(0.6)
		end

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

	if ok or Config.SELL_WALK then sellState = "Đang về chỗ cũ..." end
	if Config.SELL_WALK then
		-- đi bộ về đúng chỗ đang farm; không về được mà vẫn cùng đảo (gần) thì mới tp, tránh bị game reset vì tp xa
		Nav.walkTo(originalCFrame.Position, { stop = 3, timeout = Config.SELL_WALK_TIMEOUT })
	else
		pcall(FastTeleport, originalCFrame)
	end

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
-- Menu Settings của game nằm ở PlayerGui.Settings.Frame.List. Bản game hiện tại: mỗi công tắc là 1 khối con đặt tên theo khoá
-- (ultra_low_graphic, auto_fishing_hide_vfx, show_cutscenes, show_loot_items, show_damage_indicator, show_my_vfx,
-- show_others_vfx, camera_shaking), bên trong có Label (tên hiển thị) và ToggleButton (TextButton, chữ "On"/"Off", núm tròn Knob).
-- Bản game cũ dùng khối "toggle" (text + button.TextButton) — vẫn nhận ra làm dự phòng.
-- Lý do bản cũ không bật được: nó chỉ tìm khối "toggle" của giao diện cũ nên giao diện mới không tìm thấy mục nào.
-- Cách làm: tìm khối theo chữ ở Label (không được thì theo tên khoá), ĐỌC trạng thái On/Off trước, chỉ bấm khi khác cấu hình,
-- bấm xong ĐỢI tới khi trạng thái đổi đúng (không tin cú bấm), và khi trạng thái đã đổi thì KHÔNG bấm thêm
-- (bản cũ bấm nhiều kiểu liên tiếp nên có thể bật rồi lại tắt).
-- Mọi hàm của khối này gộp vào bảng GS để không tốn thêm biến local ở cấp cao nhất (Lua giới hạn 200 biến local mỗi khối).
-- ==================================================
local gameSettingsStatus = "Chưa áp dụng"

local function hasSignalClick()
	return firesignal ~= nil or getconnections ~= nil
end

local GS = { busy = false, fails = {}, rowFails = 0, toasted = false, noRows = false }

-- (nhãn hiển thị trong game, tên khối trong PlayerGui.Settings.Frame.List) theo thứ tự hiện trong menu
GS.pairs = {
	{ "FastMode", "ultra_low_graphic" },
	{ "Hide Auto Fishing Skill Visuals", "auto_fishing_hide_vfx" },
	{ "Skip Cutscenes", "show_cutscenes" },
	{ "Skip Loot Preview", "show_loot_items" },
	{ "Show Damage", "show_damage_indicator" },
	{ "Show VFX (self)", "show_my_vfx" },
	{ "Show VFX (Other Players)", "show_others_vfx" },
	{ "Camera Shake", "camera_shaking" },
}

-- Chuẩn hoá chữ để so sánh: bỏ thẻ RichText, đổi NBSP thành dấu cách, chữ thường, bỏ khoảng trắng / dấu câu 2 đầu
function GS.clean(s)
	local r = tostring(s or "")
	r = r:gsub("<[^>]+>", "")
	r = r:gsub("\194\160", " ")
	r = r:gsub("%s+", " ")
	return normalizeText(r)
end

-- Menu Settings coi là "đã mở" khi ScreenGui Settings đang Enabled VÀ Frame đang Visible
function GS.isOpen()
	local g = PlayerGui:FindFirstChild("Settings")
	local f = g and g:FindFirstChild("Frame")
	return f ~= nil and f.Visible and (not g:IsA("ScreenGui") or g.Enabled)
end

function GS.listFrame()
	local g = PlayerGui:FindFirstChild("Settings")
	local f = g and g:FindFirstChild("Frame")
	return f and f:FindFirstChild("List")
end

-- Nếu `row` là 1 khối công tắc thì trả về { row, btn (nút bấm), text (nhãn hiển thị), stateLabel (chỉ giao diện cũ) }
function GS.parts(row)
	if not row:IsA("GuiObject") then return nil end
	local btn = row:FindFirstChild("ToggleButton")
	local lab = row:FindFirstChild("Label")
	if btn and btn:IsA("GuiButton") and lab and lab:IsA("TextLabel") then
		return { row = row, btn = btn, text = lab.Text }
	end
	if row.Name == "toggle" then
		local t = row:FindFirstChild("text")
		local b = row:FindFirstChild("button")
		local tb = b and b:FindFirstChild("TextButton")
		if t and t:IsA("TextLabel") and tb and tb:IsA("GuiButton") then
			return { row = row, btn = tb, text = t.Text, stateLabel = b:FindFirstChild("TextLabel") }
		end
	end
	return nil
end

-- Số khối công tắc đang có trong menu (bỏ khối mẫu "ToggleItem")
function GS.count()
	local list = GS.listFrame()
	if not list then return 0 end
	local n = 0
	for _, row in ipairs(list:GetChildren()) do
		if row.Name ~= "ToggleItem" and GS.parts(row) then n = n + 1 end
	end
	return n
end

-- Tìm khối công tắc theo nhãn hiển thị; không khớp chữ thì tìm theo tên khoá của game
function GS.find(label)
	local list = GS.listFrame()
	if not list then return nil end
	local wanted = GS.clean(label)
	local key = nil
	for _, p in ipairs(GS.pairs) do
		if GS.clean(p[1]) == wanted then key = p[2] end
	end
	local byKey = nil
	for _, row in ipairs(list:GetChildren()) do
		if row.Name ~= "ToggleItem" then
			local h = GS.parts(row)
			if h then
				if GS.clean(h.text) == wanted then return h end
				if key and row.Name == key then byKey = h end
			end
		end
	end
	return byKey
end

function GS.onoff(s)
	local t = GS.clean(s)
	if t == "on" or t == "bật" or t == "bat" or t == "enabled" then return true end
	if t == "off" or t == "tắt" or t == "tat" or t == "disabled" then return false end
	return nil
end

-- Đọc trạng thái hiện tại của 1 công tắc: true = On, false = Off, nil = không đọc được
function GS.read(h)
	local v
	if h.stateLabel then
		v = GS.onoff(h.stateLabel.Text)
		if v ~= nil then return v end
	end
	if h.btn:IsA("TextButton") then
		v = GS.onoff(h.btn.Text)
		if v ~= nil then return v end
	end
	for _, d in ipairs(h.btn:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			v = GS.onoff(d.Text)
			if v ~= nil then return v end
		end
	end
	for _, inst in ipairs({ h.btn, h.row }) do
		for _, name in ipairs({ "Enabled", "Value", "State", "Toggled", "On", "IsOn", "Checked" }) do
			local a = inst:GetAttribute(name)
			if type(a) == "boolean" then return a end
		end
	end
	for _, c in ipairs(h.row:GetChildren()) do
		if c:IsA("BoolValue") then return c.Value end
	end
	-- dự phòng: vị trí núm tròn. Theo ảnh game, núm nằm bên TRÁI = On, bên PHẢI = Off (chỉ đo được khi menu đang hiện)
	local knob = h.btn:FindFirstChild("Knob")
	if knob and knob:IsA("GuiObject") and h.btn.AbsoluteSize.X > 4 then
		local kx = knob.AbsolutePosition.X + knob.AbsoluteSize.X / 2
		local bx = h.btn.AbsolutePosition.X + h.btn.AbsoluteSize.X / 2
		if math.abs(kx - bx) > h.btn.AbsoluteSize.X * 0.08 then return kx < bx end
	end
	return nil
end

-- Đợi tối đa `seconds` giây cho tới khi công tắc `label` đọc ra đúng `want`. Trả về true nếu đúng.
function GS.waitState(label, want, seconds)
	local t0 = os.clock()
	repeat
		local h = GS.find(label)
		if h and GS.read(h) == want then return true end
		task.wait(0.1)
	until os.clock() - t0 >= seconds
	return false
end

-- Kích hoạt thẳng 1 sự kiện của nút (MouseButton1Click / Activated), không phụ thuộc toạ độ màn hình
function GS.fire(btn, evName)
	local ok, sig = pcall(function() return btn[evName] end)
	if not ok or sig == nil then return false end
	if firesignal then
		return (pcall(firesignal, sig))
	end
	if getconnections then
		local ok2, conns = pcall(getconnections, sig)
		if ok2 and conns then
			for _, c in ipairs(conns) do
				pcall(function() c:Fire() end)
			end
			return #conns > 0
		end
	end
	return false
end

-- Cuộn danh sách để khối công tắc nằm giữa vùng nhìn thấy (bấm theo toạ độ màn hình cần khối đang hiện trên màn hình)
function GS.reveal(h)
	local list = GS.listFrame()
	if not list or not list:IsA("ScrollingFrame") then return end
	pcall(function()
		local y = h.row.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y
		local target = math.max(0, y - (list.AbsoluteSize.Y - h.row.AbsoluteSize.Y) / 2)
		list.CanvasPosition = Vector2.new(list.CanvasPosition.X, target)
	end)
	task.wait(0.2)
end

-- Mở menu Settings bằng nút Settings ở HUD: thử bấm tín hiệu trước (không phụ thuộc toạ độ), không ăn mới bấm theo màn hình.
-- Trước mỗi lần bấm đều kiểm tra menu đã mở chưa (nút Settings là nút bật/tắt, bấm khi đã mở sẽ đóng menu lại).
local function openGameSettingsMenu()
	if GS.isOpen() then return true end
	local hud = PlayerGui:FindFirstChild("HUD")
	local frame = hud and hud:FindFirstChild("Frame")
	local buttons = frame and frame:FindFirstChild("Buttons")
	local openBtn = buttons and buttons:FindFirstChild("Settings")
	if not openBtn then return false end

	local modes = hasSignalClick() and { "signal", "auto", "select", "noinset", "inset" } or { "auto", "select", "noinset", "inset" }
	for _, mode in ipairs(modes) do
		if GS.isOpen() then return true end
		if openBtn:IsA("GuiButton") then
			clickButton(openBtn, mode)
		else
			pressGui(openBtn, 0.05)
		end
		local t = 0
		while t < 2 do
			if GS.isOpen() then return true end
			task.wait(0.2)
			t = t + 0.2
		end
	end
	return GS.isOpen()
end

local function closeGameSettingsMenu()
	local g = PlayerGui:FindFirstChild("Settings")
	local f = g and g:FindFirstChild("Frame")
	local closeBtn = f and f:FindFirstChild("Close")
	if not closeBtn then return end
	local modes = hasSignalClick() and { "signal", "auto", "select", "noinset", "inset" } or { "auto", "select", "noinset", "inset" }
	for _, mode in ipairs(modes) do
		if not GS.isOpen() then return end
		if closeBtn:IsA("GuiButton") then
			clickButton(closeBtn, mode)
		else
			pressGui(closeBtn, 0.05)
		end
		local t = 0
		while t < 1.2 and GS.isOpen() do
			task.wait(0.2)
			t = t + 0.2
		end
	end
end

-- Đặt 1 công tắc về đúng trạng thái want (true = On, false = Off). Trả về true, hoặc false + lý do.
-- Đã đúng sẵn thì không bấm. Mỗi cách bấm đều đợi tới 1.5 giây xem trạng thái đã đổi chưa; đổi rồi thì dừng ngay.
function GS.set(label, want)
	local h = GS.find(label)
	if not h then return false, "không thấy mục trong menu" end
	local cur = GS.read(h)
	if cur == nil and not GS.isOpen() then
		-- có thể chỉ đọc được khi menu đang hiện (đo vị trí núm tròn): mở lên đọc lại
		if openGameSettingsMenu() then
			task.wait(0.4)
			h = GS.find(label)
			cur = h and GS.read(h) or nil
		end
	end
	if cur == nil then return false, "không đọc được On/Off" end
	if cur == want then return true end

	local steps = hasSignalClick() and { "MouseButton1Click", "Activated", "select", "auto", "noinset", "inset" } or { "select", "auto", "noinset", "inset" }
	-- cách bấm đã có tác dụng ở mục trước thử TRƯỚC (đỡ đợi 1.5 giây cho từng cách không ăn ở mỗi mục)
	if GS.lastStep then
		for i, st in ipairs(steps) do
			if st == GS.lastStep then
				table.remove(steps, i)
				table.insert(steps, 1, st)
				break
			end
		end
	end
	for _, step in ipairs(steps) do
		h = GS.find(label)
		if not h then return false, "mất khối công tắc" end
		if step == "select" or step == "auto" then
			-- bấm theo màn hình: menu phải đang mở và khối phải nằm trong vùng nhìn thấy
			if not GS.isOpen() and not openGameSettingsMenu() then return false, "không mở được menu Settings" end
			task.wait(0.2)
			h = GS.find(label)
			if not h then return false, "mất khối công tắc" end
			GS.reveal(h)
			clickButton(h.btn, step)
		else
			GS.fire(h.btn, step)
		end
		if GS.waitState(label, want, 1.5) then
			GS.lastStep = step
			return true
		end
	end
	return false, "bấm không đổi được trạng thái"
end

-- Áp toàn bộ Config.GAME_SETTINGS. force = true (người dùng vừa bật Fix Lag): bỏ qua việc "mục nào lỗi nhiều lần thì bỏ".
-- Máy có firesignal/getconnections thì bấm ngầm, không cần mở menu lên màn hình; không có (hoặc menu chưa dựng công tắc)
-- thì tự mở menu Settings ra, xong đóng lại nếu menu do script mở. Chỉ báo (toast) khi có mục không đổi được.
local function applyGameSettings(force)
	if GS.busy then return end
	GS.busy = true
	local wasOpen = GS.isOpen()
	local okCount, failList = 0, {}
	GS.noRows = false

	local okRun, errRun = pcall(function()
		if force then
			GS.fails = {}
			GS.rowFails = 0
		end

		-- chưa thấy công tắc nào (menu chưa dựng) hoặc máy không bấm ngầm được: mở menu Settings lên
		if GS.count() == 0 or not hasSignalClick() then
			if GS.count() == 0 and GS.rowFails >= 2 then
				GS.noRows = true
				return
			end
			openGameSettingsMenu()
			local t = 0
			while GS.count() == 0 and t < 3 do
				task.wait(0.25)
				t = t + 0.25
			end
			if GS.count() == 0 then
				GS.rowFails = GS.rowFails + 1
				GS.noRows = true
				return
			end
		end
		GS.rowFails = 0

		-- thứ tự: theo thứ tự trong menu game trước, rồi tới mục người dùng tự thêm vào Config.GAME_SETTINGS
		local labels, seen = {}, {}
		for _, p in ipairs(GS.pairs) do
			if Config.GAME_SETTINGS[p[1]] ~= nil then
				table.insert(labels, p[1])
				seen[p[1]] = true
			end
		end
		for label in pairs(Config.GAME_SETTINGS) do
			if not seen[label] then table.insert(labels, label) end
		end

		local consec = 0 -- số mục liền nhau không đổi được
		for _, label in ipairs(labels) do
			if consec >= 2 then
				table.insert(failList, label .. " (bỏ qua, các mục trước đều không bấm được)")
			elseif (GS.fails[label] or 0) < 3 then
				local ok, err = GS.set(label, Config.GAME_SETTINGS[label] == true)
				if ok then
					okCount = okCount + 1
					GS.fails[label] = 0
					consec = 0
				else
					GS.fails[label] = (GS.fails[label] or 0) + 1
					consec = consec + 1
					table.insert(failList, label .. (err and (" (" .. err .. ")") or ""))
				end
				task.wait(0.1)
			else
				table.insert(failList, label .. " (bỏ qua, đã lỗi nhiều lần)")
			end
		end
	end)

	-- menu Settings do script mở ra thì đóng lại, trả về như cũ
	if not wasOpen and GS.isOpen() then pcall(closeGameSettingsMenu) end
	GS.busy = false

	local total = okCount + #failList
	local msg
	if not okRun then
		gameSettingsStatus = "Lỗi khi áp dụng: " .. tostring(errRun)
		msg = "script lỗi khi áp dụng"
	elseif GS.noRows then
		gameSettingsStatus = "Không thấy công tắc nào trong menu Settings"
		msg = "không thấy công tắc Settings"
	elseif #failList == 0 then
		gameSettingsStatus = "Đã áp dụng " .. okCount .. "/" .. total .. " mục lúc " .. os.date("%H:%M:%S")
	else
		gameSettingsStatus = "Áp dụng " .. okCount .. "/" .. total .. " mục, lỗi: " .. table.concat(failList, "; ")
		msg = #failList .. "/" .. total .. " mục không đổi được"
	end
	if msg and (force or not GS.toasted) then
		GS.toasted = true
		pcall(notifyOwnFish, "Setting game", "lỗi", msg, true, 6)
	end
end

-- ==================================================
-- KHOÁ CÁ (túi đồ)
-- Cấu trúc túi đồ của game (PlayerGui.SatchelModal.Frame):
--   FunctionList.Lock.Button = nút ổ khoá (chế độ khoá cá)
--   List.ScrollingFrame.<GUID> = mỗi con cá 1 khung; Button.RarityLabel = độ hiếm, Button.FishWeightLabel = cân nặng,
--     Button.Exclusion.Locked = biểu tượng ổ khoá (hiện khi cá đã khoá)
-- Cá đã khoá không bị "Bán tất cả" bán.
-- Cách làm:
--   1) Đọc độ hiếm từng con: theo chữ trên nhãn (tiếng Anh + tiếng Việt), không nhận ra thì so màu gradient của nhãn với bộ màu độ hiếm
--      của game (ReplicatedStorage.Assets.UIs.GradientRaritys) nên không phụ thuộc ngôn ngữ.
--   2) Con nào từ Config.LOCK_FISH_MIN_RARITY trở lên mà chưa khoá thì khoá: bấm ổ khoá rồi bấm vào cá, SAU ĐÓ kiểm tra biểu tượng ổ khoá
--      đã hiện thật chưa (không tin cú bấm). Ưu tiên kích hoạt thẳng sự kiện nút (không cần mở túi), không được thì mở túi và bấm theo toạ độ.
--   3) Không rõ nút ổ khoá hoạt động kiểu "chế độ khoá" hay "chọn cá rồi khoá" nên script tự dò: kiểu nào ra kết quả (ổ khoá hiện) thì dùng kiểu đó.
-- Mọi hàm / trạng thái nằm trong bảng LockFish (khai báo ở đầu script).
-- ==================================================
LockFish.RANK = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6, mythical = 6, divine = 7, secret = 8 }
LockFish.RANK_VN = {
	["thông thường"] = 1, ["không phổ biến"] = 2, ["hiếm"] = 3, ["sử thi"] = 4, ["huyền thoại"] = 5,
	["thần thoại"] = 6, ["thần thánh"] = 7, ["bí mật"] = 8, ["bí ẩn"] = 8,
}

-- Độ hiếm (số 1-8) theo chữ trên nhãn, nil nếu không nhận ra
function LockFish.rankFromText(text)
	local l = string.lower(tostring(text or ""))
	l = l:gsub("^%s+", ""):gsub("%s+$", "")
	if l == "" then return nil end
	return LockFish.RANK[l] or LockFish.RANK_VN[l]
end

-- Màu của gradient tại vị trí t (0-1)
function LockFish.sample(kp, t)
	local prev = kp[1]
	for i = 2, #kp do
		local k = kp[i]
		if t <= k.Time then
			local span = k.Time - prev.Time
			local a = (span > 0) and (t - prev.Time) / span or 0
			return prev.Value:Lerp(k.Value, a)
		end
		prev = k
	end
	return kp[#kp].Value
end

function LockFish.gradDist(a, b)
	local total = 0
	for _, t in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
		local ca, cb = LockFish.sample(a, t), LockFish.sample(b, t)
		total = total + math.abs(ca.R - cb.R) + math.abs(ca.G - cb.G) + math.abs(ca.B - cb.B)
	end
	return total / 5
end

-- Độ hiếm theo màu gradient của nhãn (so với các gradient mẫu của game), nil nếu không khớp
function LockFish.rankFromGradient(g)
	if not (g and g:IsA("UIGradient")) then return nil end
	if not LockFish.index then
		local built = {}
		pcall(function()
			local assets = ReplicatedStorage:FindFirstChild("Assets")
			local uis = assets and assets:FindFirstChild("UIs")
			local folder = uis and uis:FindFirstChild("GradientRaritys")
			if folder then
				for _, gr in ipairs(folder:GetChildren()) do
					local rank = gr:IsA("UIGradient") and LockFish.RANK[string.lower(gr.Name)] or nil
					if rank then table.insert(built, { rank = rank, kp = gr.Color.Keypoints }) end
				end
			end
		end)
		if #built == 0 then return nil end
		LockFish.index = built
	end
	local kp = g.Color.Keypoints
	local best, bestD = nil, math.huge
	for _, e in ipairs(LockFish.index) do
		local d = LockFish.gradDist(kp, e.kp)
		if d < bestD then best, bestD = e, d end
	end
	if best and bestD < 0.12 then return best.rank end
	return nil
end

-- Danh sách cá trong túi: { frame, button, locked (ổ khoá), rarity (nhãn độ hiếm), name }, cùng ScrollingFrame chứa chúng
function LockFish.cards()
	local list = {}
	local satchel = PlayerGui:FindFirstChild("SatchelModal")
	local frame = satchel and satchel:FindFirstChild("Frame")
	local listFrame = frame and frame:FindFirstChild("List")
	local scroll = listFrame and listFrame:FindFirstChild("ScrollingFrame")
	if not scroll then return list, nil end
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") and not string.find(child.Name, "Template", 1, true) then
			local button = child:FindFirstChild("Button")
			if button and button:IsA("GuiButton") and button:FindFirstChild("FishWeightLabel") then
				local excl = button:FindFirstChild("Exclusion")
				table.insert(list, {
					frame = child,
					button = button,
					locked = excl and excl:FindFirstChild("Locked"),
					rarity = button:FindFirstChild("RarityLabel"),
					name = excl and excl:FindFirstChild("FishNameLabel"),
				})
			end
		end
	end
	return list, scroll
end

-- Cá đã khoá chưa (biểu tượng ổ khoá đang hiện)
function LockFish.isLocked(card)
	local l = card.locked
	if not (l and l:IsA("GuiObject") and l.Visible) then return false end
	if l:IsA("ImageLabel") and l.ImageTransparency >= 0.99 then return false end
	return true
end

-- Độ hiếm của 1 con cá: trả về (số 1-8 hoặc nil, chữ trên nhãn)
function LockFish.cardRank(card)
	local label = card.rarity
	if label and label:IsA("TextLabel") then
		local r = LockFish.rankFromText(label.Text)
		if r then return r, label.Text end
		local g = label:FindFirstChild("RarityColor") or label:FindFirstChildWhichIsA("UIGradient")
		return LockFish.rankFromGradient(g), label.Text
	end
	return nil, ""
end

-- Những con cần khoá: từ Config.LOCK_FISH_MIN_RARITY trở lên mà chưa khoá. Không nhận ra độ hiếm (nhưng nhãn có chữ) thì khoá cho chắc.
function LockFish.collect()
	local minRank = LockFish.RANK[string.lower(Config.LOCK_FISH_MIN_RARITY)] or 5
	local targets = {}
	local stats = { total = 0, locked = 0, unknown = 0 }
	for _, card in ipairs((LockFish.cards())) do
		stats.total = stats.total + 1
		if LockFish.isLocked(card) then
			stats.locked = stats.locked + 1
		else
			local rank, text = LockFish.cardRank(card)
			if rank then
				if rank >= minRank then table.insert(targets, card) end
			elseif text ~= "" then
				stats.unknown = stats.unknown + 1
				table.insert(targets, card)
			end
		end
	end
	return targets, stats
end

-- Bấm 1 nút: method "signal" = kích hoạt sự kiện nút (không cần mở túi), "press" = bấm theo toạ độ (túi phải đang mở)
function LockFish.click(btn, method)
	if method == "signal" then return signalClick(btn) end
	return clickButton(btn, "auto")
end

-- Đợi tối đa t giây cho ổ khoá của cá hiện ra (server cần chút thời gian phản hồi)
function LockFish.waitLocked(card, t)
	local w = 0
	while w < t do
		if LockFish.isLocked(card) then return true end
		task.wait(0.1)
		w = w + 0.1
	end
	return LockFish.isLocked(card)
end

-- Cuộn danh sách tới con cá (cần khi bấm theo toạ độ, cá nằm ngoài khung nhìn thì không bấm trúng được)
function LockFish.scrollTo(card, scroll)
	if not (scroll and scroll:IsA("ScrollingFrame")) then return end
	pcall(function()
		local y = card.frame.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
		scroll.CanvasPosition = Vector2.new(0, math.max(0, y - scroll.AbsoluteSize.Y / 3))
	end)
	task.wait(0.15)
end

function LockFish.isBagOpen()
	local satchel = PlayerGui:FindFirstChild("SatchelModal")
	local frame = satchel and satchel:FindFirstChild("Frame")
	return frame ~= nil and isReallyVisible(frame)
end

-- Nút mở / đóng túi đồ trên thanh hotbar (PlayerGui.Backpack.Frame.Holder.Satchel, ô số 2 "Túi đồ")
function LockFish.bagButton()
	local bp = PlayerGui:FindFirstChild("Backpack")
	local f = bp and bp:FindFirstChild("Frame")
	local h = f and f:FindFirstChild("Holder")
	local b = h and h:FindFirstChild("Satchel")
	if b and b:IsA("GuiButton") then return b end
	return nil
end

-- Đổi trạng thái túi (mở <-> đóng) thành want. Trả về true nếu đạt được trạng thái mong muốn.
function LockFish.setBag(want)
	if LockFish.isBagOpen() == want then return true end
	local btn = LockFish.bagButton()
	if not btn then return false end
	if hasSignalClick() then
		signalClick(btn)
		local t = 0
		while t < 1.5 and LockFish.isBagOpen() ~= want do
			task.wait(0.1)
			t = t + 0.1
		end
	end
	if LockFish.isBagOpen() ~= want then
		pressGui(btn, 0.05)
		local t = 0
		while t < 2 and LockFish.isBagOpen() ~= want do
			task.wait(0.1)
			t = t + 0.1
		end
	end
	task.wait(0.2)
	return LockFish.isBagOpen() == want
end

-- Chạy 1 lượt khoá cho danh sách targets bằng cách bấm `method`. Trả về số cá đã khoá thành công.
-- Tự dò kiểu hoạt động của nút ổ khoá:
--  - "chế độ khoá": bấm ổ khoá 1 lần, sau đó chỉ cần bấm vào từng con cá. Nếu đúng kiểu này thì cuối lượt bấm ổ khoá lần nữa để thoát chế độ.
--  - nếu bấm riêng vào cá không ăn thì mỗi con bấm ổ khoá rồi bấm cá (kiểu "chọn cá rồi khoá").
-- Con đầu tiên không khoá được thì dừng luôn (tránh bấm bừa vào túi).
function LockFish.pass(targets, method, scroll)
	local satchel = PlayerGui:FindFirstChild("SatchelModal")
	local frame = satchel and satchel:FindFirstChild("Frame")
	local fl = frame and frame:FindFirstChild("FunctionList")
	local lockHolder = fl and fl:FindFirstChild("Lock")
	local lockBtn = lockHolder and lockHolder:FindFirstChild("Button")
	if lockBtn and not lockBtn:IsA("GuiButton") then lockBtn = nil end

	local done = 0
	local modeOn, modeConfirmed, modeRejected = false, false, false
	for _, card in ipairs(targets) do
		if card.frame.Parent and not LockFish.isLocked(card) then
			if method == "press" then LockFish.scrollTo(card, scroll) end
			local ok = false

			-- chế độ khoá đã bật từ con trước: chỉ cần bấm vào cá
			if modeOn and not modeRejected then
				LockFish.click(card.button, method)
				ok = LockFish.waitLocked(card, 1.2)
				if ok then
					modeConfirmed = true
				else
					modeRejected = true
					modeOn = false
				end
			end

			if not ok and lockBtn then
				-- bấm ổ khoá rồi bấm cá; thử 2 lần vì nếu chế độ khoá vốn đang bật sẵn thì lần bấm ổ khoá đầu sẽ tắt nó đi
				for _ = 1, 2 do
					LockFish.click(lockBtn, method)
					task.wait(0.25)
					LockFish.click(card.button, method)
					if LockFish.waitLocked(card, 1.2) then
						ok = true
						break
					end
				end
				if ok and not modeRejected then modeOn = true end
			elseif not ok then
				-- không thấy nút ổ khoá: thử bấm thẳng vào cá
				LockFish.click(card.button, method)
				ok = LockFish.waitLocked(card, 1.2)
			end

			if ok then
				done = done + 1
			else
				break
			end
		end
	end

	-- đã chắc chắn là "chế độ khoá" (ít nhất 1 con khoá được chỉ bằng cách bấm vào cá): bấm ổ khoá để thoát chế độ, trả túi về bình thường.
	-- Chưa chắc thì KHÔNG bấm, vì kiểu "chọn cá rồi khoá" bấm ổ khoá lần nữa có thể mở khoá lại con vừa khoá.
	if modeOn and modeConfirmed and lockBtn then
		LockFish.click(lockBtn, method)
		task.wait(0.2)
	end
	return done
end

-- Nếu trên tay đang cầm 1 con cá (bấm vào cá trong túi có thể làm cầm cá lên) thì cất đi để Auto Farm còn cầm cần câu
function LockFish.unequip()
	pcall(function()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local tool = char and char:FindFirstChildOfClass("Tool")
		if hum and tool and isGuidName(tool.Name) then hum:UnequipTools() end
	end)
end

-- Kiểm tra túi và khoá cá. opts.force = true: dùng khi đang đi bán (Auto Farm đã tắt sẵn, được phép bấm theo toạ độ).
-- Trả về (số cá vừa khoá, trạng thái): "ok" | "none" (không có cá cần khoá) | "empty" (túi trống) | "partial" (còn cá chưa khoá được)
-- | "needpress" (máy không bấm ngầm được và Auto Farm đang chạy) | "nobag" (không mở được túi) | "busy"
function LockFish.run(opts)
	opts = opts or {}
	if LockFish.busy then return 0, "busy" end
	LockFish.busy = true
	local locked, status = 0, "ok"

	local ok, err = pcall(function()
		local targets, stats = LockFish.collect()
		if stats.total == 0 then
			status = "empty"
			return
		end
		if #targets == 0 then
			status = "none"
			return
		end

		-- 1) kích hoạt thẳng sự kiện nút: không cần mở túi, không đụng tới thao tác câu cá
		if hasSignalClick() then
			local _, scroll = LockFish.cards()
			locked = locked + LockFish.pass(targets, "signal", scroll)
			targets = LockFish.collect()
		end

		-- 2) còn cá chưa khoá: mở túi và bấm theo toạ độ (không làm khi Auto Farm đang chạy vì sẽ bấm lẫn vào nút câu cá)
		if #targets > 0 then
			if isRunning and not opts.force then
				status = "needpress"
				return
			end
			local openedByUs = false
			if not LockFish.isBagOpen() then
				openedByUs = LockFish.setBag(true)
			end
			if LockFish.isBagOpen() then
				local _, scroll = LockFish.cards()
				locked = locked + LockFish.pass(targets, "press", scroll)
				if openedByUs then LockFish.setBag(false) end
			else
				status = "nobag"
			end
			targets = LockFish.collect()
		end

		LockFish.unequip()
		if status == "ok" and #targets > 0 then status = "partial" end
	end)

	LockFish.busy = false
	if not ok then return locked, "partial" end
	return locked, status
end

-- Nút "Khoá cá ngay": chạy 1 lượt và báo kết quả bằng thông báo
function LockFish.manual()
	local n, status = LockFish.run({})
	local msg
	if status == "ok" then
		msg = "đã khoá " .. n .. " cá"
	elseif status == "none" then
		msg = "không có cá cần khoá"
	elseif status == "empty" then
		msg = "túi chưa có cá"
	elseif status == "partial" then
		msg = "khoá " .. n .. " cá, còn cá chưa khoá được"
	elseif status == "needpress" then
		msg = "tắt Auto Farm rồi bấm lại"
	elseif status == "nobag" then
		msg = "không mở được túi đồ"
	else
		msg = "đang chạy, thử lại sau"
	end
	pcall(notifyOwnFish, "Khoá cá", Config.LOCK_FISH_MIN_RARITY .. " trở lên", msg, true, 6)
end

-- Công tắc "Tự khoá cá": cứ Config.LOCK_FISH_INTERVAL giây kiểm tra túi, có cá cần khoá thì khoá.
-- Khoá lỗi 3 lượt liền thì nghỉ 2 phút (tránh bấm lặp đi lặp lại vô ích) và báo 1 lần.
function LockFish.loop()
	if LockFish.loopActive then return end
	LockFish.loopActive = true
	pcall(function()
		while LockFish.on and ScreenGui.Parent do
			if not Travel.busy() and not LockFish.busy and os.clock() >= LockFish.pauseUntil then
				local targets = LockFish.collect()
				if #targets > 0 and (hasSignalClick() or not isRunning) then
					local n, status = LockFish.run({})
					if n > 0 then
						pcall(notifyOwnFish, "Khoá cá", Config.LOCK_FISH_MIN_RARITY .. " trở lên", "đã khoá " .. n .. " cá", true, 5)
					end
					if status == "partial" or status == "nobag" then
						LockFish.fails = LockFish.fails + 1
						if LockFish.fails >= 3 then
							LockFish.fails = 0
							LockFish.pauseUntil = os.clock() + 120
							pcall(notifyOwnFish, "Khoá cá", "lỗi", "không khoá được, thử lại sau 2 phút", true, 6)
						end
					elseif status == "ok" then
						LockFish.fails = 0
					end
				end
			end
			local w = 0
			while LockFish.on and ScreenGui.Parent and w < Config.LOCK_FISH_INTERVAL do
				task.wait(0.5)
				w = w + 0.5
			end
		end
	end)
	LockFish.loopActive = false
end

-- ==================================================
-- FIX LAG: ẩn toàn bộ map / model / hiệu ứng (chỉ ẩn phía client, không xoá gì của game)
-- Quét lại mỗi Config.FIXLAG_INTERVAL giây và ẩn tiếp thứ mới xuất hiện. Lần bật đầu tiên cũng tự áp
-- Config.GAME_SETTINGS (tắt VFX/damage số/camera shake trong menu Settings của game) để giảm lag thêm.
-- Tắt công tắc thì trả mọi thứ về như cũ (không tự bật lại các cài đặt game đã tắt).
-- KHÔNG đụng tới hiệu ứng nằm trong BossRegions: Boss Zone / Auto Câu Boss nhận biết boss đang spawn nhờ các hiệu ứng đó đang BẬT,
-- nếu Fix Lag tắt chúng thì boss spawn rồi vẫn báo "chưa spawn".
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

local function fixLagHide(inst, char)
	if inst:IsA("Terrain") then return end
	local prop, hidden
	if inst:IsA("BasePart") then
		prop, hidden = "LocalTransparencyModifier", 1
	elseif inst:IsA("Decal") then
		prop, hidden = "Transparency", 1
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Fire")
		or inst:IsA("Smoke") or inst:IsA("Sparkles") or inst:IsA("Light")
		or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
		if inst:FindFirstAncestor("BossRegions") then return end
		prop, hidden = "Enabled", false
	else
		return
	end
	char = char or LocalPlayer.Character
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
	local char = LocalPlayer.Character
	local n = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		if not fixLagOn then return end
		pcall(fixLagHide, inst, char)
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
	task.spawn(function() pcall(applyGameSettings, true) end) -- true: người dùng vừa bật Fix Lag => thử lại mọi mục từ đầu
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

-- Auto Câu Boss mặc định đi bằng xe của game (NPC bán xe gần nhất chỗ đang đứng); chọn loại xe ở đây
do
local BoatGrid = Create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, ZIndex = 20 }, FarmTab)
Create("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 0, 34), CellPadding = UDim2.new(0, 6, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, BoatGrid)
local boatBtns = {}
for order, label in ipairs({ "Truck (miễn phí)", "Red Truck" }) do
	local btn = Create("TextButton", { LayoutOrder = order, Size = UDim2.new(0, 60, 0, 34), BackgroundColor3 = UITheme.Accent, BackgroundTransparency = 0.1, Text = label, TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 12, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 20 }, BoatGrid)
	Corner(btn, 10)
	Stroke(btn, Color3.fromRGB(255, 255, 255), 0.2, 1)
	boatBtns[order] = btn
end
local function paintBoatBtns()
	for order, btn in ipairs(boatBtns) do
		local on = Config.BOAT_CHOICE == order
		btn.BackgroundColor3 = on and UITheme.Accent or Color3.fromRGB(150, 150, 158)
		btn.BackgroundTransparency = on and 0.1 or 0.4
	end
end
for order, btn in ipairs(boatBtns) do
	btn.MouseButton1Click:Connect(function()
		Config.BOAT_CHOICE = order
		paintBoatBtns()
	end)
end
paintBoatBtns()
end

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

-- Khoá cá trong túi đồ: cá đã khoá không bị "Bán tất cả" bán. Công tắc = có tự khoá hay không; nút = khoá ngay 1 lượt.
CreateSection(FarmTab, "Khoá Cá")
CreateToggle(FarmTab, "Tự khoá cá Huyền thoại trở lên", false, function(v)
	LockFish.on = v
	if v then
		LockFish.fails = 0
		LockFish.pauseUntil = 0
		task.spawn(LockFish.loop)
	end
end)
CreateButton(FarmTab, "Khoá cá Huyền thoại+ ngay (kiểm tra túi)", function()
	task.spawn(LockFish.manual)
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

for islandIdx, island in ipairs(Islands) do
	local name, pos = island[1], island[2]
	CreateButton(IslandGrid, "Tới " .. name, function()
		if not Travel.try("island") then return end -- đang bán cá / đang dịch chuyển khác: bỏ qua cú bấm
		task.spawn(function()
			-- không dùng dịch chuyển: đi xe (gọi ở NPC bán xe gần nhất) tới đảo, đi bộ nốt
			local ok2, why = pcall(Travel.Boat.go, pos, Config.BOAT_CHOICE, islandIdx)
			if not ok2 or why == false then pcall(notifyOwnFish, "Đi xe", "lỗi", "không tới được " .. name, true, 5) end
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
			local okb = Travel.Boat.go(island[2], Config.BOAT_CHOICE, i) -- đi xe tới đảo có boss (không dùng dịch chuyển)
			if not okb then pcall(notifyOwnFish, "Đi xe", "lỗi", "không tới được " .. island[1], true, 5) end
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
-- LÕI LÁI THUYỀN (Lua thuần, không dùng API Roblox nên mô phỏng kiểm tra được ngoài game)
-- Hệ toạ độ: mặt phẳng (x, z) của Roblox. "Trái/phải" tính khi nhìn từ trên xuống, cùng dấu với Vector3:Cross().Y.
--
-- Core.step quyết định ga (-1..1) và lái (-1..1; dương = rẽ phải) mỗi nhịp điều khiển:
--   1) Nhìn trước bằng tia (cast) theo hành lang rộng bằng thân xe. Hướng thẳng tới đích thoáng => đi thẳng.
--   2) Vướng vật cản => quét 24 hướng quanh hướng đích, chọn hướng ĐỦ THOÁNG (tăng theo tốc độ) lệch ít nhất.
--      Giữ nguyên bên đã chọn để lượn dọc bờ đảo tới khi đường thẳng tới đích thoáng (không đổi bên liên tục).
--   3) Kẹt (ga dương mà không nhích) => lùi ra (lùi xa tuỳ chỗ trống phía sau), nhớ hướng đã kẹt, lần sau đi cẩn thận hơn
--      (nhìn xa hơn, chạy chậm hơn). Kẹt nhiều lần ở cùng chỗ => đổi bên né + chạy ra xa vuông góc hướng đích.
--   4) Quanh quẩn trong một vùng nhỏ quá lâu => coi là lạc đường: đổi bên + điểm thoát.
--   5) Tự học 2 điều chưa biết của xe: "ga dương" thực ra đi lùi so với hướng ghế (fwdSign) và "lái dương" thực ra quay trái (steerSign).
-- Plan.route: lộ trình các điểm đi vòng quanh các đảo (hình tròn) nằm chắn đường, đi theo tiếp tuyến.
-- ==================================================
Travel.BoatCore, Travel.BoatPlan = (function()
	local Core, Plan = {}, {}

	local PI = math.pi
	local sqrt, abs, sin, cos, acos = math.sqrt, math.abs, math.sin, math.cos, math.acos
	local min, max, ceil = math.min, math.max, math.ceil
	local atan2 = math.atan2 or math.atan
	local DEG = 180 / PI

	local function clamp(v, a, b)
		if v < a then return a end
		if v > b then return b end
		return v
	end

	local function unit(x, z)
		local m = sqrt(x * x + z * z)
		if m < 1e-9 then return 0, 0, 0 end
		return x / m, z / m, m
	end

	-- Góc có dấu từ vector a tới vector b (radian). Dương = b nằm bên TRÁI a.
	local function sang(ax, az, bx, bz)
		return atan2(az * bx - ax * bz, ax * bx + az * bz)
	end

	-- Quay vector (x, z) sang trái góc a (radian)
	local function rotl(x, z, a)
		local c, s = cos(a), sin(a)
		return x * c + z * s, -x * s + z * c
	end

	-- 24 hướng thử, tính từ hướng tới đích: 0, ±15, ±30, ... ±165, 180 độ (dương = quay sang trái)
	local ANGLES = { 0 }
	for k = 1, 11 do
		ANGLES[#ANGLES + 1] = k * PI / 12
		ANGLES[#ANGLES + 1] = -k * PI / 12
	end
	ANGLES[#ANGLES + 1] = PI

	-- Khoảng thoáng dọc hướng (dx, dz) từ (px, pz), bề ngang nửa w: 3 tia (giữa, trái, phải), thân xe rộng thì 5 tia; lấy tia ngắn nhất.
	-- cast(ox, oz, dx, dz, len) -> khoảng cách tới vật cản (len nếu không có).
	local function corridor(cast, px, pz, dx, dz, len, w)
		local c = cast(px, pz, dx, dz, len)
		if c < 1 then return c end
		local nx, nz = dz, -dx
		local m = c
		local l = cast(px + nx * w, pz + nz * w, dx, dz, len)
		if l < m then m = l end
		local r = cast(px - nx * w, pz - nz * w, dx, dz, len)
		if r < m then m = r end
		if w >= 8 then
			local h = w * 0.5
			local l2 = cast(px + nx * h, pz + nz * h, dx, dz, len)
			if l2 < m then m = l2 end
			local r2 = cast(px - nx * h, pz - nz * h, dx, dz, len)
			if r2 < m then m = r2 end
		end
		return m
	end

	Core.corridor = corridor

	function Core.new()
		return {
			t0 = nil,
			mode = "go", -- go | reverse
			info = "",
			side = 0, -- +1: ưu tiên né sang TRÁI hướng đích, -1: sang phải, 0: chưa chọn
			freeSince = nil,
			blocked = {}, -- các hướng vừa bị kẹt { x, z, t }
			hist = {},
			histT = -1e9,
			revUntil = 0,
			revStart = 0,
			revSteer = 0,
			graceUntil = 0,
			stuckTimes = {}, -- { t, x, z }
			stuckN = 0,
			caution = 0, -- 0..3: càng kẹt nhiều càng cẩn thận (nhìn xa hơn, chạy chậm hơn); tự giảm dần
			cautionT = nil,
			scanT = -1e9,
			c0 = 1e9,
			cfwd = 1e9,
			backC = 1e9,
			tx = 0,
			tz = 0,
			how = "free",
			thr = 0,
			steer = 0,
			thrPosSince = nil,
			fwdSign = 1,
			steerSign = 1,
			fwdVotes = 0,
			steerVotes = 0,
			learnT = -1e9,
			learnFx = nil,
			learnFz = nil,
			learnSteerSum = 0,
			learnSteerN = 0,
			learnGrace = 0,
			anchor = nil, -- {x, z, t}: mốc để phát hiện quanh quẩn một chỗ
			lost = 0,
			esc = nil,
			revCheckT = -1e9,
		}
	end

	-- mẫu lịch sử cũ hơn `sec` giây gần nhất
	local function posAgo(S, now, sec)
		local h = S.hist
		for i = #h, 1, -1 do
			if h[i].t <= now - sec then return h[i] end
		end
		return nil
	end

	-- điểm thoát: đi thẳng ra xa theo hướng vuông góc với hướng đích, về phía thoáng hơn
	local function makeEscape(S, now, cast, px, pz, ux, uz, w)
		local lx, lz = rotl(ux, uz, PI / 2)
		local rx, rz = rotl(ux, uz, -PI / 2)
		local cl = corridor(cast, px, pz, lx, lz, 260, w)
		local cr = corridor(cast, px, pz, rx, rz, 260, w)
		local ex, ez, side
		if cl >= cr then ex, ez, side = lx, lz, 1 else ex, ez, side = rx, rz, -1 end
		local dist = clamp(max(cl, cr) - 25, 60, 240)
		S.esc = { x = px + ex * dist, z = pz + ez * dist, untilT = now + 30 }
		S.side = side
	end

	local function startReverse(S, now, secs, steer, why)
		S.mode = "reverse"
		S.revStart = now
		S.revUntil = now + secs
		S.revSteer = steer or 0
		S.info = why or "lùi ra"
		S.thrPosSince = nil
	end

	local function registerStuck(S, now, cast, px, pz, fx, fz, ux, uz, w, why)
		S.stuckN = S.stuckN + 1
		local t = S.stuckTimes
		t[#t + 1] = { t = now, x = px, z = pz }
		while #t > 0 and t[1].t < now - 60 do table.remove(t, 1) end
		-- bao nhiêu lần kẹt gần chỗ này (trong 150 stud) gần đây
		local near = 0
		for _, e in ipairs(t) do
			if (e.x - px) ^ 2 + (e.z - pz) ^ 2 < 150 * 150 then near = near + 1 end
		end
		S.caution = min(S.caution + 0.6, 3)
		S.cautionT = now
		S.blocked[#S.blocked + 1] = { x = fx, z = fz, t = now }
		-- chỗ trống phía sau quyết định lùi bao lâu
		S.backC = corridor(cast, px, pz, -fx, -fz, 160, w)
		local secs = clamp((S.backC - 15) / 22, 1.3, 7) + 0.5 * (near - 1)
		local steer = 0
		if near >= 3 then steer = (near % 2 == 1) and 1 or -1 end -- kẹt nhiều lần: vừa lùi vừa vặn lái cho đuôi xe xoay đi
		startReverse(S, now, min(secs, 9), steer, why or "kẹt, lùi ra")
		if near >= 3 then
			-- kẹt lặp lại ở cùng chỗ: né sang bên kia + chạy ra xa
			S.side = (S.side ~= 0) and -S.side or 0
			makeEscape(S, now, cast, px, pz, ux, uz, w)
		end
	end

	-- Một nhịp điều khiển.
	-- S: trạng thái (Core.new()); now: giây; (px, pz): vị trí xe; (lx, lz): vector "trước" của ghế (LookVector, không cần chuẩn hoá);
	-- (gx, gz): điểm cần tới; cast: hàm bắn tia (xem corridor);
	-- o: { look = tầm nhìn tối đa, w = nửa bề ngang thân xe, approach = đang áp sát đảo đích (nới khoảng thoáng), lostAfter = giây quanh quẩn }
	-- Trả về: ga, lái, chữ mô tả
	function Core.step(S, now, px, pz, lx, lz, gx, gz, cast, o)
		o = o or {}
		local look = o.look or 200
		local w = o.w or 8
		local approach = o.approach

		if not S.t0 then
			S.t0 = now
			S.learnT = now
			S.anchor = { x = px, z = pz, t = now }
			S.cautionT = now
		end

		local fx, fz = unit(lx, lz)
		if fx == 0 and fz == 0 then return 0, 0, "không rõ hướng xe" end
		fx, fz = fx * S.fwdSign, fz * S.fwdSign

		-- cẩn thận giảm dần theo thời gian (nửa sau ~40 giây)
		if S.caution > 0 then
			S.caution = max(0, S.caution - (now - S.cautionT) / 40)
		end
		S.cautionT = now

		-- lịch sử vị trí (mỗi 0.2 giây)
		if now - S.histT >= 0.2 then
			S.histT = now
			S.hist[#S.hist + 1] = { t = now, x = px, z = pz }
			while #S.hist > 0 and S.hist[1].t < now - 10 do table.remove(S.hist, 1) end
		end

		-- tốc độ (theo 0.8 giây gần nhất)
		local speedAbs, speedFwd = 0, 0
		local h0 = posAgo(S, now, 0.8)
		if h0 and now - h0.t > 0.2 then
			local vx, vz = (px - h0.x) / (now - h0.t), (pz - h0.z) / (now - h0.t)
			speedAbs = sqrt(vx * vx + vz * vz)
			speedFwd = vx * fx + vz * fz
		end

		local rux, ruz, rdist = unit(gx - px, gz - pz)

		-- quanh quẩn một vùng nhỏ quá lâu (đi tới đi lui) => lạc đường
		local a = S.anchor
		if (a.x - px) ^ 2 + (a.z - pz) ^ 2 > 160 * 160 then
			S.anchor = { x = px, z = pz, t = now }
		elseif now - a.t > (o.lostAfter or 40) and S.mode == "go" and not S.esc then
			S.lost = S.lost + 1
			S.anchor = { x = px, z = pz, t = now }
			S.side = (S.side ~= 0) and -S.side or 0
			makeEscape(S, now, cast, px, pz, rux, ruz, w)
			S.info = "quanh quẩn, đổi hướng"
		end

		-- ===== đang lùi =====
		if S.mode == "reverse" then
			if now - S.revCheckT > 0.15 then
				S.revCheckT = now
				S.backC = corridor(cast, px, pz, -fx, -fz, 60, w)
			end
			if now >= S.revUntil or S.backC < 9 then
				S.mode = "go"
				S.graceUntil = now + 2.0
				S.hist = {}
				S.histT = -1e9
				S.info = "tiến lại"
				S.learnT = now
				S.learnFx, S.learnFz = nil, nil
				S.learnSteerSum, S.learnSteerN = 0, 0
				S.scanT = -1e9
			else
				S.thr, S.steer = -1, S.revSteer
				return -1, S.revSteer, S.info
			end
		end

		-- ===== phát hiện kẹt =====
		if S.mode == "go" and now >= S.graceUntil and S.thrPosSince and (now - S.t0) > 3.0 then
			local held = now - S.thrPosSince
			local h1 = posAgo(S, now, 1.8)
			if h1 and held >= 1.8 then
				local moved = sqrt((px - h1.x) ^ 2 + (pz - h1.z) ^ 2)
				if moved < 2.2 then
					registerStuck(S, now, cast, px, pz, fx, fz, rux, ruz, w, "kẹt, lùi ra")
					return -1, S.revSteer, S.info
				end
			end
			local h2 = posAgo(S, now, 5.0)
			if h2 and held >= 5.0 then
				local moved = sqrt((px - h2.x) ^ 2 + (pz - h2.z) ^ 2)
				if moved < 7 then
					registerStuck(S, now, cast, px, pz, fx, fz, rux, ruz, w, "nhích quá chậm, lùi ra")
					return -1, S.revSteer, S.info
				end
			end
		end

		-- ===== điểm thoát đang có hiệu lực: coi như đích tạm =====
		local tgx, tgz = gx, gz
		if S.esc then
			local ed = sqrt((S.esc.x - px) ^ 2 + (S.esc.z - pz) ^ 2)
			if now > S.esc.untilT or ed < 40 then
				S.esc = nil
			else
				tgx, tgz = S.esc.x, S.esc.z
			end
		end
		local ux, uz, dist = unit(tgx - px, tgz - pz)
		if dist < 0.5 then return 0, 0, "tới nơi" end

		-- ===== nhìn trước + chọn hướng =====
		local caut = 1 + 0.3 * S.caution
		local need = clamp((speedAbs + 30) * caut, 45, 180)
		local hard = clamp((speedAbs * 0.35 + 14) * caut, 18, 70)
		if approach then
			need = min(need, 28)
			hard = min(hard, 14)
		end
		local lookd = min(look, dist + 30)
		lookd = max(lookd, min(look, 60))
		need = min(need, lookd)
		hard = min(hard, need)

		if now - S.scanT >= (S.how == "free" and 0.3 or 0.2) then
			S.scanT = now
			S.cfwd = corridor(cast, px, pz, fx, fz, lookd, w)
			local c0 = corridor(cast, px, pz, ux, uz, lookd, w)
			S.c0 = c0
			if c0 >= lookd - 0.5 then
				S.how = "free"
				S.tx, S.tz = ux, uz
				if not S.freeSince then S.freeSince = now end
				if now - S.freeSince > 4 then S.side = 0 end -- đi thoáng đủ lâu: bỏ nhớ bên né
			else
				S.freeSince = nil
				local bestCost, bx, bz, bphi = 1e18, nil, nil, 0
				local relaxCost, rx, rz, rphi = 1e18, nil, nil, 0
				local maxC, mx, mz = -1, nil, nil
				-- hướng vừa kẹt còn hiệu lực
				for i = #S.blocked, 1, -1 do
					if now - S.blocked[i].t > 15 then table.remove(S.blocked, i) end
				end
				for _, phi in ipairs(ANGLES) do
					local dx, dz = rotl(ux, uz, phi)
					local c = (phi == 0) and c0 or corridor(cast, px, pz, dx, dz, lookd, w)
					if c > maxC then maxC, mx, mz = c, dx, dz end
					if c >= hard then
						local cost = abs(phi) * DEG
						local sg = (phi > 0 and 1) or (phi < 0 and -1) or 0
						if S.side ~= 0 and sg ~= 0 and sg ~= S.side then cost = cost + 45 end
						cost = cost + 0.30 * abs(sang(fx, fz, dx, dz)) * DEG
						cost = cost - 0.15 * min(c, lookd)
						for _, b in ipairs(S.blocked) do
							if abs(sang(b.x, b.z, dx, dz)) < 0.6 then cost = cost + 60 end
						end
						if c >= need then
							if cost < bestCost then bestCost, bx, bz, bphi = cost, dx, dz, phi end
						elseif cost < relaxCost then
							relaxCost, rx, rz, rphi = cost, dx, dz, phi
						end
					end
				end
				if bx then
					S.tx, S.tz, S.how = bx, bz, "avoid"
					if abs(bphi) >= 0.2 and S.side == 0 then S.side = (bphi > 0) and 1 or -1 end
				elseif rx then
					S.tx, S.tz, S.how = rx, rz, "squeeze"
					if abs(rphi) >= 0.2 and S.side == 0 then S.side = (rphi > 0) and 1 or -1 end
				elseif maxC >= 8 then
					S.tx, S.tz, S.how = mx, mz, "trapped"
				else
					S.tx, S.tz, S.how = ux, uz, "trapped"
				end
			end
		elseif S.how == "free" then
			S.tx, S.tz = ux, uz
		end

		-- ===== lái =====
		local err = sang(fx, fz, S.tx, S.tz)

		-- phía trước bị chắn mà hướng đi tốt nhất nằm gần như phía sau (hoặc phải quay gấp sát vật cản): lùi ra trước rồi mới quay
		if S.how ~= "free" and now >= S.graceUntil and (now - S.t0) > 1.0 then
			local blockedAhead = S.cfwd < need
			if (blockedAhead and abs(err) > 1.75 and speedAbs < 25) or (S.cfwd < hard * 0.8 and abs(err) > 1.0 and speedAbs < 14) then
				local back = corridor(cast, px, pz, -fx, -fz, 160, w)
				if back >= 30 then
					S.backC = back
					startReverse(S, now, clamp((back - 15) / 22, 1.2, 7), 0, "lùi ra để quay đầu")
					S.thr, S.steer = -1, 0
					return -1, 0, S.info
				end
			end
		end

		local steerCmd = -clamp(err / 0.55, -1, 1) * S.steerSign

		local thr = 1
		if S.cfwd < need then
			thr = clamp((S.cfwd - hard) / max(need - hard, 1), 0.4, 1)
		end
		-- quay gấp thì bớt ga cho xe kịp quay
		if abs(err) > 0.5 then thr = min(thr, 1 - 0.35 * clamp((abs(err) - 0.5) / 1.0, 0, 1)) end
		if S.how == "trapped" then thr = min(thr, 0.4) end
		if approach then thr = min(thr, clamp(dist / 90, 0.45, 1)) end

		-- ===== ghi nhận để phát hiện kẹt =====
		if thr >= 0.35 then
			if not S.thrPosSince then S.thrPosSince = now end
		else
			S.thrPosSince = nil
		end

		-- ===== tự học chiều xe (mỗi 0.5 giây) =====
		S.learnSteerSum = S.learnSteerSum + steerCmd
		S.learnSteerN = S.learnSteerN + 1
		if now - S.learnT >= 0.5 then
			local avgSteer = S.learnSteerSum / max(S.learnSteerN, 1)
			if S.learnFx and now >= S.learnGrace and S.mode == "go" then
				-- (a) ga dương mà xe lại chạy lùi so với hướng ghế
				if S.thrPosSince and now - S.thrPosSince > 1.5 and speedAbs > 8 and S.cfwd > 40 then
					if speedFwd < -0.5 * speedAbs then
						S.fwdVotes = S.fwdVotes + 1
					elseif speedFwd > 0.3 * speedAbs then
						S.fwdVotes = 0
					end
					if S.fwdVotes >= 3 then
						S.fwdSign = -S.fwdSign
						S.fwdVotes = 0
						S.learnGrace = now + 3
						S.graceUntil = now + 1.5
						S.info = "đảo chiều tiến"
					end
				end
				-- (b) lái một chiều mà xe quay chiều ngược lại (lệnh thật = lái đã nhân steerSign)
				local dyaw = sang(S.learnFx, S.learnFz, fx, fz)
				if abs(avgSteer) > 0.7 and speedFwd > 6 and abs(dyaw) > 0.04 then
					if (dyaw > 0) == (avgSteer > 0) then
						S.steerVotes = S.steerVotes + 1
					else
						S.steerVotes = max(S.steerVotes - 1, 0)
					end
					if S.steerVotes >= 3 then
						S.steerSign = -S.steerSign
						S.steerVotes = 0
						S.learnGrace = now + 3
						S.info = "đảo chiều lái"
					end
				end
			end
			S.learnT = now
			S.learnFx, S.learnFz = fx, fz
			S.learnSteerSum, S.learnSteerN = 0, 0
		end

		S.thr, S.steer = thr, steerCmd
		local info = S.esc and "chạy ra xa để thoát" or (S.how == "free" and "thẳng tới đích" or ("né vật cản (" .. S.how .. ")"))
		return thr, steerCmd, info
	end

	-- ==================================================
	-- LỘ TRÌNH ĐI VÒNG ĐẢO
	-- circles: { {x=, z=, r=, id=}, ... } mỗi đảo là 1 hình tròn (r đã gồm khoảng đệm). Trả về danh sách điểm {x, z} (không gồm điểm đầu và đích).
	-- o: { skip = { [id] = true } đảo bỏ qua (đảo đích), pref = 1/-1 ưu tiên đi vòng theo chiều cùng/ngược kim đồng hồ, bonus = độ ưu tiên (stud) }
	-- Đi theo tiếp tuyến: từ điểm hiện tại tới tiếp điểm, lượn theo cung, rời cung ở tiếp điểm hướng tới đích. Chọn chiều ngắn hơn.
	-- ==================================================
	local function distPtSeg(px, pz, ax, az, bx, bz)
		local abx, abz = bx - ax, bz - az
		local l2 = abx * abx + abz * abz
		local t = 0
		if l2 > 1e-9 then t = clamp(((px - ax) * abx + (pz - az) * abz) / l2, 0, 1) end
		local qx, qz = ax + abx * t, az + abz * t
		return sqrt((px - qx) ^ 2 + (pz - qz) ^ 2), t
	end

	local function around(p, g, c, pref, bonus)
		local R = c.r
		local dPx, dPz = p.x - c.x, p.z - c.z
		local dGx, dGz = g.x - c.x, g.z - c.z
		local dP, dG = sqrt(dPx * dPx + dPz * dPz), sqrt(dGx * dGx + dGz * dGz)
		if dP <= R * 1.001 or dG <= R * 1.001 then return nil end
		local phiP, phiG = atan2(dPz, dPx), atan2(dGz, dGx)
		local aP, aG = acos(R / dP), acos(R / dG)
		local twoPi = 2 * PI
		-- ngược chiều kim đồng hồ (góc cực tăng): rời p ở phiP + aP, tới g ở phiG - aG
		local dccw = ((phiG - aG) - (phiP + aP)) % twoPi
		-- cùng chiều kim đồng hồ (góc cực giảm): rời p ở phiP - aP, tới g ở phiG + aG
		local dcw = ((phiP - aP) - (phiG + aG)) % twoPi
		local tan = sqrt(dP * dP - R * R) + sqrt(dG * dG - R * R)
		local lccw, lcw = tan + R * dccw, tan + R * dcw
		if pref == 1 then lccw = lccw - (bonus or 0) elseif pref == -1 then lcw = lcw - (bonus or 0) end
		local ccw = lccw <= lcw
		local a1 = ccw and (phiP + aP) or (phiP - aP)
		local span = ccw and dccw or dcw
		local dir = ccw and 1 or -1
		local n = max(1, ceil(span / (PI / 4)))
		local step = span / n
		local pts = {}
		pts[#pts + 1] = { x = c.x + R * cos(a1), z = c.z + R * sin(a1) }
		local rr = R / cos(step / 2)
		for k = 1, n - 1 do
			local ak = a1 + dir * step * k
			pts[#pts + 1] = { x = c.x + rr * cos(ak), z = c.z + rr * sin(ak) }
		end
		local a2 = a1 + dir * span
		pts[#pts + 1] = { x = c.x + R * cos(a2), z = c.z + R * sin(a2) }
		return pts, (ccw and 1 or -1), (ccw and lccw or lcw)
	end

	function Plan.route(sx, sz, gx, gz, circles, o)
		o = o or {}
		local skip = o.skip or {}
		local pts = {}
		local cur = { x = sx, z = sz }
		local g = { x = gx, z = gz }

		-- đang đứng trong hình tròn của đảo nào đó (đảo xuất phát): đi thẳng ra ngoài trước
		for _, c in ipairs(circles) do
			if not skip[c.id] then
				local dx, dz = cur.x - c.x, cur.z - c.z
				local d = sqrt(dx * dx + dz * dz)
				if d < c.r then
					local ux, uz = unit(dx, dz)
					if d < 1 then ux, uz = unit(c.x - g.x, c.z - g.z) end
					cur = { x = c.x + ux * (c.r + 25), z = c.z + uz * (c.r + 25) }
					pts[#pts + 1] = { x = cur.x, z = cur.z }
				end
			end
		end

		local lastSide = nil
		for _ = 1, 6 do
			-- đảo chắn đường gần nhất dọc đoạn cur -> g
			local hit, hitT = nil, 2
			for _, c in ipairs(circles) do
				if not skip[c.id] then
					local d, t = distPtSeg(c.x, c.z, cur.x, cur.z, g.x, g.z)
					if d < c.r * 0.97 and t < hitT then hit, hitT = c, t end
				end
			end
			if not hit then break end
			local pts2, side = around(cur, g, hit, o.pref, o.bonus or 0)
			if not pts2 then break end
			for _, p in ipairs(pts2) do pts[#pts + 1] = p end
			cur = pts2[#pts2]
			lastSide = side
		end
		return pts, lastSide
	end

	return Core, Plan
end)()

-- ==================================================
-- XE / THUYỀN CỦA GAME (Boat) cho Auto Câu Boss, nút "Tới <đảo>" (tab Đảo) và nút "Tới" (tab Boss Zone)
-- Trình tự Boat.go: đi bộ tới NPC "Boat Merchant" (npc_car_merchant_*) GẦN NHẤT -> mở hộp thoại -> "Gọi xe" -> chọn Truck / Red Truck
--   -> lên xe (Workspace.Cars.<UserId>, ghế lái DSeat kiểu VehicleSeat) -> lái tới đảo đích -> tới sát bờ thì nhảy lên part gần nhất
--   -> đi bộ tới toạ độ đã đặt sẵn của đảo, rồi tới đích. Không dùng dịch chuyển.
-- GỌI XE CHẮC ĂN LẦN ĐẦU: mở NPC bằng Travel.openPrompt (kiểm tra hộp thoại có mở thật, thử lại ngay nếu chưa); mỗi lần bấm nút đều
--   KIỂM TRA màn hình có đổi không rồi mới đi tiếp (không đổi thì đổi cách bấm ngay, không đợi cả vòng); nhớ cách bấm đã có tác dụng.
-- LÁI NÉ VẬT CẢN (Travel.BoatCore): mỗi nhịp bắn tia nhìn trước theo hành lang rộng bằng thân xe; vướng thì chọn hướng thoáng lệch ít nhất
--   và bám theo bờ đảo tới khi đường tới đích thoáng lại; kẹt thì lùi ra rồi chọn hướng khác; quanh quẩn một chỗ thì đổi bên + chạy ra xa.
--   Có lộ trình đi vòng các đảo chắn đường (Travel.BoatPlan). Lái bằng ThrottleFloat / SteerFloat đặt MỖI KHUNG HÌNH (BindToRenderStep
--   ưu tiên cuối để đè lên bộ điều khiển mặc định của game vốn đặt lại về 0 khi không bấm phím).
-- Mọi bước lỗi đều trả về false, lý do để nơi gọi báo cho người dùng.
-- ==================================================
Travel.Boat = (function()
	local Boat = {}
	local Nav = Travel.Nav
	local Core, Plan = Travel.BoatCore, Travel.BoatPlan
	local BIND = "ChisatoDrive"
	local sqrt, floor, huge = math.sqrt, math.floor, math.huge

	Boat.stop = false -- đặt true để huỷ mọi chuyến đang chạy (vd khi tắt hub)
	Boat.onStatus = nil -- tuỳ chọn: hàm(chữ) nhận trạng thái đang làm gì
	Boat.lastStatus = ""
	Boat.badCar = setmetatable({}, { __mode = "k" }) -- xe không lên được: lần sau gọi xe mới
	Boat.clickMode = nil -- cách bấm nút hộp thoại đã từng có tác dụng (nhớ cho lần sau)
	Boat.ISLAND_R = 330 -- bán kính ước lượng của 1 đảo (stud). Không biết bán kính thật nên khi lập lộ trình đệm thêm ISLAND_PAD
	Boat.ISLAND_PAD = 70

	local function clamp(v, a, b)
		if v < a then return a end
		if v > b then return b end
		return v
	end

	local function flatDist(a, b)
		return sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
	end

	local function status(text)
		Boat.lastStatus = text
		local f = Boat.onStatus
		if f then pcall(f, text) end
	end

	-- ---------- hộp thoại NPC ----------
	local function carText(obj)
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
		return (string.lower(text):gsub("%s+", " "))
	end

	-- Danh sách nút đang hiện trong hộp thoại NPC: { {obj=..., text=chữ thường bỏ thẻ định dạng} }
	local function listOptions()
		local out = {}
		if not isDialogueOpen() then return out end
		local actions = PlayerGui.Dialogue.Frame:FindFirstChild("Actions")
		if not actions then return out end
		for _, obj in ipairs(actions:GetDescendants()) do
			if obj:IsA("GuiButton") and obj.Visible and not (obj.Parent and obj.Parent:IsA("UIListLayout")) then
				local text = (carText(obj):gsub("<[^>]+>", ""))
				out[#out + 1] = { obj = obj, text = text }
			end
		end
		return out
	end

	-- bỏ ký tự có dấu (byte >= 128) để so khớp không phụ thuộc kiểu mã hoá Unicode của chữ trong game
	local function ascii(s)
		return (s:gsub("[\128-\255]", ""))
	end

	local function isCall(t)
		return t:find("gọi xe", 1, true) ~= nil or ascii(t):find("go?i%s*xe") ~= nil or t:find("call", 1, true) ~= nil
	end

	local function isCarName(t, name)
		return t:find(name, 1, true) ~= nil
	end

	Boat.OPTIONS = {
		{ name = "Truck", pred = function(t) return t:find("^truck") ~= nil or (t:find("truck", 1, true) ~= nil and t:find("red", 1, true) == nil) end },
		{ name = "Red Truck", pred = function(t) return isCarName(t, "red truck") end },
	}

	-- màn hình danh sách xe hiện ra sau khi bấm "Gọi xe"
	local function isCarList(t)
		return t:find("truck", 1, true) ~= nil
	end

	-- nút KHÔNG phải cái cần bấm: đặt điểm hồi / để sau / tạm biệt
	local function isOther(t)
		local a = ascii(t)
		return t:find("hồi", 1, true) ~= nil or t:find("sau", 1, true) ~= nil or a:find("sau", 1, true) ~= nil
			or t:find("spawn", 1, true) ~= nil or t:find("later", 1, true) ~= nil or t:find("bye", 1, true) ~= nil
			or t:find("tạm biệt", 1, true) ~= nil or t:find("đặt", 1, true) ~= nil
	end

	-- nút đầu tiên không phải đặt điểm hồi / để sau (dự phòng khi chữ "Gọi xe" đọc không ra)
	local function isFirstOther(t)
		return not isOther(t) and not isCarList(t)
	end

	local function findOption(pred)
		for _, o in ipairs(listOptions()) do
			if pred(o.text) then return o end
		end
		return nil
	end

	local MODE_ORDER = { "signal", "select", "noinset", "inset", "auto" }

	-- Bấm nút thoả pred bằng từng CÁCH BẤM, mỗi cách đợi tối đa maxWait giây xem check() có thành true (màn hình đã đổi) không.
	-- Không đổi thì sang cách kế ngay (không đợi hết cả vòng). Cách có tác dụng được nhớ và thử TRƯỚC ở lần sau.
	-- Trả về true nếu check() thành true.
	local function clickUntil(pred, check, maxWait)
		local order = {}
		if Boat.clickMode then order[1] = Boat.clickMode end
		for _, m in ipairs(MODE_ORDER) do
			if m ~= Boat.clickMode then order[#order + 1] = m end
		end
		for _, mode in ipairs(order) do
			if Boat.stop then return false end
			if check() then return true end
			local o = findOption(pred)
			if not o then return check() end -- nút biến mất: màn hình đã đổi (hoặc hộp thoại đã đóng)
			if not (mode == "signal" and not hasSignalClick()) then
				clickButton(o.obj, mode)
				local t = 0
				while t < (maxWait or 1.6) do
					task.wait(0.1)
					t = t + 0.1
					if check() then
						Boat.clickMode = mode
						return true
					end
				end
			end
		end
		return false
	end

	local function seatOf(car)
		return car and (car:FindFirstChild("DSeat") or car:FindFirstChildWhichIsA("VehicleSeat", true))
	end

	function Boat.findCar()
		local cars = workspace:FindFirstChild("Cars")
		local car = cars and cars:FindFirstChild(tostring(LocalPlayer.UserId))
		if car and seatOf(car) then return car end
		return nil
	end

	-- ---------- NPC bán xe ----------
	local mcache = { t = -1e9, list = {} }
	local function merchants()
		local age = os.clock() - mcache.t
		if age > 20 or (#mcache.list == 0 and age > 2) then
			local list = {}
			local world = workspace:FindFirstChild("World")
			local folder = (world and world:FindFirstChild("Islands")) or workspace
			for _, d in ipairs(folder:GetDescendants()) do
				if d:IsA("Model") and string.find(string.lower(d.Name), "car_merchant", 1, true) then list[#list + 1] = d end
			end
			mcache.t, mcache.list = os.clock(), list
		end
		return mcache.list
	end

	-- NPC bán xe GẦN NHẤT quanh chỗ đang đứng (chỉ thấy NPC đã được game tải). Trả về prompt, vị trí, model.
	function Boat.merchant()
		local _, root = Nav.parts()
		local from = root and root.Position or Vector3.new(0, 0, 0)
		local bestM, bestPos, bestD = nil, nil, huge
		for _, m in ipairs(merchants()) do
			if m.Parent then
				local part = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
				if part then
					local dd = (part.Position - from).Magnitude
					if dd < bestD then bestM, bestPos, bestD = m, part.Position, dd end
				end
			end
		end
		local prompt = bestM and bestM:FindFirstChildWhichIsA("ProximityPrompt", true)
		return prompt, bestPos, bestM
	end

	local function openMerchant()
		if isDialogueOpen() then return true end
		return Travel.openPrompt(function() return (Boat.merchant()) end, { attempts = 8 })
	end

	-- Gọi xe ở NPC (phải đứng gần NPC): mở hộp thoại -> bấm "Gọi xe" -> bấm xe đã chọn -> đợi xe MỚI xuất hiện.
	-- Mỗi bước kiểm tra màn hình có đổi thật không rồi mới sang bước sau. Trả về true, hoặc false + lý do.
	function Boat.summon(choice)
		local opt = Boat.OPTIONS[choice] or Boat.OPTIONS[1]
		local oldCar = Boat.findCar()
		local oldSeat = seatOf(oldCar)
		local oldPos = oldSeat and oldSeat.Position

		-- xe MỚI: model khác lúc trước, hoặc cùng model nhưng đã được đưa tới chỗ khác
		local function fresh()
			local car = Boat.findCar()
			if not car then return nil end
			if car ~= oldCar then return car end
			local seat = seatOf(car)
			if seat and oldPos and flatDist(seat.Position, oldPos) > 25 then return car end
			return nil
		end

		local function screen()
			local list = listOptions()
			for _, o in ipairs(list) do
				if isCarList(o.text) then return "list" end
			end
			for _, o in ipairs(list) do
				if isCall(o.text) then return "menu" end
			end
			if #list > 0 then return "other" end
			return "empty"
		end

		local deadline = os.clock() + 55
		local emptySince = nil
		local lastErr = "không mở được hộp thoại NPC bán xe"
		while os.clock() < deadline and not Boat.stop do
			if fresh() then
				if isDialogueOpen() then pcall(closeDialogue) end
				return true
			end

			if not isDialogueOpen() then
				if not openMerchant() then return false, lastErr end
				emptySince = nil
			end

			local sc = screen()
			if sc == "menu" then
				emptySince = nil
				status("Gọi xe: bấm \"Gọi xe\"...")
				clickUntil(isCall, function() return screen() == "list" or fresh() ~= nil end)
			elseif sc == "list" then
				emptySince = nil
				status("Gọi xe: chọn " .. opt.name .. "...")
				local done = clickUntil(opt.pred, function() return fresh() ~= nil or not isDialogueOpen() end, 2.2)
				if done then
					local t = 0
					while t < 6 and not fresh() do
						task.wait(0.2)
						t = t + 0.2
					end
				end
				lastErr = "đã chọn " .. opt.name .. " nhưng xe không xuất hiện"
			elseif sc == "other" then
				emptySince = nil
				clickUntil(isFirstOther, function() return screen() ~= "other" end)
				lastErr = "không bấm được nút \"Gọi xe\""
			else
				-- chưa có nút nào (hộp thoại đang hiện chữ). Quá lâu mà vẫn trống thì đóng đi mở lại
				emptySince = emptySince or os.clock()
				if os.clock() - emptySince > 6 then
					pcall(closeDialogue)
					emptySince = nil
				else
					task.wait(0.25)
				end
			end
		end
		if isDialogueOpen() then pcall(closeDialogue) end
		return false, lastErr
	end

	-- Có xe ngay cạnh thì dùng, chưa có thì đi bộ tới NPC bán xe gần nhất rồi gọi ra.
	function Boat.ensureCar(choice)
		local hum, root = Nav.parts()
		if not root then return nil, "không thấy nhân vật" end

		local car = Boat.findCar()
		if car and not Boat.badCar[car] then
			local seat = seatOf(car)
			if seat and (hum.SeatPart == seat or flatDist(seat.Position, root.Position) <= 40) then return car end
		end

		status("Tìm NPC bán xe gần nhất...")
		local _, mpos = Boat.merchant()
		local waited = 0
		while not mpos and waited < 6 do
			-- NPC chưa được game tải: yêu cầu tải khu vực quanh nhân vật rồi đợi
			if waited == 0 then pcall(requestStream, root.Position, 2) end
			task.wait(0.5)
			waited = waited + 0.5
			_, mpos = Boat.merchant()
		end
		if not mpos then return nil, "không thấy NPC bán xe quanh đây" end

		if flatDist(root.Position, mpos) > 12 then
			status("Đi bộ tới NPC bán xe...")
			if not Nav.walkTo(mpos, { stop = 7, timeout = 90 }) then return nil, "không đi bộ tới được NPC bán xe" end
		end
		local ok, err = Boat.summon(choice)
		if not ok then return nil, err or "gọi xe không thành công" end
		return Boat.findCar()
	end

	-- Lên ghế lái. Trả về true, hoặc false + lý do.
	function Boat.board(car)
		local seat = seatOf(car)
		if not seat then return false, "xe không có ghế lái" end
		status("Lên xe...")
		-- xe vừa xuất hiện còn đang rơi / trượt: đợi đứng yên rồi mới bước lên
		local settle = 0
		while settle < 3 and seat.AssemblyLinearVelocity.Magnitude > 2 do
			task.wait(0.2)
			settle = settle + 0.2
		end
		for _ = 1, 4 do
			local hum, root = Nav.parts()
			if not hum then return false, "không thấy nhân vật" end
			if hum.SeatPart == seat then return true end
			if (root.Position - seat.Position).Magnitude > 8 then
				Nav.walkTo(seat.Position, { stop = 5, timeout = 40 })
			end
			local prompt = seat:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt and fireproximityprompt then
				pcall(fireproximityprompt, prompt)
				task.wait(0.8)
			end
			hum, root = Nav.parts()
			if not hum then return false, "không thấy nhân vật" end
			if hum.SeatPart ~= seat then
				-- chạm vào ghế để ngồi: đặt nhân vật ngay trên ghế (chỉ khi đang ở gần, không dịch chuyển xa)
				if (root.Position - seat.Position).Magnitude <= 60 then
					setRootCFrame(root, seat.CFrame + Vector3.new(0, 2.5, 0))
					task.wait(0.8)
				end
			end
			hum = Nav.parts()
			if hum and hum.SeatPart == seat then return true end
		end
		return false, "không lên được xe"
	end

	-- Nhảy khỏi ghế
	function Boat.exit()
		local hum = Nav.parts()
		if not hum then return end
		for _ = 1, 4 do
			hum.Jump = true
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
			task.wait(0.5)
			if hum.SeatPart == nil then return end
		end
	end

	-- ---------- đảo ----------
	-- Đảo nào (chỉ số trong Islands) gần pos nhất
	function Boat.nearestIsland(pos)
		local best, bd = 1, huge
		for k, isl in ipairs(Islands) do
			local d = sqrt((isl[2].X - pos.X) ^ 2 + (isl[2].Z - pos.Z) ^ 2)
			if d < bd then best, bd = k, d end
		end
		return best, bd
	end

	-- Danh sách part "đất" của đảo idx (có va chạm, đủ lớn, nằm ngang mặt đảo, không phải vùng boss). Nhớ lại 25 giây.
	local pcache = {}
	local function islandParts(idx)
		local c = pcache[idx]
		if c and os.clock() - c.t < 25 and #c.list > 0 then return c.list end
		local list = {}
		local folder = findIslandFolder(idx)
		if folder then
			local refY = Islands[idx][2].Y
			local regions = folder:FindFirstChild("BossRegions")
			local n = 0
			for _, d in ipairs(folder:GetDescendants()) do
				if d:IsA("BasePart") and d.CanCollide and d.Transparency < 0.9 and d.Size.Magnitude > 8
					and d.Position.Y > refY - 12 and d.Position.Y < refY + 40 and not (regions and d:IsDescendantOf(regions)) then
					list[#list + 1] = d
				end
				n = n + 1
				if n % 500 == 0 then task.wait() end
			end
		end
		pcache[idx] = { t = os.clock(), list = list }
		return list
	end

	-- Điểm trên "part" gần xe nhất của đảo idx. Trả về điểm, khoảng cách ngang (nil nếu chưa có part nào được tải).
	function Boat.nearestPart(idx, from)
		local best, bd = nil, huge
		for _, d in ipairs(islandParts(idx)) do
			if d.Parent then
				local p = d.Position
				-- loại nhanh các part chắc chắn xa hơn kết quả hiện có (đỡ gọi GetClosestPointOnSurface)
				local rough = sqrt((p.X - from.X) ^ 2 + (p.Z - from.Z) ^ 2) - d.Size.Magnitude * 0.5
				if rough < bd then
					local pt = p
					local okc, cp = pcall(function() return d:GetClosestPointOnSurface(from) end)
					if okc and cp then pt = cp end
					local dd = sqrt((pt.X - from.X) ^ 2 + (pt.Z - from.Z) ^ 2)
					if dd < bd then best, bd = pt, dd end
				end
			end
		end
		if not best then return nil end
		return best, bd
	end

	-- Hình tròn ước lượng của từng đảo, dùng để lập lộ trình đi vòng
	function Boat.circles()
		local out = {}
		for i, it in ipairs(Islands) do
			out[#out + 1] = { x = it[2].X, z = it[2].Z, r = Boat.ISLAND_R + Boat.ISLAND_PAD, id = i }
		end
		return out
	end

	-- ---------- lái xe ----------
	-- Lái xe (đang ngồi ghế lái) tới sát bờ đảo idx. Trả về true, điểm bờ (Vector3 hoặc nil); hoặc false, lý do.
	-- opts.timeout: tối đa chừng này giây.
	function Boat.drive(idx, opts)
		opts = opts or {}
		local timeout = opts.timeout or Config.BOAT_TIMEOUT
		local car = Boat.findCar()
		local seat = seatOf(car)
		local hum = Nav.parts()
		if not (seat and hum and hum.SeatPart == seat) then return false, "chưa ngồi trên ghế lái" end

		local isl = Islands[idx][2]
		local gx0, gz0 = isl.X, isl.Z
		local R = Boat.ISLAND_R

		-- bề ngang thân xe (nửa bề ngang + đệm)
		local w = 8
		pcall(function()
			local e = car:GetExtentsSize()
			w = clamp(math.min(e.X, e.Z) / 2 + 1.5, 4, 12)
		end)

		-- tia nhìn trước: bỏ qua xe, nhân vật và các vùng không phải vật cản thật; tới gần đảo đích thì bỏ qua luôn đảo đích
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		pcall(function() params.RespectCanCollide = true end)
		local ignoreBase = { car }
		do
			local ch = LocalPlayer.Character
			if ch then ignoreBase[#ignoreBase + 1] = ch end
			for i in ipairs(Islands) do
				local f = findIslandFolder(i)
				if f then
					local z1, z2 = f:FindFirstChild("Zones"), f:FindFirstChild("BossRegions")
					if z1 then ignoreBase[#ignoreBase + 1] = z1 end
					if z2 then ignoreBase[#ignoreBase + 1] = z2 end
				end
			end
		end
		local function setFilter(withGoal)
			local list = {}
			for _, v in ipairs(ignoreBase) do list[#list + 1] = v end
			if withGoal then
				local gf = findIslandFolder(idx)
				if gf then list[#list + 1] = gf end
			end
			params.FilterDescendantsInstances = list
		end
		setFilter(false)

		-- hai độ cao tia: sát đáy thân xe (bắt vật cản thấp như bãi cạn, đá ngầm) và ngang ghế lái
		local lowY, highY = seat.Position.Y, seat.Position.Y
		local function refreshHeights()
			local pos = seat.Position
			local okb, bottom = pcall(function()
				local cf, size = car:GetBoundingBox()
				return cf.Position.Y - size.Y / 2
			end)
			local lo = (okb and bottom) and (bottom + 1.2) or (pos.Y - 1.5)
			lo = clamp(lo, pos.Y - 4, pos.Y - 0.5) -- không để tia xuống quá sâu (đáy biển) hay lên quá cao
			lowY, highY = lo, pos.Y + 1
			if highY - lowY < 1.5 then highY = lowY end
		end
		refreshHeights()

		local function castAt(y, ox, oz, dx, dz, len)
			local res = workspace:Raycast(Vector3.new(ox, y, oz), Vector3.new(dx * len, 0, dz * len), params)
			if res then return res.Distance end
			return len
		end
		local function cast(ox, oz, dx, dz, len)
			local d = castAt(lowY, ox, oz, dx, dz, len)
			if highY ~= lowY and d > 1 then
				local d2 = castAt(highY, ox, oz, dx, dz, len)
				if d2 < d then d = d2 end
			end
			return d
		end

		-- lái: đặt ga / lái mỗi khung hình
		local S = Core.new()
		local ctl = { thr = 0, steer = 0 }
		local function apply()
			seat.ThrottleFloat = ctl.thr
			seat.SteerFloat = ctl.steer
		end
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Last.Value, function()
			if seat.Parent then pcall(apply) end
		end)

		-- lộ trình: các điểm đi vòng những đảo chắn đường, điểm cuối = điểm áp sát ngoài đảo đích
		local circles = Boat.circles()
		local function buildRoute(fx, fz, variant)
			local pts = Plan.route(fx, fz, gx0, gz0, circles, {
				skip = { [idx] = true },
				pref = variant and ((variant % 2 == 0) and 1 or -1) or nil,
				bonus = variant and 400 or 0,
			})
			local lx, lz = fx, fz
			if #pts > 0 then lx, lz = pts[#pts].x, pts[#pts].z end
			local ux, uz = lx - gx0, lz - gz0
			local m = sqrt(ux * ux + uz * uz)
			if m < 1 then ux, uz, m = 1, 0, 1 end
			ux, uz = ux / m, uz / m
			pts[#pts + 1] = { x = gx0 + ux * (R * 1.35 + 120), z = gz0 + uz * (R * 1.35 + 120) }
			return pts
		end

		local p0 = seat.Position
		local wps = buildRoute(p0.X, p0.Z, nil)
		local wpi, variant, lastLost = 1, 0, 0
		local lastSkipT, wpBest, wpBestT = -1e9, 1e18, 0
		local shore, lastShoreT = nil, -1e9
		local approach, stuckAtApproach = false, 0
		local approachD = R * 1.35 + 330
		local reached, why = false, nil
		local nextStream, nextStatus, nextHeights = 0, 0, 0
		local t0 = os.clock()
		local info = ""

		local okLoop, errLoop = pcall(function()
			while true do
				task.wait(0.05)
				local t = os.clock() - t0
				if Boat.stop then why = "đã dừng" return end
				if t > timeout then why = "lái quá thời gian" return end
				local h = Nav.parts()
				if not h then why = "mất nhân vật" return end
				if h.SeatPart ~= seat or not seat.Parent then why = "bị văng khỏi xe" return end

				local pos = seat.Position
				local px, pz = pos.X, pos.Z
				if os.clock() >= nextHeights then
					nextHeights = os.clock() + 2
					refreshHeights()
				end
				local lv = seat.CFrame.LookVector

				local dgc = sqrt((px - gx0) ^ 2 + (pz - gz0) ^ 2)
				local was = approach
				approach = dgc < approachD
				if approach ~= was then
					setFilter(approach)
					if approach then stuckAtApproach = S.stuckN end
				end

				-- chọn đích tạm
				local gx, gz, reach, isShore
				if wpi <= #wps and not approach then
					-- bỏ qua điểm lộ trình khi thấy rõ điểm xa hơn (đường thoáng) hoặc điểm hiện tại mãi không tới được
					if os.clock() - lastSkipT >= 1 then
						lastSkipT = os.clock()
						for j = #wps, wpi + 1, -1 do
							local dd = sqrt((wps[j].x - px) ^ 2 + (wps[j].z - pz) ^ 2)
							if dd > 1 and dd < 500 then
								local ux, uz = (wps[j].x - px) / dd, (wps[j].z - pz) / dd
								if Core.corridor(cast, px, pz, ux, uz, dd, w) >= dd - 0.5 then
									wpi = j
									wpBest, wpBestT = 1e18, t
									break
								end
							end
						end
					end
					local dcur = sqrt((wps[wpi].x - px) ^ 2 + (wps[wpi].z - pz) ^ 2)
					if dcur < wpBest - 30 then
						wpBest, wpBestT = dcur, t
					elseif t - wpBestT > 30 and wpi < #wps then
						wpi = wpi + 1
						wpBest, wpBestT = 1e18, t
					end
					gx, gz, reach, isShore = wps[wpi].x, wps[wpi].z, 80, false
				else
					-- đã tới điểm áp sát hoặc đang áp sát: nhắm điểm gần nhất của đảo đích
					if os.clock() - lastShoreT > 1 or not shore then
						lastShoreT = os.clock()
						local pt = Boat.nearestPart(idx, pos)
						if pt then shore = pt end
					end
					if shore then
						gx, gz, reach, isShore = shore.X, shore.Z, 18, true
					else
						gx, gz, reach, isShore = gx0, gz0, 30, true
					end
				end

				local dg = sqrt((gx - px) ^ 2 + (gz - pz) ^ 2)
				if dg <= reach then
					if isShore then
						reached = true
						return
					end
					wpi = wpi + 1
				end

				local thr, steer, inf = Core.step(S, t, px, pz, lv.X, lv.Z, gx, gz, cast, { look = 200, w = w, approach = approach })
				ctl.thr, ctl.steer, info = thr, steer, inf

				-- tới gần bờ mà kẹt (xe đã cập bờ, không nhích được nữa) thì coi như tới nơi
				if approach and S.stuckN - stuckAtApproach >= 2 then
					local near = shore and sqrt((shore.X - px) ^ 2 + (shore.Z - pz) ^ 2) or (dgc - R)
					if near < 60 then
						reached = true
						return
					end
				end

				-- quanh quẩn mãi (lạc đường): lập lại lộ trình từ chỗ hiện tại, đổi chiều đi vòng
				if S.lost > lastLost then
					lastLost = S.lost
					variant = variant + 1
					wps = buildRoute(px, pz, variant)
					wpi = 1
					wpBest, wpBestT = 1e18, t
				end

				-- tải sẵn khu vực đảo đích khi còn xa
				if os.clock() >= nextStream then
					nextStream = os.clock() + 6
					BossScan.busyUntil = os.clock() + 8
					task.spawn(requestStream, Vector3.new(gx0, pos.Y, gz0), 3)
				end

				if os.clock() >= nextStatus then
					nextStatus = os.clock() + 1.5
					status("Đang lái xe tới " .. Islands[idx][1] .. " (còn " .. floor(dgc) .. " stud) · " .. tostring(info))
				end
			end
		end)

		pcall(function() RunService:UnbindFromRenderStep(BIND) end)
		ctl.thr, ctl.steer = 0, 0
		pcall(apply)
		if not okLoop then return false, "lỗi khi lái: " .. tostring(errLoop) end
		if reached then return true, shore end
		return false, why or "không rõ"
	end

	-- Nhảy từ xe lên part gần nhất: nhảy + đi về phía điểm đó, thử vài lần tới khi đứng được trên đảo.
	function Boat.hopOnto(point)
		for _ = 1, 6 do
			local hum = Nav.parts()
			if not hum then return false end
			hum.Jump = true
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
			hum:MoveTo(point + Vector3.new(0, 1, 0))
			for _ = 1, 9 do
				task.wait(0.1)
				local h2, root = Nav.parts()
				if not h2 then return false end
				local flat = sqrt((root.Position.X - point.X) ^ 2 + (root.Position.Z - point.Z) ^ 2)
				if h2.SeatPart == nil and flat < 10 and root.Position.Y > point.Y - 4 and h2.FloorMaterial ~= Enum.Material.Air then
					return true
				end
			end
		end
		return false
	end

	-- Đi tới targetPos (Vector3) bằng xe, targetPos nằm trên đảo thứ idx (mặc định đảo gần targetPos nhất):
	--   gần sẵn (cùng đảo) -> đi bộ luôn
	--   xa -> lấy / gọi xe ở NPC gần nhất -> lái né vật cản tới sát bờ đảo -> nhảy lên part gần nhất
	--   -> đi bộ tới toạ độ đã đặt sẵn của đảo (Islands[idx][2]) -> đi bộ nốt tới targetPos.
	-- Lỗi giữa chừng (không gọi được xe, không lên được xe, lái hỏng) thì thử lại tối đa Config.BOAT_RETRIES lần / Config.BOAT_TOTAL_TIMEOUT giây.
	-- Trả về true nếu cuối cùng đứng gần targetPos, kèm lý do nếu có bước lỗi. Không dùng dịch chuyển.
	function Boat.go(targetPos, choice, idx)
		local _, root = Nav.parts()
		if not root then return false, "không thấy nhân vật" end
		idx = idx or Boat.nearestIsland(targetPos)
		local isl = Islands[idx]
		local function flatTo(p)
			local _, r = Nav.parts()
			if not r then return huge end
			return flatDist(r.Position, p)
		end

		-- cùng đảo (gần toạ độ đảo hoặc gần đích): đi bộ luôn
		if flatTo(targetPos) < 120 then
			return Nav.walkTo(targetPos, { stop = 4, timeout = 90 })
		end
		if Boat.nearestIsland(root.Position) == idx and flatTo(isl[2]) < 400 then
			if Nav.walkTo(isl[2], { stop = 6, timeout = 90 }) then
				return Nav.walkTo(targetPos, { stop = 4, timeout = 90 })
			end
		end

		local t0 = os.clock()
		local totalMax = Config.BOAT_TOTAL_TIMEOUT or 700
		local retries = Config.BOAT_RETRIES or 3
		local arrived, shore, why = false, nil, nil
		for attempt = 1, retries do
			if Boat.stop or os.clock() - t0 > totalMax then break end
			local car, err = Boat.ensureCar(choice)
			if not car then
				why = err
				if attempt >= 2 then break end
				task.wait(1.5)
			else
				local seated, berr = Boat.board(car)
				if not seated then
					Boat.badCar[car] = true
					why = berr or "không lên được xe"
				else
					local left = totalMax - (os.clock() - t0)
					local ok, res = Boat.drive(idx, { timeout = clamp(left, 60, Config.BOAT_TIMEOUT) })
					if ok then
						arrived, shore = true, res -- res = điểm bờ (có thể nil)
						break
					end
					why = "lái xe: " .. tostring(res)
				end
			end
		end

		-- lái chưa tới nơi nhưng xe đã nằm sát bờ đảo đích thì vẫn thử nhảy lên
		if not arrived and not Boat.stop then
			local hum, r = Nav.parts()
			if hum and r and hum.SeatPart ~= nil then
				local pt, dd = Boat.nearestPart(idx, r.Position)
				if pt and dd <= 80 then
					arrived, shore = true, pt
				end
			end
		end
		if not arrived then return false, why end

		status("Nhảy lên đảo...")
		local _, r1 = Nav.parts()
		local point = shore or (r1 and (Boat.nearestPart(idx, r1.Position)))
		Boat.exit()
		local hopped = false
		if point then hopped = Boat.hopOnto(point) end
		if not hopped then
			-- thử lại với điểm gần nhất tính theo chỗ đang đứng
			local _, r2 = Nav.parts()
			local p2 = r2 and (Boat.nearestPart(idx, r2.Position))
			if p2 then hopped = Boat.hopOnto(p2) end
		end

		status("Đi bộ tới " .. isl[1] .. "...")
		local walked = Nav.walkTo(isl[2], { stop = 6, timeout = 90 })
		if walked then
			walked = Nav.walkTo(targetPos, { stop = 4, timeout = 90 })
		end
		local fail
		if not hopped then fail = "chưa nhảy lên được đảo" end
		return walked, fail
	end

	return Boat
end)()

-- Trạng thái đi xe hiện ở dòng "Auto Câu Boss: ..." của tab Boss Zone khi Auto Câu Boss đang bật
Travel.Boat.onStatus = function(text)
	if autoBossOn and autoBossState ~= "" then autoBossState = text end
end

-- ==================================================
-- AUTO CÂU BOSS (công tắc ở tab Farm)
-- Khi có boss zone đang spawn: đi XE của game tới đảo đó (tới NPC bán xe gần nhất, gọi xe, lái né vật cản, nhảy lên part gần nhất, đi bộ),
-- tìm điểm đứng được TRÊN ĐẢO gần vùng boss nhất (bắn tia xuống đất theo các vòng tròn lớn dần quanh vùng boss),
-- quay mặt về phía boss rồi bật Auto Farm để ném cần. Không dùng dịch chuyển xa (game reset nhân vật khi tp quá xa).
-- TRÌNH TỰ (Auto Farm, Auto Câu Boss, Auto Sell chạy lần lượt, không dịch chuyển chồng nhau nhờ khoá dịch chuyển):
--   Có boss : tắt Auto Farm -> đi xe tới đảo boss -> tới chỗ đứng gần boss -> xoay mặt + camera về boss -> bật Auto Farm ném cần
--             -> KHOÁ vị trí và hướng nhìn (shift lock hay xoay lệch thì tự chỉnh lại mỗi giây; Anti TP chặn game kéo về chỗ cũ)
--   Túi đầy : Auto Câu Boss đứng yên, Auto Sell tắt câu -> đi bộ bán (bán lại nếu còn đầy) -> về đúng chỗ đang đứng -> nhảy 1 cái -> bật lại câu
--   Boss hết: (liên tục ~8 giây) tắt câu -> đợi BOSS_RETURN_DELAY giây -> đi xe về chỗ farm cũ -> nhảy 1 cái
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
			-- mặc định đi bằng xe: tới NPC bán xe gần nhất chỗ đang đứng, gọi xe, lái tới boss (không dùng dịch chuyển)
			autoBossState = "Đang đi xe tới boss " .. island[1] .. "..."
			local bOk, bWhy = Travel.Boat.go(standPos, Config.BOAT_CHOICE, i)
			if not bOk then
				pcall(notifyOwnFish, "Đi xe", "lỗi", bWhy or "không tới được boss", true, 5)
				return
			end
			local _, r0 = Travel.Nav.parts()
			if r0 and (r0.Position - goal.Position).Magnitude < 30 then FastTeleport(goal) end -- chỉnh chỗ đứng + hướng (dịch rất ngắn)
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
								if originCF then
									autoBossState = "Đi xe về chỗ cũ..."
									pcall(Travel.Boat.go, originCF.Position, Config.BOAT_CHOICE)
									local _, r1 = Travel.Nav.parts()
									if r1 and (r1.Position - originCF.Position).Magnitude < 30 then FastTeleport(originCF) end
								end
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
-- NHẬP TẤT CẢ CODE (Redeem)
-- Ô nhập code của game nằm trong menu Settings: PlayerGui.Settings.Frame.List.CodeRedeem
--   (Prompt.TextBox = ô gõ code, RedeemButton.Button = nút Redeem).
-- Với mỗi code trong Config.REDEEM_CODES: điền vào ô rồi bấm Redeem, nghỉ Config.REDEEM_DELAY giây rồi sang code kế.
-- Máy có firesignal/getconnections thì bấm ngầm, không cần mở menu; không có thì tự mở menu Settings, kéo tới ô nhập code,
-- bấm theo toạ độ, xong đóng menu lại.
-- ==================================================
local redeeming = false

local function findCodeRedeem()
	local settingsGui = PlayerGui:FindFirstChild("Settings")
	local frame = settingsGui and settingsGui:FindFirstChild("Frame")
	local list = frame and frame:FindFirstChild("List")
	local row = list and list:FindFirstChild("CodeRedeem")
	local prompt = row and row:FindFirstChild("Prompt")
	local box = prompt and prompt:FindFirstChild("TextBox")
	local redeemFrame = row and row:FindFirstChild("RedeemButton")
	local btn = redeemFrame and redeemFrame:FindFirstChild("Button")
	if box and box:IsA("TextBox") and btn and btn:IsA("GuiButton") then
		return box, btn, list, row
	end
	return nil
end

-- setLabel(text): cập nhật chữ trên nút để thấy tiến độ. Trả về số code đã nhập.
local function redeemAllCodes(setLabel)
	if redeeming then return 0 end
	redeeming = true
	local sent = 0
	local total = #Config.REDEEM_CODES

	local ok, err = pcall(function()
		local openedByUs = false
		if not hasSignalClick() then
			openedByUs = openGameSettingsMenu()
			if not openedByUs then
				pcall(notifyOwnFish, "Nhập Code", "lỗi", "không mở được menu Settings", true)
				return
			end
		end

		for idx, code in ipairs(Config.REDEEM_CODES) do
			local box, btn, list, row = findCodeRedeem()
			if not box then
				pcall(notifyOwnFish, "Nhập Code", "lỗi", "không thấy ô nhập code", true)
				break
			end
			setLabel("Đang nhập code " .. idx .. "/" .. total .. ": " .. code)

			-- kéo danh sách Settings tới chỗ nhập code (chỉ cần khi bấm bằng toạ độ)
			if not hasSignalClick() and list and list:IsA("ScrollingFrame") and row then
				pcall(function()
					local y = row.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y
					list.CanvasPosition = Vector2.new(0, math.max(0, y))
				end)
				task.wait(0.2)
			end

			box.Text = code
			task.wait(0.2)

			local clicked = false
			if hasSignalClick() then clicked = signalClick(btn) end
			if not clicked then clicked = clickButton(btn, "auto") end
			sent += 1
			task.wait(Config.REDEEM_DELAY)
		end

		if openedByUs then closeGameSettingsMenu() end
	end)

	redeeming = false
	if sent > 0 then
		pcall(notifyOwnFish, "Nhập Code", "xong", "đã nhập " .. sent .. "/" .. total .. " code", true)
	end
	return sent
end

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

CreateSection(SettingTab, "Code")
local REDEEM_BUTTON_TEXT = "Nhập tất cả Code trong game"
local redeemButton
redeemButton = CreateButton(SettingTab, REDEEM_BUTTON_TEXT, function()
	if redeeming then return end
	task.spawn(function()
		redeemAllCodes(function(text) redeemButton.Text = text end)
		redeemButton.Text = REDEEM_BUTTON_TEXT
	end)
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
