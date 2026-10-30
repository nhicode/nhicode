--[[ CHAT TRANSLATOR v9 (3 thanh, gõ chữ terminal; tin của bạn: Google + dùng bản dịch có sẵn trên Firebase) for Roblox (Delta) ]]

local Players, HttpService, TextChatService, UIS, RS =
    game:GetService("Players"), game:GetService("HttpService"), game:GetService("TextChatService"),
    game:GetService("UserInputService"), game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------------- Cấu hình
-- Danh sách ngôn ngữ, dạng  mã|Tên;
local LANGS, NAMES, CANON = {}, {}, {}
for c, n in ([[
vi|Tiếng Việt; en|Tiếng Anh (English); zh-CN|Tiếng Trung (Giản thể); zh-TW|Tiếng Trung (Phồn thể);
ja|Tiếng Nhật; ko|Tiếng Hàn; th|Tiếng Thái; id|Tiếng Indonesia; tl|Tiếng Philippines; ms|Tiếng Mã Lai;
ru|Tiếng Nga; es|Tiếng Tây Ban Nha; pt|Tiếng Bồ Đào Nha; fr|Tiếng Pháp; de|Tiếng Đức; it|Tiếng Ý;
tr|Tiếng Thổ Nhĩ Kỳ; ar|Tiếng Ả Rập; pl|Tiếng Ba Lan; uk|Tiếng Ukraina; hi|Tiếng Hindi;
af|Tiếng Afrikaans; sq|Tiếng Albania; am|Tiếng Amharic; hy|Tiếng Armenia; as|Tiếng Assam; ay|Tiếng Aymara;
az|Tiếng Azerbaijan; bm|Tiếng Bambara; eu|Tiếng Basque; be|Tiếng Belarus; bn|Tiếng Bengal; bho|Tiếng Bhojpuri;
bs|Tiếng Bosnia; bg|Tiếng Bulgaria; ca|Tiếng Catalan; ceb|Tiếng Cebuano; ny|Tiếng Chichewa; co|Tiếng Corsica;
hr|Tiếng Croatia; cs|Tiếng Séc; da|Tiếng Đan Mạch; dv|Tiếng Dhivehi; doi|Tiếng Dogri; nl|Tiếng Hà Lan;
eo|Tiếng Esperanto; et|Tiếng Estonia; ee|Tiếng Ewe; fi|Tiếng Phần Lan; fy|Tiếng Frisia; gl|Tiếng Galicia;
ka|Tiếng Georgia; el|Tiếng Hy Lạp; gn|Tiếng Guarani; gu|Tiếng Gujarati; ht|Tiếng Creole Haiti; cnh|Tiếng Hakha Chin;
ha|Tiếng Hausa; haw|Tiếng Hawaii; iw|Tiếng Do Thái; hmn|Tiếng Hmong; hu|Tiếng Hungary; hrx|Tiếng Hunsrik;
iba|Tiếng Iban; is|Tiếng Iceland; ig|Tiếng Igbo; ilo|Tiếng Ilocano; ga|Tiếng Ireland; jw|Tiếng Java;
kn|Tiếng Kannada; kk|Tiếng Kazakh; km|Tiếng Khmer; rw|Tiếng Kinyarwanda; gom|Tiếng Konkani; kri|Tiếng Krio;
ku|Tiếng Kurd (Kurmanji); ckb|Tiếng Kurd (Sorani); ky|Tiếng Kyrgyz; lo|Tiếng Lào; la|Tiếng Latin; lv|Tiếng Latvia;
ln|Tiếng Lingala; lt|Tiếng Litva; lg|Tiếng Luganda; lb|Tiếng Luxembourg; mk|Tiếng Macedonia; mai|Tiếng Maithili;
mg|Tiếng Malagasy; ml|Tiếng Malayalam; mt|Tiếng Malta; mi|Tiếng Maori; mr|Tiếng Marathi; mni-Mtei|Tiếng Meiteilon (Manipuri);
lus|Tiếng Mizo; mn|Tiếng Mông Cổ; my|Tiếng Myanmar (Miến Điện); ne|Tiếng Nepal; no|Tiếng Na Uy; or|Tiếng Odia;
om|Tiếng Oromo; ps|Tiếng Pashto; fa|Tiếng Ba Tư; pa|Tiếng Punjab; qu|Tiếng Quechua; ro|Tiếng Romania;
sm|Tiếng Samoa; sa|Tiếng Phạn; gd|Tiếng Gaelic Scotland; nso|Tiếng Sepedi; sr|Tiếng Serbia; st|Tiếng Sesotho;
sn|Tiếng Shona; sd|Tiếng Sindhi; si|Tiếng Sinhala; sk|Tiếng Slovak; sl|Tiếng Slovenia; so|Tiếng Somali;
su|Tiếng Sunda; sw|Tiếng Swahili; sv|Tiếng Thụy Điển; tg|Tiếng Tajik; ta|Tiếng Tamil; tt|Tiếng Tatar;
te|Tiếng Telugu; ti|Tiếng Tigrinya; ts|Tiếng Tsonga; tk|Tiếng Turkmen; ak|Tiếng Twi; ur|Tiếng Urdu;
ug|Tiếng Uyghur; uz|Tiếng Uzbek; cy|Tiếng Wales; xh|Tiếng Xhosa; yi|Tiếng Yiddish; yo|Tiếng Yoruba; zu|Tiếng Zulu;
]]):gmatch("([^|;]+)|([^;]+)") do
    c, n = c:match("^%s*(.-)%s*$"), n:match("^%s*(.-)%s*$")
    LANGS[#LANGS + 1] = {n, c}
    NAMES[c], CANON[c:lower()] = n, c
end

local MAX_LOG, MAX_CACHE = 20, 1000

-- FIREBASE Realtime Database (chỉ ĐỌC): tin của bạn vẫn dịch bằng Google Dịch và KHÔNG ghi gì lên Firebase,
-- nhưng nếu câu đó đã có sẵn bản dịch trên Firebase thì dùng luôn. Để trống FB_URL = tắt.
local FB_URL = "https://dichai-c1645-default-rtdb.firebaseio.com"


local S = {
    incoming = true, near = true, range = 50, showEN = true, pivot = true, abbr = true,
    showOrig = true, followChat = true, stripPunct = true, stripEnd = false, myLang = "vi", outLang = "en",
    autoSend = true, autoCopy = true, fx = true, noCaps = false, useDB = FB_URL ~= "",
}

---------------------------------------------------------------- Giao diện (màu hồng / đen, đổi được trong Settings)
local COLORS = {
    {"Hồng neon", 255, 60, 170}, {"Hồng đậm", 205, 20, 105}, {"Hồng pastel", 255, 150, 200},
    {"Hồng nhạt", 255, 200, 225}, {"Đen", 14, 14, 18}, {"Trắng", 255, 255, 255},
}
-- {tên, nền, viền/nhấn, màu chữ, độ trong}
local PRESETS = {
    {"Đen + chữ trắng", 5, 1, 6, 1},
    {"Đen + chữ hồng", 5, 1, 1, 2},
    {"Hồng + chữ đen", 3, 5, 5, 1},
    {"Hồng đậm + chữ đen", 2, 5, 5, 1},
}
local FILLS = {0.1, 0.3, 0.6, 0.85}
local THEME_FILE = "chat_translator_theme_v5.json"
local TH = {bg = 5, acc = 1, txt = 6, fill = 1, preset = 1}

local function col(i) local c = COLORS[i] or COLORS[1] return Color3.fromRGB(c[2], c[3], c[4]) end
local function hex(c)
    local function h(x) return math.floor(x * 255 + 0.5) end
    return string.format("#%02X%02X%02X", h(c.R), h(c.G), h(c.B))
end
local NEON, OBS, TXT, DIM, FILL_T
local function applyTheme()
    NEON, OBS, TXT = col(TH.acc), col(TH.bg), col(TH.txt)
    DIM, FILL_T = TXT:Lerp(OBS, 0.45), FILLS[TH.fill] or 0.3
end

---------------------------------------------------------------- Dọn bản cũ
local env = (getgenv and getgenv()) or _G
if env.__CT_CLEANUP then pcall(env.__CT_CLEANUP) end

local alive, conns, gui, cleanups = true, {}, nil, {}
local function track(c) conns[#conns + 1] = c return c end
local function onCleanup(f) cleanups[#cleanups + 1] = f end
env.__CT_CLEANUP = function()
    alive = false
    for _, f in ipairs(cleanups) do pcall(f) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if gui then pcall(function() gui:Destroy() end) end
    pcall(function() _G.AddLogToUI = nil end)
end

---------------------------------------------------------------- HTTP
local function getRequest()
    return (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
end

local function rawHttp(opts)
    local req = getRequest()
    if req then
        local ok, res = pcall(req, opts)
        if ok and res and res.Body and (res.StatusCode == 200 or res.Success) then return res.Body end
        return nil
    end
    if (opts.Method or "GET") == "GET" then
        local ok, body = pcall(function() return game:HttpGet(opts.Url) end)
        if ok then return body end
    end
end

-- Gọi mạng trong luồng riêng; quá 8 giây thì bỏ (chờ bằng coroutine)
local function httpReq(opts, timeout)
    local co = coroutine.running()
    local done, body, waiting = false, nil, false
    task.spawn(function()
        local ok, b = pcall(rawHttp, opts)
        if ok then body = b end
        if not done then
            done = true
            if waiting then task.spawn(co) end
        end
    end)
    if not done then
        waiting = true
        task.delay(timeout or 8, function() if not done then done = true task.spawn(co) end end)
        coroutine.yield()
    end
    return body
end

local function urlEncode(s)
    return (tostring(s):gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", string.byte(c)) end))
end
local function jsonDecode(s)
    local ok, d = pcall(function() return HttpService:JSONDecode(s) end)
    if ok and type(d) == "table" then return d end
end

-- lưu / tải cài đặt (toàn bộ bảng S)
local SETTINGS_FILE = "chat_translator_settings_v5.json"
local function saveSettings()
    pcall(function() if writefile then writefile(SETTINGS_FILE, HttpService:JSONEncode(S)) end end)
end
pcall(function()
    if isfile and readfile and isfile(SETTINGS_FILE) then
        local d = jsonDecode(readfile(SETTINGS_FILE))
        if d then for k, v in pairs(d) do if S[k] ~= nil and type(S[k]) == type(v) then S[k] = v end end end
    end
end)
S.range = math.clamp(S.range, 1, 5000)
if not NAMES[S.myLang] then S.myLang = "vi" end
if not NAMES[S.outLang] then S.outLang = "en" end
if FB_URL == "" then S.useDB = false end

-- tải theme đã lưu
pcall(function()
    if isfile and readfile and isfile(THEME_FILE) then
        local d = jsonDecode(readfile(THEME_FILE))
        if d then for k in pairs(TH) do if type(d[k]) == "number" then TH[k] = d[k] end end end
    end
end)
applyTheme()

---------------------------------------------------------------- Lọc / chuẩn hoá dấu câu & khoảng trắng
local function decodeEntities(s)
    s = s:gsub("&#(%d+);", function(n)
        n = tonumber(n)
        if n and n < 1114112 then return utf8.char(n) end
    end)
    return (s:gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end

local FULLWIDTH = {
    {"，", ", "}, {"。", ". "}, {"！", "! "}, {"？", "? "}, {"：", ": "},
    {"；", "; "}, {"（", " ("}, {"）", ") "}, {"、", ", "},
}
local CJK = "[\227-\233][\128-\191][\128-\191]"

local function clean(text, tl, isInput)
    if type(text) ~= "string" then return text end
    if not isInput then text = decodeEntities(text) end
    text = text:gsub("[\r\n\t]", " ")
    local isCJK = tl and (tl:find("^zh") or tl == "ja")
    if not isCJK then
        for _, p in ipairs(FULLWIDTH) do text = text:gsub(p[1], p[2]) end
    end
    text = text:gsub("%s+", " ")
    text = text:gsub("%s+([,%.!%?;%)])", "%1")
    text = text:gsub("(%()%s+", "%1")
    text = text:gsub(",%s*,+", ",")
    text = text:gsub("([,%.!%?;])%s+([,%.!%?;])", "%1%2")
    if isCJK then
        local prev
        repeat
            prev = text
            text = text:gsub("(" .. CJK .. ")%s+(" .. CJK .. ")", "%1%2")
        until text == prev
    else
        text = text:gsub("([,;!%?])(%a)", "%1 %2")
        text = text:gsub("([,;!%?])([\195-\198\225])", "%1 %2")
        text = text:gsub("(%l)%.(%u)", "%1. %2")
    end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Xoá dấu . , ở cuối/giữa câu (stripPunct) và ! ? ký hiệu cuối câu (stripEnd)
local TAIL = {"！", "？", "。", "，", "、", "…", "～", "；", "："}
local function stripP(s, tl)
    if type(s) ~= "string" or not (S.stripPunct or S.stripEnd) then return s end
    local orig = s
    if S.stripPunct then
        s = s:gsub("，", " "):gsub("、", " "):gsub("。", " "):gsub("…", " ")
        s = s:gsub(",", " ")
        s = s:gsub("%.(%s)", " %1"):gsub("%.+%s*$", "")
        s = clean(s, tl, true)
    end
    if S.stripEnd then
        local prev
        repeat
            prev = s
            s = s:gsub("[%s!%?%.,;:~]+$", "")
            for _, t in ipairs(TAIL) do
                if s:sub(-#t) == t then s = s:sub(1, -#t - 1) end
            end
        until s == prev
        s = s:gsub("^¡", ""):gsub("^¿", "")
    end
    return s == "" and orig or s
end

local function norm(s) return (tostring(s or ""):lower():gsub("[%p%s]", "")) end
local function lc(l) return ((l or ""):lower():gsub("%-.*$", "")) end
local function ulen(t) return utf8.len(t) or #t end

---------------------------------------------------------------- Chuẩn hoá mã ngôn ngữ
local ALIAS = {
    ["zh"] = "zh-CN", ["zh-cn"] = "zh-CN", ["zh-hans"] = "zh-CN", ["zh-sg"] = "zh-CN", ["zh-my"] = "zh-CN",
    ["zh-tw"] = "zh-TW", ["zh-hant"] = "zh-TW", ["zh-hk"] = "zh-TW", ["zh-mo"] = "zh-TW",
    ["he"] = "iw", ["jv"] = "jw", ["fil"] = "tl", ["nb"] = "no", ["nn"] = "no", ["in"] = "id",
    ["mni"] = "mni-Mtei", ["pt-br"] = "pt", ["pt-pt"] = "pt", ["sr-latn"] = "sr", ["sr-cyrl"] = "sr",
    ["ckb-iq"] = "ckb", ["kmr"] = "ku",
}
local function normLang(c)
    if type(c) ~= "string" or c == "" then return nil end
    c = c:lower():gsub("_", "-")
    if ALIAS[c] then return ALIAS[c] end
    if CANON[c] then return CANON[c] end
    local base = c:match("^(%a+)")
    return base and (ALIAS[base] or CANON[base]) or nil
end
local function sameLang(a, b)
    local x, y = normLang(a), normLang(b)
    return x ~= nil and x == y
end

---------------------------------------------------------------- Bộ nhớ đệm (cache 2 thế hệ)
local function newCache(max) return {cur = {}, old = {}, n = 0, on = 0, half = math.max(1, math.floor(max / 2))} end
local function cSet(c, k, v)
    if c.cur[k] == nil then c.n = c.n + 1 end
    c.cur[k] = v
    if c.old[k] ~= nil then c.old[k] = nil c.on = c.on - 1 end
    if c.n >= c.half then c.old, c.on, c.cur, c.n = c.cur, c.n, {}, 0 end
end
local function cGet(c, k)
    local v = c.cur[k]
    if v ~= nil then return v end
    v = c.old[k]
    if v ~= nil then
        c.old[k] = nil
        c.on = c.on - 1
        cSet(c, k, v)
        return v
    end
end

local TR  = env.__CT4_TR  or newCache(MAX_CACHE)
local DET = env.__CT4_DET or newCache(MAX_CACHE)
env.__CT4_TR, env.__CT4_DET = TR, DET
local CACHE_FILE = "chat_translator_cache_v4.json"
local dirty, savePending = false, false

local function loadCache()
    if not (isfile and readfile) then return end
    local ok, raw = pcall(function() if isfile(CACHE_FILE) then return readfile(CACHE_FILE) end end)
    local d = ok and raw and jsonDecode(raw)
    if not d then return end
    for k, v in pairs(d.tr or {}) do if type(v) == "table" and v.o then cSet(TR, k, v) end end
    for k, v in pairs(d.det or {}) do if type(v) == "string" then cSet(DET, k, v) end end
end
local function saveCache()
    if not (writefile and dirty) then return end
    dirty = false
    local tr, det = {}, {}
    for _, t in ipairs({TR.old, TR.cur}) do for k, v in pairs(t) do tr[k] = v end end
    for _, t in ipairs({DET.old, DET.cur}) do for k, v in pairs(t) do det[k] = v end end
    pcall(function() writefile(CACHE_FILE, HttpService:JSONEncode({tr = tr, det = det})) end)
end
if TR.n == 0 and TR.on == 0 then loadCache() end
onCleanup(saveCache)

-- gộp thay đổi, 30 giây sau mới ghi 1 lần
local function markDirty()
    dirty = true
    if savePending then return end
    savePending = true
    task.delay(30, function() savePending = false saveCache() end)
end

-- chữ thường hỗ trợ tiếng Việt / Latin mở rộng / Hy Lạp / Cyrillic
local function ulower(s)
    if not s:find("[\195-\209\225]") then return s:lower() end
    local ok, res = pcall(function()
        local t = {}
        for _, cp in utf8.codes(s) do
            if cp < 0x80 then
                if cp >= 65 and cp <= 90 then cp = cp + 32 end
            elseif cp == 0x130 then cp = 0x69
            elseif cp >= 0xC0 and cp <= 0xDE and cp ~= 0xD7 then cp = cp + 32
            elseif cp >= 0x100 and cp <= 0x137 and cp % 2 == 0 then cp = cp + 1
            elseif cp >= 0x139 and cp <= 0x148 and cp % 2 == 1 then cp = cp + 1
            elseif cp >= 0x14A and cp <= 0x177 and cp % 2 == 0 then cp = cp + 1
            elseif cp == 0x1A0 or cp == 0x1AF then cp = cp + 1
            elseif cp >= 0x1EA0 and cp <= 0x1EF8 and cp % 2 == 0 then cp = cp + 1
            elseif cp >= 0x391 and cp <= 0x3A9 then cp = cp + 32
            elseif cp >= 0x410 and cp <= 0x42F then cp = cp + 32
            elseif cp >= 0x400 and cp <= 0x40F then cp = cp + 80 end
            t[#t + 1] = utf8.char(cp)
        end
        return table.concat(t)
    end)
    return (ok and res) or s:lower()
end

local function ckey(text) return (ulower(clean(text or "", "en", true)):gsub("[%.,]+$", "")) end
local function mk(tl, style, key) return tl .. "|" .. (style or "") .. "|" .. key end

---------------------------------------------------------------- Phát hiện ngôn ngữ nguồn
local RANGES = {
    {0xAC00, 0xD7AF, "ko"}, {0x1100, 0x11FF, "ko"}, {0x3130, 0x318F, "ko"}, {0x3040, 0x30FF, "ja"},
    {0x4E00, 0x9FFF, "han"}, {0x3400, 0x4DBF, "han"},
    {0x0E00, 0x0E7F, "th"}, {0x0E80, 0x0EFF, "lo"}, {0x1780, 0x17FF, "km"}, {0x1000, 0x109F, "my"},
    {0x0370, 0x03FF, "el"}, {0x0590, 0x05FF, "iw"},
    {0x0A00, 0x0A7F, "pa"}, {0x0A80, 0x0AFF, "gu"}, {0x0B80, 0x0BFF, "ta"}, {0x0C00, 0x0C7F, "te"},
    {0x0C80, 0x0CFF, "kn"}, {0x0D00, 0x0D7F, "ml"}, {0x0D80, 0x0DFF, "si"}, {0x10A0, 0x10FF, "ka"},
    {0x0530, 0x058F, "hy"},
    {0x0600, 0x06FF, "~"}, {0x0750, 0x077F, "~"}, {0x0900, 0x097F, "~"}, {0x0980, 0x09FF, "~"},
    {0x0400, 0x04FF, "~"}, {0x1200, 0x137F, "~"},
    {0x1EA0, 0x1EF9, "vi"}, {0x01A0, 0x01A1, "vi"}, {0x01AF, 0x01B0, "vi"}, {0x0110, 0x0111, "vi"},
}

local function scriptLang(text)
    local cnt = {}
    pcall(function()
        for _, cp in utf8.codes(text) do
            if cp >= 0x01A0 or cp == 0x0110 or cp == 0x0111 then
                for _, r in ipairs(RANGES) do
                    if cp >= r[1] and cp <= r[2] then cnt[r[3]] = (cnt[r[3]] or 0) + 1 break end
                end
            end
        end
    end)
    if cnt.ja then return "ja", true end
    if cnt.ko then return "ko", true end
    local best, bc = nil, 0
    for k, v in pairs(cnt) do if v > bc then best, bc = k, v end end
    if not best then return nil end
    if best == "han" then return "zh", false end
    if best == "~" then return "~", false end
    return best, true
end

local function quickDetect(text)
    local lang, conf = scriptLang(text)
    if conf then return lang end
    return cGet(DET, ckey(text))
end

local PL = {}
local function rememberLang(uid, lang)
    local t = PL[uid]
    if not t then t = {n = 0} PL[uid] = t end
    t[lang] = (t[lang] or 0) + 1
    t.n = t.n + 1
end
local function hintFor(uid)
    local t = PL[uid]
    if not t or t.n < 3 then return nil end
    local best, bc
    for k, v in pairs(t) do if k ~= "n" and (not bc or v > bc) then best, bc = k, v end end
    if best and bc / t.n >= 0.7 then return best end
end

---------------------------------------------------------------- TỪ VIẾT TẮT / TIẾNG LÓNG
-- Cách thêm: mỗi mục dạng  viếttắt=nghĩa đầy đủ|  (nhớ có dấu | ở cuối, viết tắt viết thường)
local function T(s)
    local t = {}
    for k, v in s:gmatch("([^|=]+)=([^|]*)|") do
        k, v = k:match("^%s*(.-)%s*$"), v:match("^%s*(.-)%s*$")
        if k ~= "" then t[k] = v end
    end
    return t
end

local UNI = T([[
lol=haha|lmao=haha|lmfao=haha|rofl=haha|brb=be right back|gg=good game|wp=well played|
afk=away from keyboard|idk=I don't know|omg=oh my god|thx=thanks|thnx=thanks|tnx=thanks|
np=no problem|pls=please|plz=please|nvm=never mind|btw=by the way|jk=just kidding|
ez=easy|gl=good luck|hf=have fun|rn=right now|tbh=to be honest|imo=in my opinion|
wtf=what the hell|xswl=笑死我了|yyds=永远的神|awsl=啊我死了|hhh=哈哈哈|hhhh=哈哈哈哈|
]])
local EN = T([[
u=you|ur=your|r=are|y=why|k=okay|kk=okay|bc=because|cuz=because|cus=because|mb=my bad|
ik=I know|idc=I don't care|ig=I guess|ily=I love you|tho=though|ngl=not gonna lie|
fr=for real|frfr=for real|ong=on god|smh=shaking my head|tbf=to be fair|irl=in real life|
dm=direct message|wb=welcome back|gn=good night|gm=good morning|ty=thank you|yw=you're welcome|
asap=as soon as possible|oml=oh my god|sus=suspicious|bruh=bro|wyd=what are you doing|
hbu=how about you|hru=how are you|sry=sorry|soz=sorry|abt=about|bout=about|ppl=people|
rly=really|ofc=of course|ikr=I know right|lmk=let me know|ttyl=talk to you later|
gtg=going to go|g2g=going to go|bbl=be back later|dw=don't worry|ye=yeah|yea=yeah|
wat=what|wut=what|thanku=thank you|
]])
local IDN = T([[
gk=tidak|ga=tidak|gak=tidak|ngga=tidak|nggak=tidak|enggak=tidak|tdk=tidak|yg=yang|dgn=dengan|
dg=dengan|sdh=sudah|udh=sudah|udah=sudah|dah=sudah|bgt=banget|bngt=banget|bs=bisa|jgn=jangan|
lg=lagi|krn=karena|karna=karena|utk=untuk|dr=dari|tp=tapi|sm=sama|aq=aku|ak=aku|km=kamu|
kmu=kamu|hrs=harus|org=orang|sy=saya|mksh=terima kasih|makasih=terima kasih|tq=terima kasih|
kmrn=kemarin|bsk=besok|skrg=sekarang|skg=sekarang|blm=belum|emg=memang|trs=terus|jd=jadi|
bkn=bukan|knp=kenapa|gmn=bagaimana|gimana=bagaimana|msh=masih|yaudah=ya sudah|gpp=tidak apa apa|
gapapa=tidak apa apa|sapa=siapa|kpn=kapan|dmn=di mana|mls=malas|cpt=cepat|dlu=dulu|bru=baru|
gue=aku|gw=aku|lu=kamu|sip=oke|
]])
local ES = T([[
q=que|xq=porque|pq=porque|porq=porque|pk=porque|tb=también|tmb=también|tbn=también|x=por|
xfa=por favor|xfavor=por favor|porfa=por favor|pls=por favor|bn=bien|k=que|ke=que|d=de|
dnd=dónde|salu2=saludos|tkm=te quiero mucho|tqm=te quiero mucho|ps=pues|pa=para|nose=no sé|
ns=no sé|toy=estoy|stoy=estoy|tas=estás|ta=está|dps=después|cmo=cómo|msj=mensaje|grax=gracias|
vdd=verdad|mñn=mañana|tmr=mañana|ntp=no te preocupes|xd=jaja|jsjs=jaja|jsjsjs=jaja|jeje=jaja|
tp=tampoco|mxo=mucho|ola=hola|hla=hola|nd=nada|
]])
local PT = T([[
vc=você|vcs=vocês|tb=também|tbm=também|blz=beleza|pq=porque|n=não|obg=obrigado|brigado=obrigado|
mt=muito|mto=muito|msm=mesmo|vlw=valeu|flw=falou|td=tudo|tds=todos|q=que|hj=hoje|amg=amigo|
amgs=amigos|bjs=beijos|nd=nada|ngm=ninguém|pfv=por favor|pf=por favor|sdds=saudades|
sqn=só que não|tmj=estamos juntos|cmg=comigo|ctz=certeza|qnd=quando|dps=depois|mds=meu Deus|
nss=nossa|ss=sim|nn=não|ent=então|bora=vamos|eh=é|ta=está|to=estou|tá=está|tô=estou|vdd=verdade|
oq=o que|oque=o que|sdv=se Deus quiser|pdc=pode crer|
]])
local RU = T([[
спс=спасибо|пасиб=спасибо|пасибо=спасибо|пж=пожалуйста|плз=пожалуйста|плиз=пожалуйста|
пжлст=пожалуйста|пожалуста=пожалуйста|хз=не знаю|кст=кстати|щас=сейчас|ща=сейчас|
норм=нормально|чё=что|че=что|мб=может быть|чел=человек|имхо=по моему мнению|лол=ха-ха|
кек=ха-ха|ахаха=ха-ха|хаха=ха-ха|ок=хорошо|прив=привет|здр=здравствуйте|спок=спокойной ночи|
сек=секунду|нзч=не за что|ясн=ясно|ваще=вообще|типо=типа|бб=пока|мерси=спасибо|
]])
local TURK = T([[
slm=selam|mrb=merhaba|nbr=ne haber|naber=ne haber|tmm=tamam|tşk=teşekkürler|tsk=teşekkürler|
tşkler=teşekkürler|evt=evet|hyr=hayır|bn=ben|sn=sen|bi=bir|kib=kendine iyi bak|gn=günaydın|
hdi=hadi|yrn=yarın|bşk=başka|bkz=bakınız|sağol=sağ ol|knk=kanka|nolcak=ne olacak|
]])
local THA = T([[คับ=ครับ|มั้ย=ไหม|ม้าย=ไหม|ป่าว=เปล่า|ชั้น=ฉัน|เค=โอเค|จร้า=จ้ะ|จ้า=จ้ะ|]])
local KOR = T([[
ㅇㅇ=응|ㄴㄴ=아니 아니|ㄱㅅ=감사|ㅈㅅ=죄송|ㅇㅋ=오케이|ㄱㄱ=가자|ㅊㅋ=축하|ㅅㄱ=수고|
ㅂㅂ=바이바이|ㅎㅇ=안녕|ㅇㅈ=인정|ㄷㄷ=덜덜|ㅁㅊ=미쳤다|ㅇㅎ=아하|ㄹㅇ=진짜|ㄱㅊ=괜찮아|
]])
local JPN = T([[
りょ=了解|あざ=ありがとう|あざす=ありがとうございます|あざっす=ありがとうございます|
おつ=お疲れ様|乙=お疲れ様|よろ=よろしく|ごめ=ごめん|おは=おはよう|ワロタ=笑った|
それな=その通り|ぴえん=泣きそう|ノシ=またね|草=笑|草草=笑|草草草=笑|草w=笑|草ww=笑|
]])
local ZHO = T([[
nb=牛逼|wc=卧槽|tmd=他妈的|mdzz=妈的智障|dbq=对不起|bzd=不知道|bhys=不好意思|gkd=搞快点|
yysy=有一说一|xdm=兄弟们|dalao=大佬|lj=垃圾|cj=菜鸡|sb=傻逼|zqsg=真情实感|nsdd=你说得对|
]])
local FIL = T([[
lng=lang|nmn=naman|kc=kasi|tlga=talaga|pano=paano|wla=wala|hnd=hindi|hndi=hindi|nde=hindi|
bkt=bakit|sna=sana|sge=sige|wag=huwag|pwde=pwede|dko=hindi ko|d=hindi|ung=yung|nyo=ninyo|
tnx=salamat|thnx=salamat|
]])
local VIE = T([[
ko=không|k=không|kh=không|hok=không|dc=được|đc=được|vs=với|mn=mọi người|bt=bình thường|
ntn=như thế nào|nc=nói chuyện|trc=trước|sd=sử dụng|cx=cũng|j=gì|z=vậy|dt=điện thoại|
đt=điện thoại|bn=bạn|mk=mình|thik=thích|ny=người yêu|r=rồi|rùi=rồi|trl=trả lời|ib=nhắn tin|
nt=nhắn tin|wa=quá|qa=quá|
]])

local ABBR = {en = EN, id = IDN, ms = IDN, es = ES, pt = PT, ru = RU, tr = TURK, th = THA,
    ko = KOR, ja = JPN, zh = ZHO, tl = FIL, vi = VIE}
local RAW = {ja = {{"ワロタ", "笑った"}, {"ぴえん", "泣きそう"}, {"草生える", "笑える"}}}
local LAUGH = {ja = "笑", ko = "하하", th = "ฮ่าๆ", zh = "哈哈"}

local function onlyOf(w, ch) return w ~= "" and (w:gsub(ch, "")) == "" end

-- Nhận ra các kiểu cười: kkk, wkwk, rsrs, ww (ja), 555 (th), ㅋㅋ, ㅎㅎ, ㅠㅠ
local function laughOf(w, lang)
    local n = #w
    local L = LAUGH[lang or ""] or "haha"
    if n >= 3 and w:find("^k+$") then return L end
    if n >= 4 then
        local x = w:gsub("wk", "")
        if x == "" or x == "w" or x == "k" or x == "kw" or onlyOf(w, "rs") then return L end
    end
    if lang == "ja" and (w:find("^w+$") or onlyOf(w, "ｗ")) then return L end
    if lang == "th" and n >= 3 and w:find("^5+$") then return L end
    if onlyOf(w, "ㅋ") or onlyOf(w, "ㅎ") then return LAUGH.ko end
    if onlyOf(w, "ㅠ") or onlyOf(w, "ㅜ") then return "흑흑" end
end

-- Mở rộng viết tắt trong câu. Trả về: câu mới, có thay đổi hay không
local function expand(text, lang)
    if not S.abbr or type(text) ~= "string" then return text, false end
    local before = text
    local t = text:match("^%s*(.-)%s*$")
    if #t >= 3 and #t <= 8 then -- tin chỉ gồm 666 / 233 / 555
        if t:find("^6+$") and (#t >= 4 or lang == "zh") then return (lang == "zh") and "厉害" or "awesome", true end
        if t:find("^2333*$") and (#t >= 4 or lang == "zh") then return LAUGH.zh, true end
        if t:find("^5+$") and (#t >= 4 or lang == "th") then return LAUGH.th, true end
    end
    local ltable = lang and ABBR[lang]
    local function fix(w)
        local lw = ulower(w)
        return laughOf(lw, lang) or UNI[lw] or (ltable and ltable[lw]) or nil
    end
    local out = text:gsub("[^%s%p]+", function(tok)
        if tok:find("[\128-\255]") then
            local r = fix(tok)
            if r then return r end
            if tok:find("[\224\227-\237]") then -- trộn Latin với Hán/Nhật/Hàn/Thái
                tok = tok:gsub("[%a%d]+", fix)
                for _, p in ipairs(lang and RAW[lang] or {}) do tok = tok:gsub(p[1], p[2]) end
            end
            return tok
        end
        return fix(tok)
    end)
    return out, out ~= before
end

---------------------------------------------------------------- Các nguồn dịch
local function gtx(text, sl, tl)
    local body = httpReq({Url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl="
        .. sl .. "&tl=" .. tl .. "&dt=t&q=" .. urlEncode(text), Method = "GET"})
    local d = body and jsonDecode(body)
    if not d or type(d[1]) ~= "table" then return end
    local out = {}
    for _, seg in ipairs(d[1]) do
        if type(seg) == "table" and type(seg[1]) == "string" then out[#out + 1] = seg[1] end
    end
    local res = table.concat(out)
    if res == "" then return end
    return res, (type(d[3]) == "string") and d[3] or nil
end

local function gdict(text, sl, tl)
    local body = httpReq({Url = "https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl="
        .. sl .. "&tl=" .. tl .. "&q=" .. urlEncode(text), Method = "GET"})
    local d = body and jsonDecode(body)
    local f = d and d[1]
    if type(f) == "table" and type(f[1]) == "string" then return f[1], f[2] end
    if type(f) == "string" then return f end
end


-- Nguồn dịch: Google (thử lại 1 lần) -> Google dict
local function runBackends(txt, sl, tl)
    local r, d = gtx(txt, sl, tl)
    if r then return r, d end
    task.wait(0.25)
    r, d = gtx(txt, sl, tl)
    if r then return r, d end
    r, d = gdict(txt, sl, tl)
    if r then return r, (type(d) == "string") and d or nil end
end

-- Trả về: bản dịch, ngôn ngữ nguồn (mã chuẩn), trạng thái ("ok" | "same" | "fail")
local function translateCore(text, tl, sl, style, hint)
    tl = normLang(tl) or tl
    sl = (sl and sl ~= "auto") and (normLang(sl) or "auto") or "auto"
    local key = ckey(text)
    if key == "" then return text, nil, "same" end

    local ek = mk(tl, style, key)
    local hit = cGet(TR, ek)
    if hit then return hit.o, hit.d, hit.s end

    if sl == "auto" then
        local q = quickDetect(text)
        sl = q and (normLang(q) or q) or "auto"
    end
    if sl ~= "auto" and sameLang(sl, tl) then return text, sl, "same" end

    local function done(out, det, st)
        if st == "ok" or (st == "same" and det) then
            cSet(TR, ek, {o = out, d = det, s = st})
            markDirty()
            if det then cSet(DET, key, det) end
        end
        return out, det, st
    end

    local src = clean(text, "en", true)
    if src == "" then src = text end
    local known = (sl ~= "auto") and lc(sl) or nil
    local expLang = known or (hint and lc(hint)) or nil
    local pre = expand(src, expLang)

    local res, det = runBackends(pre, sl, tl)
    if not res then return text, (sl ~= "auto") and sl or nil, "fail" end
    local detN = det and (normLang(det) or det) or ((sl ~= "auto") and sl or nil)
    if detN and sameLang(detN, tl) then return done(text, detN, "same") end

    -- chưa biết ngôn ngữ trước đó, giờ Google đã nhận ra: thử mở rộng viết tắt theo ngôn ngữ đó
    if not known and detN then
        local dl = lc(detN)
        if dl ~= expLang then
            local pre2, ch2 = expand(src, dl)
            if ch2 and pre2 ~= pre then
                local r2 = runBackends(pre2, detN, tl)
                if r2 then res, pre = r2, pre2 end
            end
        end
    end

    -- Google trả nguyên văn: thử 1 nguồn khác
    if norm(res) == norm(pre) then
        if not pre:find("[%a\128-\255]") then return done(text, detN, "same") end
        local r2 = gdict(pre, detN or "auto", tl)
        if r2 and norm(r2) ~= norm(pre) then res = r2 else return done(text, detN, "same") end
    end
    return done(clean(res, tl), detN, "ok")
end

-- Vỏ bọc: gộp các yêu cầu giống hệt nhau đang chạy (chỉ gọi mạng 1 lần) và bắt mọi lỗi
local inflight = {}
local function translate(text, tl, sl, style, hint)
    local ek = mk(normLang(tl) or tl, style, ckey(text))
    local q = inflight[ek]
    if q then
        local w = {co = coroutine.running(), done = false}
        q[#q + 1] = w
        task.delay(25, function() if not w.done then w.done = true task.spawn(w.co) end end)
        coroutine.yield()
        local hit = cGet(TR, ek)
        if hit then return hit.o, hit.d, hit.s end
    end
    inflight[ek] = {}
    local ok, a, b, c = pcall(translateCore, text, tl, sl, style, hint)
    local waiters = inflight[ek]
    inflight[ek] = nil
    for _, w in ipairs(waiters or {}) do
        if not w.done then w.done = true task.spawn(w.co) end
    end
    if ok then return a, b, c end
    return text, nil, "fail"
end

-- Lưu kết quả dịch bắc cầu làm kết quả chính của câu gốc
local function cachePivot(text, tl, style, out, det)
    cSet(TR, mk(normLang(tl) or tl, style, ckey(text)), {o = out, d = det, s = "ok"})
    markDirty()
end

-- Ngôn ngữ phổ biến dịch trực tiếp tốt; ngôn ngữ hiếm -> dịch bắc cầu qua tiếng Anh
local COMMON = {}
for c in ("en vi zh-CN zh-TW ja ko es pt fr de ru id th it tr ar hi pl nl uk ms tl"):gmatch("%S+") do COMMON[c] = true end
local function isRare(l)
    local n = normLang(l)
    return n ~= nil and not COMMON[n]
end

-- Dịch thông minh (cho tin mình gửi đi)
local function smartTranslate(text, tl, sl, style, hint)
    local out, det, st = translate(text, tl, sl, style, hint)
    local tln = normLang(tl) or tl
    det = det or ((sl and sl ~= "auto") and sl or nil)
    if not S.pivot or st == "same" or tln == "en" or (det and sameLang(det, "en")) then
        return out, det, st
    end
    if st ~= "ok" or isRare(tln) or (det and isRare(det)) then
        local en, _, enSt = translate(text, "en", det or sl or "auto", style, hint)
        if enSt == "ok" and en then
            local o2, _, s2 = translate(en, tln, "en", style)
            if s2 == "ok" then
                cachePivot(text, tln, style, o2, det)
                return o2, det, "ok"
            end
        end
    end
    return out, det, st
end

---------------------------------------------------------------- Gửi chat
local useTCS = TextChatService.ChatVersion == Enum.ChatVersion.TextChatService

local function sendChat(text)
    if ulen(text) > 200 then text = text:sub(1, (utf8.offset(text, 201) or (#text + 1)) - 1) end
    if useTCS then
        local tc = TextChatService:FindFirstChild("TextChannels")
        local ch = tc and tc:FindFirstChild("RBXGeneral")
        if not ch then
            for _, c in ipairs(tc and tc:GetChildren() or {}) do
                if c:IsA("TextChannel") and c.Name ~= "RBXSystem" and c:FindFirstChild(LocalPlayer.Name) then ch = c break end
            end
        end
        if ch and pcall(function() ch:SendAsync(text) end) then return true end
    end
    local ev = RS:FindFirstChild("DefaultChatSystemChatEvents")
    local say = ev and ev:FindFirstChild("SayMessageRequest")
    return (say and pcall(function() say:FireServer(text, "All") end)) or false
end

local function styleOut(s) -- bỏ dấu chấm cuối câu cho giống tin nhắn thường
    s = s:gsub("。+$", ""):gsub("%.+$", "")
    return s
end

-- Lỗi / hết lượt => trả nil để dùng Google.
-- ===== Firebase: tra bản dịch có sẵn =====
local fbMem = {} -- nhớ trong phiên chơi, khỏi hỏi lại Firebase

-- băm khoá (văn bản có ký tự không hợp lệ làm khoá Firebase) thành 16 ký tự hex; khoá gốc được lưu kèm để kiểm tra trùng
local function fbId(key)
    if not bit32 then return nil end
    local h1, h2 = 2166136261, 5381
    for i = 1, #key do
        local b = key:byte(i)
        h1 = bit32.band(bit32.lshift(bit32.bxor(h1, b), 24) + bit32.bxor(h1, b) * 403, 0xFFFFFFFF) -- FNV-1a
        h2 = (h2 * 33 + b) % 4294967296 -- djb2
    end
    return string.format("%08x%08x", h1, h2)
end

local function fbGet(id, key)
    if fbMem[id] then return fbMem[id] end
    local body = httpReq({Url = FB_URL .. "/tr/" .. id .. ".json", Method = "GET"}, 3)
    local e = body and jsonDecode(body)
    if type(e) == "table" and e.k == key and type(e.o) == "string" and e.o ~= "" then
        fbMem[id] = e.o
        return e.o
    end
end

-- Tra bản dịch có sẵn trên Firebase (chỉ đọc). Tin ngắn / không có chữ cái thì bỏ qua.
local fbTag = nil -- chú thích hiện cạnh tên "Bạn" khi lấy từ Firebase
local function fbLookup(text, tl)
    fbTag = nil
    if not (S.useDB and FB_URL ~= "") then return end
    if ulen(text) <= 2 or not text:find("[%a\128-\255]") then return end
    local key = tl .. "|" .. ckey(text)
    local id = fbId(key)
    local saved = id and fbGet(id, key)
    if saved then fbTag = " · Firebase" end
    return saved
end

local function translateOut(raw)
    local g = fbLookup(raw, normLang(S.outLang) or S.outLang)
    if g then g = styleOut(stripP(g, S.outLang)) return S.noCaps and ulower(g) or g, "ok" end
    local _, changed = expand(raw, lc(S.myLang)) -- có viết tắt tiếng mẹ đẻ => chắc chắn nguồn là ngôn ngữ của tôi
    local out, _, st = smartTranslate(raw, S.outLang, changed and S.myLang or "auto")
    if st == "ok" then out = stripP(out, S.outLang) end
    out = styleOut(out)
    if S.noCaps then out = ulower(out) end -- bật "Không viết hoa": đổi hết chữ cái sang chữ thường
    return out, st
end

---------------------------------------------------------------- UI helpers
local FONT, HEAD, LEFT = Enum.Font.Code, Enum.Font.GothamBold, Enum.TextXAlignment.Left
local RED, WHITE = Color3.fromRGB(255, 90, 90), Color3.new(1, 1, 1)

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function guiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then
        local t = Instance.new("Folder")
        local ok2 = pcall(function() t.Parent = cg end)
        t:Destroy()
        if ok2 then return cg end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function esc(s) return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end

local function chatRect()
    local ok, pos, size = pcall(function()
        local c = TextChatService:FindFirstChild("ChatWindowConfiguration")
        return c.AbsolutePosition, c.AbsoluteSize
    end)
    if ok and size and size.X > 50 and size.Y > 50 then return pos, size end
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    return Vector2.new(8, 40), Vector2.new(math.clamp(vp.X * 0.3, 260, 450), math.clamp(vp.Y * 0.25, 150, 260))
end

local PARENT = guiParent()
pcall(function()
    local old = PARENT:FindFirstChild("UniqueTranslatorUI")
    if old then old:Destroy() end
end)
gui = new("ScreenGui", {Name = "UniqueTranslatorUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999})
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
gui.Parent = PARENT

-- Kéo thả: chỉ 1 listener InputChanged dùng chung
local drag = {}
local function makeDraggable(handle, target)
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag.target, drag.startIn, drag.startPos = target, i.Position, target.Position
            local c
            c = i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    if drag.target == target then drag.target = nil end
                    c:Disconnect()
                end
            end)
        end
    end)
end
track(UIS.InputChanged:Connect(function(i)
    local t = drag.target
    if t and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d, sp = i.Position - drag.startIn, drag.startPos
        t.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
    end
end))

---------------------------------------------------------------- Thành phần giao diện (bo tròn, tối giản)
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local TOP, CHIP_W = 44, 100

local function round(o, r) new("UICorner", {CornerRadius = UDim.new(0, r)}, o) return o end
local function stroke(o, c, th, tr) return new("UIStroke", {Color = c, Thickness = th or 1, Transparency = tr or 0}, o) end
local function cardColor() return OBS:Lerp(TXT, 0.1) end

local function buildPanel(parent, W, H)
    local f = new("Frame", {Size = UDim2.fromOffset(W, H), BackgroundColor3 = OBS,
        BackgroundTransparency = FILL_T, BorderSizePixel = 0, ZIndex = 1}, parent)
    round(f, 18)
    stroke(f, NEON, 1.5, 0.05)
    return f
end

local function roundButton(parent, x, y, size, glyph, cb)
    local b = new("TextButton", {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = cardColor(), BackgroundTransparency = 0.2, Text = glyph, Font = HEAD, TextSize = 16,
        TextColor3 = TXT, AutoButtonColor = false, ZIndex = 7}, parent)
    round(b, size / 2)
    stroke(b, DIM, 1, 0.2)
    b.Activated:Connect(cb)
    return b
end

-- nhãn nhỏ hình viên thuốc (VI / EN / tên ngôn ngữ gốc / khoảng cách)
local function chip(parent, text, filled, color)
    local w = 40
    local ok, v = pcall(function() return TextService:GetTextSize(text, 11, FONT, Vector2.new(400, 20)).X end)
    if ok and v then w = v + 14 end
    w = math.clamp(w, 26, CHIP_W)
    local c = new("TextLabel", {Size = UDim2.fromOffset(w, 16), BackgroundColor3 = filled and NEON or OBS,
        BackgroundTransparency = filled and 0 or 1, Text = text, Font = FONT, TextSize = 11,
        TextColor3 = filled and OBS or (color or TXT), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7}, parent)
    round(c, 8)
    if not filled then stroke(c, DIM, 1, 0) end
    return c
end

local function line(parent, order, label, text, filled, color, size, fixedW)
    local x = label and (CHIP_W + 8) or 0
    local row = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 6}, parent)
    local c
    if label then
        c = chip(row, label, filled, DIM)
        c.Position = UDim2.fromOffset(0, 1)
    end
    local lbl = new("TextLabel", {Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, TextWrapped = true, Font = FONT,
        TextSize = size, TextColor3 = color, TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top,
        Text = text, ZIndex = 6}, row)
    local fixed = false
    if fixedW then -- đo trước chiều cao thật, để lúc gõ chữ khung không bị giãn dần
        local ok, h = pcall(function()
            return TextService:GetTextSize(text, size, FONT, Vector2.new(math.max(60, fixedW - x), 10000)).Y
        end)
        if ok and h then
            row.AutomaticSize, row.Size = Enum.AutomaticSize.None, UDim2.new(1, 0, 0, math.max(17, h))
            lbl.AutomaticSize, lbl.Size = Enum.AutomaticSize.None, UDim2.new(1, -x, 1, 0)
            lbl.Text, fixed = "", true
        end
    end
    return row, lbl, c, fixed
end

-- Hiệu ứng gõ chữ kiểu máy tính: từng ký tự hiện ra + con trỏ "_" nhấp nháy
local CURSOR = "_"
local function typeText(lbl, full, blink, slow)
    local n = utf8.len(full)
    if not n or n == 0 then lbl.Text = full return end
    local dur = slow and math.clamp(n * 0.03, 0.3, 1.1) or math.clamp(n * 0.012, 0.15, 0.5)
    local t0, shown = tick(), 0
    while alive and lbl.Parent do
        local k = math.min(n, math.floor((tick() - t0) / dur * n) + 1)
        if k ~= shown then
            shown = k
            local cut = (utf8.offset(full, k + 1) or (#full + 1)) - 1
            lbl.Text = full:sub(1, cut) .. CURSOR
        end
        if k >= n then break end
        task.wait()
    end
    if not (alive and lbl.Parent) then return end
    if blink then
        for _ = 1, 2 do
            lbl.Text = full .. CURSOR
            task.wait(0.16)
            lbl.Text = full
            task.wait(0.16)
            if not (alive and lbl.Parent) then return end
        end
    end
    lbl.Text = full
end

local function playSeq(card, seq) -- các thanh hiện lần lượt như in từng dòng
    task.spawn(function()
        for i, s in ipairs(seq) do
            if not (alive and card.Parent) then return end
            if s.chip then s.chip.Visible = true end
            typeText(s.lbl, s.text, i == #seq, i == 1)
        end
    end)
end

local function flashCard(card) -- thẻ mới: viền sáng rồi tắt dần
    card.BackgroundTransparency = 1
    TweenService:Create(card, TweenInfo.new(0.25), {BackgroundTransparency = 0.25}):Play()
    local st = stroke(card, NEON, 1.5, 0.05)
    TweenService:Create(st, TweenInfo.new(0.9), {Transparency = 1}):Play()
    task.delay(1, function() pcall(function() st:Destroy() end) end)
end

local function chipName(code)
    local c = normLang(code)
    local n = c and NAMES[c]
    if not n then return "Gốc" end
    return (n:gsub("%s*%b()", ""))
end
local function shortCode(code) return ((normLang(code) or tostring(code or "?")):upper()) end

---------------------------------------------------------------- Chat log (khung chính)
local cpos, csize = chatRect()
local vpS = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
local logW = math.clamp(csize.X * 0.95, 320, vpS.X * 0.9)
local logH = math.clamp(csize.Y * 1.1, 260, vpS.Y * 0.9)
local logX, logY = cpos.X + csize.X + 10, cpos.Y
if cpos.X < 0 or cpos.X > vpS.X or cpos.Y < 0 or cpos.Y > vpS.Y then logX, logY = 8, 40 end
logX = math.max(8, math.min(logX, vpS.X - logW - 8))
logY = math.max(8, math.min(logY, vpS.Y - logH - 8))

local logRoot = new("Frame", {Name = "LogRoot", Position = UDim2.fromOffset(logX, logY),
    Size = UDim2.fromOffset(logW, logH), BackgroundTransparency = 1, BorderSizePixel = 0}, gui)
local MW, MH = 320, math.min(430, vpS.Y - 24)
local menu = new("Frame", {Name = "Menu", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(MW, MH), BackgroundTransparency = 1, Visible = false}, gui)

local logScroll, statusLbl, input
local logData, logLabels, logCount = {}, {}, 0
local statusText, statusRed = "", false

local spinGen = 0
local function setStatus(kind, msg) -- hiện lỗi; khi đang dịch thì hiện vòng xoay kiểu terminal
    spinGen = spinGen + 1
    local my = spinGen
    statusRed = kind == "err"
    statusText = statusRed and ("⦗ ERR ⦘ " .. msg) or ""
    if statusLbl then
        statusLbl.Text = statusText
        statusLbl.TextColor3 = statusRed and RED or TXT
    end
    if kind == "busy" and S.fx then
        task.spawn(function()
            local frames, i = {"|", "/", "-", "\\"}, 0
            while alive and spinGen == my do
                i = i % 4 + 1
                statusText = "> " .. frames[i] .. " đang dịch" .. string.rep(".", i - 1)
                if statusLbl then statusLbl.Text, statusLbl.TextColor3 = statusText, TXT end
                task.wait(0.1)
            end
        end)
    end
end

-- 1 tin = 1 thẻ: tên + khoảng cách, rồi 3 thanh: bản dịch / tiếng Anh / câu gốc + tên ngôn ngữ gốc
local function makeEntry(e, order, animate)
    local card = new("Frame", {Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = cardColor(), BackgroundTransparency = 0.25, BorderSizePixel = 0,
        LayoutOrder = order, ZIndex = 5}, logScroll)
    round(card, 12)
    new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, card)
    new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, card)

    local head = new("Frame", {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 6}, card)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, head)
    local tag = e.status == "fail" and "<font color=\"#FF5A5A\">⦗ ERR ⦘</font> " or ""
    new("TextLabel", {Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
        RichText = true, Text = tag .. "<b>" .. esc(e.name or "?") .. "</b>", Font = FONT, TextSize = 13,
        TextColor3 = TXT, LayoutOrder = 1, ZIndex = 6}, head)
    if type(e.dist) == "number" and e.dist < math.huge then
        chip(head, math.floor(e.dist) .. " m", false, DIM).LayoutOrder = 2
    end

    local fx = animate and S.fx
    local rowW = fx and (logW - 48) or nil
    local seq = {}
    local function add(o, label, text, filled, color, size)
        local _, lbl, c, ok = line(card, o, label, text, filled, color, size, rowW)
        if ok then
            if c then c.Visible = false end
            seq[#seq + 1] = {lbl = lbl, chip = c, text = text}
        end
    end

    if e.dist == nil and e.orig == nil then -- tin hệ thống: chỉ 1 dòng chữ
        add(2, nil, e.result or "", false, DIM, 13)
    else
        add(2, shortCode(e.rlang or S.myLang), e.result or "", true, TXT, 15)
        if S.showEN and e.en and norm(e.en) ~= norm(e.result) and norm(e.en) ~= norm(e.orig) then
            add(3, "EN", e.en, false, TXT:Lerp(OBS, 0.15), 13)
        end
        if S.showOrig and e.orig and norm(e.orig) ~= norm(e.result) then
            add(4, chipName(e.det), e.orig, false, DIM, 13)
        end
    end
    if fx then
        flashCard(card)
        if #seq > 0 then playSeq(card, seq) end
    end
    return card
end

local function scrollDown()
    task.delay(0.05, function()
        if logScroll and logScroll.Parent then
            logScroll.CanvasPosition = Vector2.new(0, logScroll.AbsoluteCanvasSize.Y)
        end
    end)
end

-- Hàm công khai: _G.AddLogToUI(name, dist, result, status, orig, en, det, rlang)
local function addLog(name, dist, result, status, orig, en, det, rlang)
    local e = {name = name, dist = dist, result = result, status = status, orig = orig, en = en, det = det, rlang = rlang}
    logCount = logCount + 1
    logData[#logData + 1] = e
    if #logData > MAX_LOG then table.remove(logData, 1) end
    if logScroll then
        if #logLabels >= MAX_LOG then
            local old = table.remove(logLabels, 1)
            pcall(function() old:Destroy() end)
        end
        logLabels[#logLabels + 1] = makeEntry(e, logCount, true)
        scrollDown()
    end
end
_G.AddLogToUI = addLog
env.AddLogToUI = addLog

-- Gửi tin: dịch rồi gửi vào chat
local sending, sendT = false, 0
local function doSend(raw)
    raw = (raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if raw == "" or (sending and tick() - sendT < 25) then return end
    sending, sendT = true, tick()
    setStatus("busy", "Đang dịch...")
    task.spawn(function()
        local ok, err = pcall(function()
            local out, st = translateOut(raw)
            if st == "fail" then return setStatus("err", "Lỗi mạng, không dịch được.") end
            addLog("Bạn" .. (fbTag or ""), nil, out, "ok", raw, nil, S.myLang, S.outLang)
            local cp = S.autoCopy and (setclipboard or toclipboard)
            if cp then pcall(cp, out) end
            if S.autoSend then
                if sendChat(out) then setStatus("ok", "Đã gửi: " .. out)
                else setStatus("err", "Gửi thất bại (đã copy): " .. out) end
            else
                setStatus("ok", "Bản dịch: " .. out)
            end
            if input then input.Text = "" end
        end)
        if not ok then setStatus("err", tostring(err)) end
        sending = false
    end)
end

local renderLog
local function resizeLog(f)
    logW, logH = math.clamp(logW * f, 300, vpS.X * 0.9), math.clamp(logH * f, 240, vpS.Y * 0.9)
    logRoot.Size = UDim2.fromOffset(logW, logH)
    task.defer(renderLog)
end

renderLog = function()
    local keep = input and input.Text or ""
    for _, c in ipairs(logRoot:GetChildren()) do c:Destroy() end
    local W, H = logW, logH
    buildPanel(logRoot, W, H)

    -- thanh tiêu đề (kéo để di chuyển) + nút cài đặt
    makeDraggable(new("TextButton", {Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(W - 72, TOP),
        BackgroundTransparency = 1, Text = "Dịch chat", Font = FONT, TextSize = 15, TextColor3 = TXT,
        TextXAlignment = LEFT, AutoButtonColor = false, ZIndex = 6}, logRoot), logRoot)
    roundButton(logRoot, W - 48, 6, 32, "≡", function() menu.Visible = not menu.Visible end)

    logScroll = new("ScrollingFrame", {Position = UDim2.fromOffset(12, TOP), Size = UDim2.fromOffset(W - 24, H - TOP - 74),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = NEON,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5}, logRoot)
    new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, logScroll)
    logLabels = {}
    for i, e in ipairs(logData) do logLabels[i] = makeEntry(e, logCount - #logData + i) end
    scrollDown()

    statusLbl = new("TextLabel", {Position = UDim2.fromOffset(18, H - 70), Size = UDim2.fromOffset(W - 36, 16),
        BackgroundTransparency = 1, Text = statusText, Font = FONT, TextSize = 12,
        TextColor3 = statusRed and RED or TXT, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6}, logRoot)

    -- ô nhập dạng viên thuốc + nút gửi tròn
    local bar = new("Frame", {Position = UDim2.fromOffset(12, H - 52), Size = UDim2.fromOffset(W - 24, 40),
        BackgroundColor3 = cardColor(), BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 5}, logRoot)
    round(bar, 20)
    local ring = stroke(bar, DIM, 1.2, 0.1)
    input = new("TextBox", {Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(W - 24 - 16 - 44, 40),
        BackgroundTransparency = 1, PlaceholderText = "Gõ tin nhắn", Text = keep, ClearTextOnFocus = false,
        MultiLine = false, Font = FONT, TextSize = 15, TextColor3 = TXT, PlaceholderColor3 = DIM,
        TextXAlignment = LEFT, ZIndex = 6}, bar)
    input.Focused:Connect(function() ring.Color, ring.Thickness = NEON, 1.8 end)
    input.FocusLost:Connect(function(enter)
        ring.Color, ring.Thickness = DIM, 1.2
        if enter then doSend(input.Text) end
    end)
    local send = new("TextButton", {Position = UDim2.fromOffset(W - 24 - 36, 4), Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = NEON, Text = ">>", Font = HEAD, TextSize = 13, TextColor3 = OBS,
        AutoButtonColor = false, ZIndex = 7}, bar)
    round(send, 16)
    send.Activated:Connect(function() doSend(input.Text) end)
end

---------------------------------------------------------------- Menu cài đặt (dựng lại khi đổi màu)
local body, refreshAll

local function buildMenu()
    for _, c in ipairs(menu:GetChildren()) do c:Destroy() end
    buildPanel(menu, MW, MH)
    makeDraggable(new("TextButton", {Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(MW - 72, TOP),
        BackgroundTransparency = 1, Text = "Cài đặt", Font = FONT, TextSize = 15, TextColor3 = TXT,
        TextXAlignment = LEFT, AutoButtonColor = false, ZIndex = 6}, menu), menu)
    roundButton(menu, MW - 48, 6, 32, "X", function() menu.Visible = false end)

    body = new("ScrollingFrame", {Position = UDim2.fromOffset(12, TOP),
        Size = UDim2.fromOffset(MW - 24, MH - TOP - 14), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = NEON, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5}, menu)
    new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, body)

    local order, refs = 0, {}
    refreshAll = function() for _, f in ipairs(refs) do f() end end

    local function rowBtn(h)
        order = order + 1
        local b = new("TextButton", {Size = UDim2.new(1, -4, 0, h or 34), BackgroundColor3 = OBS,
            BackgroundTransparency = FILL_T, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
            LayoutOrder = order, ZIndex = 5}, body)
        round(b, 10)
        return b
    end
    local function rowLabel(b, x)
        return new("TextLabel", {Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - 4, 1, 0),
            BackgroundTransparency = 1, Font = FONT, TextSize = 13, TextXAlignment = LEFT, TextColor3 = TXT,
            TextWrapped = true, Text = "", ZIndex = 6}, b)
    end
    local function toggle(label, key)
        local b = rowBtn(38)
        local dia = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(11, 19),
            Size = UDim2.fromOffset(10, 10), BorderSizePixel = 0, BackgroundColor3 = NEON, ZIndex = 6}, b)
        new("UIStroke", {Color = NEON, Thickness = 1}, dia) round(dia, 5)
        local lbl = rowLabel(b, 26)
        local function refresh()
            local on = S[key]
            dia.BackgroundTransparency = on and 0 or 1
            lbl.TextColor3 = on and TXT or DIM
            lbl.Text = label .. "  " .. (on and "⦗ ON ⦘" or "⦗ OFF ⦘")
        end
        b.Activated:Connect(function() S[key] = not S[key] refresh() saveSettings() end)
        refresh()
    end
    local function action(textFn, fn) -- hàng bấm: hiện chữ + chạy hàm khi bấm
        local b = rowBtn(34)
        local l = rowLabel(b, 10)
        local function r() l.Text = textFn() end
        refs[#refs + 1] = r
        b.Activated:Connect(function() fn() r() end)
        r()
    end

    -- đổi màu: lưu file + dựng lại giao diện
    local function reTheme()
        pcall(function() if writefile then writefile(THEME_FILE, HttpService:JSONEncode(TH)) end end)
        local sp = body.CanvasPosition
        task.defer(function()
            applyTheme()
            renderLog()
            buildMenu()
            task.defer(function() body.CanvasPosition = sp end)
        end)
    end

    for _, t in ipairs({
        {"Gắn với nút bật/tắt chat Roblox", "followChat"}, {"Dịch chat người khác", "incoming"},
        {"Chỉ dịch người ở gần (ưu tiên gần nhất)", "near"},
    }) do toggle(t[1], t[2]) end

    do -- khoảng cách dịch: gõ số trực tiếp hoặc bấm - / +
        local b = rowBtn(38)
        new("TextLabel", {Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(140, 38), BackgroundTransparency = 1,
            Font = FONT, TextSize = 13, TextXAlignment = LEFT, TextColor3 = TXT, Text = "Khoảng cách dịch:", ZIndex = 6}, b)
        local box
        local function setRange(n)
            S.range = math.clamp(math.floor(n + 0.5), 1, 5000)
            if box then box.Text = tostring(S.range) end
            saveSettings()
        end
        local function mini(txt, x, fn)
            local m = new("TextButton", {Position = UDim2.fromOffset(x, 5), Size = UDim2.fromOffset(28, 28),
                BackgroundColor3 = OBS, BackgroundTransparency = FILL_T, Text = txt, Font = FONT, TextSize = 18,
                TextColor3 = TXT, AutoButtonColor = false, ZIndex = 7}, b)
            new("UIStroke", {Color = NEON, Thickness = 1, Transparency = 0.45}, m)
            m.Activated:Connect(fn)
        end
        mini("-", 150, function() setRange(S.range - 10) end)
        box = new("TextBox", {Position = UDim2.fromOffset(182, 5), Size = UDim2.fromOffset(52, 28),
            BackgroundColor3 = OBS, BackgroundTransparency = FILL_T, Text = tostring(S.range), ClearTextOnFocus = false,
            PlaceholderText = "50", Font = FONT, TextSize = 14, TextColor3 = TXT, PlaceholderColor3 = DIM, ZIndex = 7}, b)
        new("UIStroke", {Color = NEON, Thickness = 1, Transparency = 0.45}, box)
        box.FocusLost:Connect(function() setRange(tonumber(box.Text) or S.range) end)
        mini("+", 238, function() setRange(S.range + 10) end)
    end

    for _, t in ipairs({
        {"Hiệu ứng gõ chữ kiểu terminal", "fx"}, {"Hiện bản tiếng Anh (EN)", "showEN"}, {"Dịch bắc cầu qua tiếng Anh (ngôn ngữ hiếm)", "pivot"},
        {"Hiểu từ viết tắt / tiếng lóng", "abbr"}, {"Hiện câu gốc", "showOrig"},
        {"Xoá dấu . , thừa sau khi dịch", "stripPunct"},
        {"Xoá dấu ! ? và ký hiệu cuối câu", "stripEnd"}, {"Tự gửi vào chat khi dịch xong", "autoSend"},
        {"Tự copy bản dịch", "autoCopy"}, {"Không viết hoa (chữ thường hết)", "noCaps"},
    }) do toggle(t[1], t[2]) end
    if FB_URL ~= "" then toggle("Dùng bản dịch có sẵn trên … (chỉ đọc)", "useDB") end

    -- bảng chọn ngôn ngữ (dựng khi mở lần đầu cho nhẹ máy)
    local picker, pickTitle, pickSearch, pickKey
    local pickItems = {}
    local function closePicker() if picker then picker.Visible = false end body.Visible = true end
    local function openPicker(key, title)
        if not picker then
            picker = new("Frame", {Position = body.Position, Size = body.Size, BackgroundTransparency = 1,
                Visible = false, ZIndex = 5}, menu)
            local back = new("TextButton", {Size = UDim2.fromOffset(74, 26), BackgroundColor3 = OBS,
                BackgroundTransparency = FILL_T, Text = "< BACK", Font = HEAD, TextSize = 10, TextColor3 = TXT,
                AutoButtonColor = false, ZIndex = 6}, picker)
            new("UIStroke", {Color = NEON, Thickness = 1, Transparency = 0.4}, back)
            back.Activated:Connect(closePicker)
            pickTitle = new("TextLabel", {Position = UDim2.fromOffset(82, 0), Size = UDim2.new(1, -86, 0, 26),
                BackgroundTransparency = 1, Font = FONT, TextSize = 13, TextColor3 = TXT, TextXAlignment = LEFT,
                TextWrapped = true, ZIndex = 6}, picker)
            pickSearch = new("TextBox", {Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, -4, 0, 28),
                BackgroundTransparency = 1, PlaceholderText = "> tìm ngôn ngữ_", Text = "", ClearTextOnFocus = false,
                Font = FONT, TextSize = 15, TextColor3 = TXT, PlaceholderColor3 = DIM, TextXAlignment = LEFT,
                ZIndex = 6}, picker)
            new("Frame", {Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, -4, 0, 3), BackgroundColor3 = NEON,
                BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 6}, picker)
            local ps = new("ScrollingFrame", {Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -70),
                BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = NEON,
                CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 6}, picker)
            new("UIListLayout", {Padding = UDim.new(0, 3)}, ps)
            for _, l in ipairs(LANGS) do
                local b = new("TextButton", {Size = UDim2.new(1, -4, 0, 30), BackgroundColor3 = OBS,
                    BackgroundTransparency = FILL_T, BorderSizePixel = 0, AutoButtonColor = false,
                    Text = l[1] .. "  (" .. l[2] .. ")", Font = FONT, TextSize = 14, TextColor3 = TXT,
                    TextXAlignment = LEFT, ZIndex = 7}, ps)
                new("UIPadding", {PaddingLeft = UDim.new(0, 8)}, b)
                b.Activated:Connect(function()
                    if pickKey then S[pickKey] = l[2] saveSettings() end
                    refreshAll()
                    closePicker()
                end)
                pickItems[#pickItems + 1] = {btn = b, key = ulower(l[1] .. " " .. l[2])}
            end
            pickSearch:GetPropertyChangedSignal("Text"):Connect(function()
                local q = ulower(pickSearch.Text)
                for _, it in ipairs(pickItems) do it.btn.Visible = q == "" or it.key:find(q, 1, true) ~= nil end
            end)
        end
        pickKey, pickTitle.Text, pickSearch.Text = key, title, ""
        body.Visible = false
        picker.Visible = true
    end

    action(function() return "Ngôn ngữ của tôi: " .. (NAMES[S.myLang] or S.myLang) end,
        function() openPicker("myLang", "Chọn ngôn ngữ của tôi") end)
    action(function() return "Ngôn ngữ gửi đi: " .. (NAMES[S.outLang] or S.outLang) end,
        function() openPicker("outLang", "Chọn ngôn ngữ gửi đi") end)

    action(function() return "Phóng to khung chat  ⦗ + ⦘" end, function() resizeLog(1.15) end)
    action(function() return "Thu nhỏ khung chat  ⦗ - ⦘" end, function() resizeLog(1 / 1.15) end)

    -- MÀU SẮC: đổi giao diện hồng / đen
    action(function() return "Giao diện mẫu: " .. PRESETS[TH.preset][1] end, function()
        TH.preset = TH.preset % #PRESETS + 1
        local p = PRESETS[TH.preset]
        TH.bg, TH.acc, TH.txt, TH.fill = p[2], p[3], p[4], p[5]
        reTheme()
    end)
    action(function() return "Màu viền / nhấn: " .. COLORS[TH.acc][1] end,
        function() TH.acc = TH.acc % #COLORS + 1 reTheme() end)
    action(function() return "Màu chữ: " .. COLORS[TH.txt][1] end,
        function() TH.txt = TH.txt % #COLORS + 1 reTheme() end)
    action(function() return "Màu nền: " .. COLORS[TH.bg][1] end,
        function() TH.bg = TH.bg % #COLORS + 1 reTheme() end)
    action(function() return "Độ đặc của nền: " .. math.floor((1 - FILLS[TH.fill]) * 100) .. "%" end,
        function() TH.fill = TH.fill % #FILLS + 1 reTheme() end)
end

renderLog()
buildMenu()

---------------------------------------------------------------- Dịch tin đến (hàng đợi theo sự kiện, không polling)
local queue, queued = {}, {}
local isProcessing, active, MAX_PAR = false, 0, 2

local function rootOf(model) return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) end
local function distTo(plr)
    local a, b = rootOf(plr and plr.Character), rootOf(LocalPlayer.Character)
    if a and b then return (a.Position - b.Position).Magnitude end
    return math.huge
end

-- Chạy nhiều việc song song rồi gộp kết quả; chờ bằng coroutine
local function join(fns, timeout)
    local n, results = #fns, {}
    local co = coroutine.running()
    local waiting, finished = false, false
    for i, f in ipairs(fns) do
        task.spawn(function()
            results[i] = table.pack(pcall(f))
            n = n - 1
            if n == 0 and not finished then
                finished = true
                if waiting then task.spawn(co) end
            end
        end)
    end
    if n > 0 then
        waiting = true
        task.delay(timeout or 40, function() if not finished then finished = true task.spawn(co) end end)
        coroutine.yield()
    end
    return results
end
local function unpackRes(r) return (r and r[1]) and {r[2], r[3], r[4]} or {} end

local function translateIncoming(text, hint)
    local tl = normLang(S.myLang) or S.myLang
    local sl = quickDetect(text)
    if not sl and hint and not scriptLang(text) and ulen(text) <= 10 then sl = hint end
    local a = sl or "auto"

    local direct, en
    if S.showEN and tl ~= "en" then
        local res = join({
            function() return translate(text, tl, a, nil, hint) end,
            function() return translate(text, "en", a, nil, hint) end,
        }, 40)
        direct, en = unpackRes(res[1]), unpackRes(res[2])
    else
        direct = {translate(text, tl, a, nil, hint)}
        if tl == "en" then en = direct end
    end

    local det = direct[2] or (en and en[2]) or sl
    local result, status = direct[1] or text, direct[3] or "fail"
    if det and sameLang(det, tl) then
        result, status = text, "same"
    elseif S.pivot and tl ~= "en" and det and not sameLang(det, "en")
        and (status ~= "ok" or isRare(tl) or isRare(det)) then
        -- dịch bắc cầu: nguồn -> tiếng Anh -> ngôn ngữ của tôi
        if not en then en = {translate(text, "en", det, nil, hint)} end
        if en[3] == "ok" and en[1] then
            local r, _, st = translate(en[1], tl, "en")
            if st == "ok" then
                result, status = r, "ok"
                cachePivot(text, tl, nil, r, det)
            end
        end
    end
    local enText = en and en[3] == "ok" and en[1] or nil
    if det and sameLang(det, "en") then enText = nil end
    if status == "ok" then result = stripP(result, tl) end
    if enText then enText = stripP(enText, "en") end
    return result, status, enText, det
end

local function process(it)
    local uid = it.plr.UserId
    local result, status, en, det = translateIncoming(it.text, hintFor(uid))
    if det and not scriptLang(it.text) and ulen(it.text) >= 8 then rememberLang(uid, det) end
    addLog(it.plr.DisplayName, it.dist, result, status, it.text, en, det)
end

local function pickNext() -- ưu tiên người gần nhất
    local bi, bd, bt = nil, math.huge, math.huge
    for i, it in ipairs(queue) do
        it.dist = distTo(it.plr)
        if it.dist < bd or (it.dist == bd and it.t < bt) then bi, bd, bt = i, it.dist, it.t end
    end
    if not bi then return nil end
    local it = table.remove(queue, bi)
    queued[it.key] = nil
    return it
end

local function pump()
    if isProcessing or not alive then return end
    isProcessing = true
    while #queue > 0 and active < MAX_PAR do
        local it = pickNext()
        if it and not (S.near and it.dist > S.range) then
            active = active + 1
            task.spawn(function()
                local ok, err = pcall(process, it)
                if not ok then warn("[ChatTranslator] " .. tostring(err)) end
                active = active - 1
                pump()
            end)
        end
    end
    isProcessing = false
end

local seen, seenN = {}, 0
local function onMessage(plr, text, id)
    if not alive or not S.incoming or not plr or plr == LocalPlayer then return end
    if type(text) ~= "string" or not text:find("%S") then return end
    local now = tick()
    local k1 = id and ("id:" .. id) or nil
    local k2 = plr.UserId .. ":" .. text
    if (k1 and seen[k1]) or (seen[k2] and now - seen[k2] < 3) or queued[k2] then return end
    if k1 then seen[k1] = now end
    seen[k2] = now
    seenN = seenN + 1
    if seenN > 300 then seen, seenN = {}, 0 end

    local d = distTo(plr)
    if S.near and d > S.range then return end
    queue[#queue + 1] = {plr = plr, text = text, t = now, dist = d, key = k2}
    queued[k2] = true
    if #queue > 30 then -- quá tải: bỏ tin của người xa nhất
        local wi, wd = 1, -1
        for i, it in ipairs(queue) do
            local dd = distTo(it.plr)
            if dd > wd then wi, wd = i, dd end
        end
        local gone = table.remove(queue, wi)
        if gone then queued[gone.key] = nil end
    end
    pump()
end

---------------------------------------------------------------- Nghe chat
if useTCS then
    local function hookChannel(ch)
        if not ch:IsA("TextChannel") then return end
        track(ch.MessageReceived:Connect(function(msg)
            local src = msg.TextSource
            if src then pcall(onMessage, Players:GetPlayerByUserId(src.UserId), msg.Text, msg.MessageId) end
        end))
    end
    local channels = TextChatService:WaitForChild("TextChannels", 5)
    if channels then
        for _, ch in ipairs(channels:GetChildren()) do hookChannel(ch) end
        track(channels.ChildAdded:Connect(hookChannel))
    end
else
    local function hookPlayer(p) track(p.Chatted:Connect(function(m) pcall(onMessage, p, m) end)) end
    for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
    track(Players.PlayerAdded:Connect(hookPlayer))
end
track(Players.PlayerRemoving:Connect(function(p) PL[p.UserId] = nil end))

---------------------------------------------------------------- Gắn với nút chat của Roblox (theo sự kiện)
local CoreGui
pcall(function() CoreGui = game:GetService("CoreGui") end)

local function robloxChatOpen()
    if CoreGui then
        local ok, v = pcall(function()
            local ec = CoreGui:FindFirstChild("ExperienceChat")
            local layout = ec and ec:FindFirstChild("appLayout")
            local win = layout and layout:FindFirstChild("chatWindow")
            if not win then return nil end
            if ec:IsA("ScreenGui") and not ec.Enabled then return false end
            return layout.Visible and win.Visible
        end)
        if ok and type(v) == "boolean" then return v end
    end
    local ok, v = pcall(function() return game:GetService("StarterGui"):GetCore("ChatActive") end)
    if ok and type(v) == "boolean" then return v end
end

local function applyChatState()
    if not alive then return end
    local open = true
    if S.followChat then
        local st = robloxChatOpen()
        if st ~= nil then open = st end
    end
    if logRoot.Visible ~= open then
        logRoot.Visible = open
        if not open then menu.Visible = false end
    end
end

local chkPending = false
local function scheduleCheck()
    if chkPending then return end
    chkPending = true
    task.delay(0.15, function() chkPending = false applyChatState() end)
end

local chatConns = {}
local function hookChatGui()
    for _, c in ipairs(chatConns) do pcall(function() c:Disconnect() end) end
    chatConns = {}
    local ec = CoreGui and CoreGui:FindFirstChild("ExperienceChat")
    if not ec then return end
    local function watch(inst, prop)
        if inst then chatConns[#chatConns + 1] = inst:GetPropertyChangedSignal(prop):Connect(scheduleCheck) end
    end
    local layout = ec:FindFirstChild("appLayout")
    if ec:IsA("ScreenGui") then watch(ec, "Enabled") end
    watch(layout, "Visible")
    watch(layout and layout:FindFirstChild("chatWindow"), "Visible")
    chatConns[#chatConns + 1] = ec.ChildAdded:Connect(function() hookChatGui() scheduleCheck() end)
end
onCleanup(function() for _, c in ipairs(chatConns) do pcall(function() c:Disconnect() end) end end)
if CoreGui then
    track(CoreGui.ChildAdded:Connect(function(ch)
        if ch.Name == "ExperienceChat" then hookChatGui() scheduleCheck() end
    end))
end
track(UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        scheduleCheck()
    end
end))
hookChatGui()
applyChatState()
