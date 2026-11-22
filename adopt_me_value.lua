--!nocheck
--!nolint
-- Adopt Me Trade Value v3.1
-- Chi hien khi dang mo man hinh TRADE: tong value 2 ben + loi/lo, ghi o tren cung man hinh
-- Gia tri lay tu bang gia Elvebredd (qua ban sao JSON cong khai cap nhat 15 phut/lan)

-- Vi tri o ghi value: thanh ngang ben phai nut Accept, duoi o do ben kia (theo ti le chieu cao nut Accept)
local BOX_TOP = 0.04    -- o ghi value cach dinh cua so trade bao nhieu (ti le chieu cao cua so). Tang de ha xuong

local DATA_URLS = {
    "https://raw.githubusercontent.com/Ricky-Koe-1776/elvebredd-value-api/main/data/values.json",
    "https://elvebredd-value-api.vercel.app/api/pets",
}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local ENV = {}
pcall(function() ENV = getfenv(0) end)
local function X(n) local ok, v = pcall(function() return ENV[n] end) if ok then return v end end
local genv = (X("getgenv") and X("getgenv")()) or _G

-- xoa ban cu
pcall(function() if genv.AMValue and genv.AMValue.destroy then genv.AMValue.destroy() end end)
local function uiParent()
    local gh = X("gethui")
    if gh then local ok, h = pcall(gh) if ok and h then return h end end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end
for _, root in ipairs({ uiParent(), LocalPlayer:FindFirstChild("PlayerGui") }) do
    if root then
        for _, d in ipairs(root:GetDescendants()) do
            if d.Name == "AMValueGui" or d.Name == "AMValueTag" or d.Name == "AMValuePet" then pcall(function() d:Destroy() end) end
        end
    end
end

local AM = { alive = true, conns = {}, petTags = true }
genv.AMValue = AM

---------------------------------------------------------------- TAI DU LIEU
local function httpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 50 then return body end
    local req = X("request") or X("http_request") or (X("syn") and X("syn").request)
    if req then
        local ok2, res = pcall(req, { Url = url, Method = "GET" })
        if ok2 and res and type(res.Body) == "string" and #res.Body > 50 then return res.Body end
    end
    return nil
end

local function norm(s)
    s = tostring(s or ""):lower():gsub("[_%-]", " "):gsub("[^%w ]", ""):gsub("%s+", " ")
    return (s:gsub("^ ", ""):gsub(" $", ""))
end

local ITEMS, INDEX, COMPACT, UPDATED = {}, {}, {}, nil
local function addItem(it)
    if type(it) ~= "table" or not it.name then return end
    table.insert(ITEMS, it)
    for _, k in ipairs({ it.name, it.slug }) do
        local n = norm(k)
        if n ~= "" and not INDEX[n] then INDEX[n] = it end
        local c = n:gsub(" ", "")
        if c ~= "" and not COMPACT[c] then COMPACT[c] = it end
    end
end

local function loadData()
    if type(genv.AMValueCache) == "table" and os.time() - (genv.AMValueCache.t or 0) < 900 then
        ITEMS, INDEX, COMPACT = {}, {}, {}
        for _, it in ipairs(genv.AMValueCache.items) do addItem(it) end
        UPDATED = genv.AMValueCache.t
        return true, "cache"
    end
    for _, url in ipairs(DATA_URLS) do
        local body = httpGet(url)
        if body then
            local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
            if ok and type(data) == "table" then
                local list = data.items or data.pets or data.data or (data[1] and data)
                if type(list) == "table" and #list > 0 then
                    ITEMS, INDEX, COMPACT = {}, {}, {}
                    for _, it in ipairs(list) do addItem(it) end
                    UPDATED = os.time()
                    genv.AMValueCache = { t = UPDATED, items = ITEMS }
                    return true, url
                end
            end
        end
    end
    return false, "khong tai duoc"
end

---------------------------------------------------------------- GIA TRI
-- age: "default" | "neon" | "mega"; potion: "base" | "nopotion" | "ride" | "fly" | "fly_ride"
local function getVal(it, age, potion)
    if type(it.values) == "table" then
        local a = it.values[age or "default"]
        if type(a) == "table" then
            local v = a[potion or "base"] or a.base or a.nopotion
            if type(v) == "number" then return v end
        elseif type(a) == "number" then
            return a
        end
    end
    if type(it.value) == "number" and (age == nil or age == "default") then return it.value end
    return nil
end

local function fmt(v)
    if type(v) ~= "number" then return "?" end
    if v >= 100 then
        local s = tostring(math.floor(v + 0.5))
        local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
        return (out:gsub("^,", ""))
    elseif v >= 1 then
        return (string.format("%.1f", v):gsub("%.0$", ""))
    end
    return (string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", ""))
end

local function isPet(it)
    return tostring(it.type or ""):lower():find("pet", 1, true) ~= nil
end

-- "Neon Dog", "Mega Neon Dog", "MFR Dog", "Dog"... -> item, age, potion
local function lookup(text)
    local n = norm(text)
    if n == "" then return nil end
    local age, potion = nil, nil
    local function strip(prefix)
        if n:sub(1, #prefix + 1) == prefix .. " " then n = n:sub(#prefix + 2) return true end
        return false
    end
    if strip("mega neon") or strip("mega") then age = "mega"
    elseif strip("neon") then age = "neon" end
    local p = n:match("^([mnfr]+) ")
    if p and #p <= 3 and not INDEX[n] then
        if p:find("m") then age = "mega" elseif p:find("n") then age = age or "neon" end
        local f, r = p:find("f") ~= nil, p:find("r") ~= nil
        potion = (f and r and "fly_ride") or (f and "fly") or (r and "ride") or nil
        n = n:sub(#p + 2)
    end
    local it = INDEX[n]
    if not it then return nil end
    return it, age, potion
end

-- Chu ngan de ghi tren dau pet / tren o do vat
local function shortText(it, age, potion)
    if age or potion then
        local v = getVal(it, age or "default", potion or "base")
        local tag = (age == "mega" and "M " or age == "neon" and "N " or "")
            .. (potion == "fly_ride" and "FR " or potion == "fly" and "F " or potion == "ride" and "R " or "")
        return tag .. fmt(v)
    end
    if isPet(it) then
        local d, nv, m = getVal(it, "default"), getVal(it, "neon"), getVal(it, "mega")
        local s = fmt(d)
        if nv then s = s .. " | N " .. fmt(nv) end
        if m then s = s .. " | M " .. fmt(m) end
        return s
    end
    return fmt(getVal(it, "default"))
end

-- Dong day du cho o tim kiem
local function fullText(it)
    if not isPet(it) then
        return it.name .. ": " .. fmt(getVal(it, "default"))
    end
    local lines = { it.name .. " (" .. tostring(it.rarity or "?") .. ")" }
    for _, age in ipairs({ "default", "neon", "mega" }) do
        local a = it.values and it.values[age]
        if type(a) == "table" then
            table.insert(lines, string.format("%s: thuong %s | R %s | F %s | FR %s",
                age == "default" and "Thuong" or age == "neon" and "Neon" or "Mega",
                fmt(a.nopotion or a.base), fmt(a.ride), fmt(a.fly), fmt(a.fly_ride)))
        end
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------- DOC DU LIEU TRADE (nghe su kien game)
local RS = game:GetService("ReplicatedStorage")
local TRADE, TRADE_T = nil, 0
local SEEN_KEYS = {}

local function findTrade(t, depth, seen)
    if type(t) ~= "table" or depth > 6 or seen[t] then return nil end
    seen[t] = true
    if type(t.sender_offer) == "table" or type(t.recipient_offer) == "table" then return t end
    for _, v in pairs(t) do
        local r = findTrade(v, depth + 1, seen)
        if r then return r end
    end
end
local function onNet(...)
    local args = { ... }
    for i = 1, #args do
        local a = args[i]
        if type(a) == "string" then
            SEEN_KEYS[a] = os.clock()
            -- "trade" kem gia tri khong phai bang -> trade da ket thuc
            if a == "trade" and i < #args and type(args[i + 1]) ~= "table" then TRADE = nil end
        elseif type(a) == "table" then
            local t = findTrade(a, 0, {})
            if t then TRADE, TRADE_T = t, os.clock() end
        end
    end
end
local hooked = {}
local function hookRemote(r)
    if hooked[r] or not r:IsA("RemoteEvent") then return end
    hooked[r] = true
    pcall(function() table.insert(AM.conns, r.OnClientEvent:Connect(onNet)) end)
end
pcall(function()
    for _, d in ipairs(RS:GetDescendants()) do hookRemote(d) end
    table.insert(AM.conns, RS.DescendantAdded:Connect(hookRemote))
end)
-- neu script farm dang chay thi lay luon du lieu no da nghe duoc
local function tradeFromFarm()
    local n = genv.AMFarmNET
    if type(n) == "table" and type(n.trade) == "table" then return findTrade(n.trade, 0, {}) end
end

---------------------------------------------------------------- TEN THAT CUA MON DO (ma trong game -> ten hien thi)
-- Ma mon trong trade (vd "pet_rock", "winter_2021_..." ) khac ten tren Elvebredd -> doc bang ten cua chinh game
local KIND_NAME, KIND_CAT = {}, {}
local DB_STATE = "chua tai"
local function withTimeout(sec, fn)
    local done, res = false, nil
    task.spawn(function() local ok, r = pcall(fn) if ok then res = r end done = true end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < sec do task.wait(0.1) end
    return res
end
local function loadInventoryDB()
    DB_STATE = "dang tai"
    local setid = X("setthreadidentity") or X("setidentity") or (X("syn") and X("syn").set_thread_identity)
    local db = withTimeout(10, function()
        if setid then pcall(setid, 2) end
        local f = RS:FindFirstChild("Fsys")
        if not f then return nil end
        local load = require(f).load
        return load("InventoryDB")
    end)
    if type(db) ~= "table" then DB_STATE = "khong doc duoc" return end
    local n = 0
    for cat, tbl in pairs(db) do
        if type(tbl) == "table" then
            for kind, d in pairs(tbl) do
                if type(kind) == "string" and type(d) == "table" and type(d.name) == "string" then
                    KIND_NAME[kind] = d.name
                    KIND_CAT[kind] = tostring(cat)
                    n = n + 1
                end
            end
        end
    end
    DB_STATE = n .. " ten"
end

local RESOLVED, UNKNOWN = {}, {}
local function tryName(s)
    if not s or s == "" then return nil end
    local n = norm(s)
    if INDEX[n] then return INDEX[n] end
    local c = n:gsub(" ", "")
    if COMPACT[c] then return COMPACT[c] end
    local it = lookup(s)
    if it then return it end
    -- bo so / nam (vd "_2021"), bo tien to su kien o dau, bo duoi o cuoi
    local words = {}
    for w in n:gmatch("%S+") do if not w:match("^%d+$") then table.insert(words, w) end end
    -- thu cum tu dai nhat truoc (vd "winter 2021 frost fury" -> "frost fury")
    for len = #words, 1, -1 do
        for i = 1, #words - len + 1 do
            local sub = table.concat(words, " ", i, i + len - 1)
            if #sub >= 3 then
                local hit = INDEX[sub] or COMPACT[(sub:gsub(" ", ""))]
                if hit then return hit end
            end
        end
    end
    return nil
end
local function resolveKind(kind)
    kind = tostring(kind)
    if RESOLVED[kind] ~= nil then return RESOLVED[kind] or nil end
    local it = tryName(KIND_NAME[kind]) or tryName(kind)
    if it then RESOLVED[kind] = it UNKNOWN[kind] = nil
    else
        UNKNOWN[kind] = KIND_NAME[kind] or true
        -- chua co ten tu game thi chua ghi nho la "khong co" de lan sau thu lai
        if next(KIND_NAME) then RESOLVED[kind] = false end
    end
    return it
end

---------------------------------------------------------------- MAN HINH TRADE CO DANG MO?
local function shownGui(o)
    while o and o:IsA("GuiObject") do
        if not o.Visible then return false end
        o = o.Parent
    end
    return not (o and o:IsA("ScreenGui") and not o.Enabled)
end
local function btnText(b)
    local t = (b:IsA("TextButton") and b.Text or "")
    for _, d in ipairs(b:GetDescendants()) do
        if d:IsA("TextLabel") then t = t .. " " .. d.Text end
    end
    return t:lower()
end
-- Tra ve: ScreenGui trade, nut Accept (de ghi value ngay ben phai no)
local function tradeWindowOpen()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, g in ipairs(pg:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "AMValueGui" then
            local n = g.Name:lower()
            local named = n:find("trade", 1, true) and not n:find("history", 1, true)
                and not n:find("license", 1, true) and not n:find("request", 1, true)
            local accept, decline, tradeWord
            for _, b in ipairs(g:GetDescendants()) do
                if b:IsA("TextLabel") and b.Text:upper():gsub("%s", "") == "TRADE" and shownGui(b) then tradeWord = true end
                if b:IsA("GuiButton") and b.Name ~= "AMValueCopy" then
                    local t = btnText(b)
                    if t:find("accept", 1, true) and shownGui(b)
                        and (not accept or b.AbsolutePosition.Y + b.AbsoluteSize.Y > accept.AbsolutePosition.Y + accept.AbsoluteSize.Y) then
                        accept = b
                    elseif t:find("decline", 1, true) and shownGui(b) then decline = b end
                end
            end
            -- khong nham voi bang loi moi trade (cung co Accept/Decline)
            if accept and (named or (decline and tradeWord)) then return g, accept end
        end
    end
    return nil
end

---------------------------------------------------------------- TINH GIA 1 BEN
local function isMe(p)
    if p == LocalPlayer then return true end
    if type(p) == "string" then return p == LocalPlayer.Name end
    if type(p) == "table" then return p.Name == LocalPlayer.Name or p.name == LocalPlayer.Name end
    return false
end

local function itemValue(entry)
    if type(entry) ~= "table" then return nil, "?" end
    local kind = entry.kind or entry.id or entry.item_id or entry.name
    local props = type(entry.properties) == "table" and entry.properties or entry
    local it = kind and resolveKind(kind)
    local age = (props.mega_neon and "mega") or (props.neon and "neon") or "default"
    local f, r = props.flyable == true, props.rideable == true
    local potion = (f and r and "fly_ride") or (f and "fly") or (r and "ride") or "nopotion"
    local tag = (age == "mega" and "M" or age == "neon" and "N" or "") .. (f and "F" or "") .. (r and "R" or "")
    if not it then
        local shown = KIND_NAME[tostring(kind)] or tostring(kind)
        return nil, (tag ~= "" and tag .. " " or "") .. shown .. " (?)"
    end
    local v = isPet(it) and getVal(it, age, potion) or getVal(it, "default")
    return v, (tag ~= "" and tag .. " " or "") .. it.name .. " " .. fmt(v)
end

local function sideValue(offer)
    local total, lines, unknown = 0, {}, 0
    local items = {}
    if type(offer) == "table" then
        if type(offer.items) == "table" then items = offer.items
        elseif #offer > 0 then items = offer end
    end
    for _, e in pairs(items) do
        if type(e) == "table" then
            local v, txt = itemValue(e)
            if v then total = total + v else unknown = unknown + 1 end
            table.insert(lines, txt)
        end
    end
    return total, lines, unknown
end

---------------------------------------------------------------- GIAO DIEN (tren cung man hinh)
local gui = Instance.new("ScreenGui")
gui.Name = "AMValueGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = uiParent()

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 560, 0, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Position = UDim2.new(0.5, -280, 0, 6)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local pad = Instance.new("UIPadding", panel)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.RichText = true
title.Text = ""
title.Parent = panel

local detail = Instance.new("TextLabel")
detail.Size = UDim2.new(1, 0, 0, 0)
detail.Position = UDim2.new(0, 0, 0, 28)
detail.AutomaticSize = Enum.AutomaticSize.Y
detail.BackgroundTransparency = 1
detail.Font = Enum.Font.Gotham
detail.TextSize = 12
detail.TextColor3 = Color3.fromRGB(210, 210, 210)
detail.TextXAlignment = Enum.TextXAlignment.Left
detail.TextYAlignment = Enum.TextYAlignment.Top
detail.TextWrapped = true
detail.Text = ""
detail.Parent = panel

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0, 60, 0, 20)
copyBtn.Position = UDim2.new(1, -60, 0, 3)
copyBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
copyBtn.TextColor3 = Color3.new(1, 1, 1)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 11
copyBtn.Text = "Copy log"
copyBtn.Parent = panel
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 5)

local function dumpTable(t, depth, out, seen)
    if depth > 4 or seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
        table.insert(out, string.rep("  ", depth) .. tostring(k) .. " = " .. (type(v) == "table" and "{" or tostring(v)))
        if type(v) == "table" then dumpTable(v, depth + 1, out, seen) end
        if #out > 300 then return end
    end
end
function AM.copyLog()
    local out = { "AMValue v3.1 | so mon: " .. #ITEMS .. " | ten game: " .. DB_STATE .. " | trade: " .. tostring(TRADE ~= nil) }
    table.insert(out, "Vi tri: " .. tostring(AM.anchorInfo))
    for k, v in pairs(UNKNOWN) do table.insert(out, "KHONG TIM THAY: " .. k .. " -> " .. tostring(v)) end
    if TRADE then dumpTable(TRADE, 0, out, {}) else
        table.insert(out, "Su kien da nghe:")
        for k in pairs(SEEN_KEYS) do if #out < 200 then table.insert(out, "  " .. k) end end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then for _, g in ipairs(pg:GetChildren()) do
            if g.Name:lower():find("trade", 1, true) then table.insert(out, "GUI: " .. g.Name) end
        end end
    end
    local sc = X("setclipboard") or X("toclipboard")
    if sc then pcall(sc, table.concat(out, "\n")) end
end
table.insert(AM.conns, copyBtn.MouseButton1Click:Connect(function() AM.copyLog() end))

function AM.destroy()
    AM.alive = false
    for _, c in ipairs(AM.conns) do pcall(function() c:Disconnect() end) end
    pcall(function() gui:Destroy() end)
    pcall(function() if box then box:Destroy() end end)
    for _, bb in pairs(petTag) do pcall(function() bb:Destroy() end) end
    if genv.AMValue == AM then genv.AMValue = nil end
end

---------------------------------------------------------------- CAP NHAT
---------------------------------------------------------------- O GHI VALUE TRONG CUA SO TRADE (ben phai nut Accept)
local box
local function makeBox(g)
    if box and box.Parent == gui then return box end
    if box then pcall(function() box:Destroy() end) end
    box = Instance.new("TextLabel")
    box.Name = "AMValueTag"
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    box.BackgroundTransparency = 0.1
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Font = Enum.Font.GothamBold
    box.RichText = true
    box.TextScaled = true
    box.ZIndex = 50
    box.Text = ""
    box.Parent = gui -- gan vao giao dien rieng (khong bi UIScale cua game lam lech)
    Instance.new("UICorner", box).CornerRadius = UDim.new(1, 0)
    local lim = Instance.new("UITextSizeConstraint", box)
    lim.MaxTextSize = 16
    local pad = Instance.new("UIPadding", box)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
    -- dong phia duoi: noi loi/lo kieu "tho"
    local mood = Instance.new("TextLabel")
    mood.Name = "AMValueMood"
    mood.BackgroundTransparency = 1
    mood.Size = UDim2.new(1, 0, 1, 0)
    mood.Position = UDim2.new(0, 0, 1, 1)
    mood.Font = Enum.Font.SourceSansBold -- font co du dau tieng Viet
    mood.TextScaled = true
    mood.TextStrokeTransparency = 0.2
    mood.TextColor3 = Color3.new(1, 1, 1)
    mood.ZIndex = 51
    mood.Text = ""
    mood.Parent = box
    Instance.new("UITextSizeConstraint", mood).MaxTextSize = 18
    -- nut copy nho goc tren phai
    local c = copyBtn:Clone()
    c.Name = "AMValueCopy"
    c.Size = UDim2.new(0, 34, 0, 14)
    c.Position = UDim2.new(1, -34, 0, -16)
    c.TextSize = 9
    c.Text = "Copy"
    c.ZIndex = 51
    c.Parent = box
    c.MouseButton1Click:Connect(function()
        pcall(function() AM.copyLog() end)
        c.Text = "Da copy"
        task.delay(1.5, function() if c.Parent then c.Text = "Copy" end end)
    end)
    return box
end
local function placeBox(g, accept)
    local b = makeBox(g)
    -- khung cua so trade = to tien lon nhat chua nut Accept
    local win = accept
    local o = accept.Parent
    while o and o:IsA("GuiObject") do
        if o.AbsoluteSize.X > win.AbsoluteSize.X * 1.5 then win = o end
        o = o.Parent
    end
    -- giao dien rieng bo qua thanh tren (IgnoreGuiInset); cong lai neu cua so trade khong bo qua
    local dy = 0
    if not g.IgnoreGuiInset then
        local ok, inset = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
        if ok and inset then dy = inset.Y end
    end
    local wp, ws = win.AbsolutePosition, win.AbsoluteSize
    local w = math.clamp(ws.X * 0.5, 120, 320)
    local hgt = math.clamp(ws.Y * 0.085, 22, 40)
    local x = wp.X + ws.X / 2 - w / 2
    local y = wp.Y + ws.Y * BOX_TOP + dy
    b.Position = UDim2.fromOffset(x, y)
    b.Size = UDim2.fromOffset(w, hgt)
    b.Visible = true
    AM.anchorInfo = string.format("win=%s (%d,%d %dx%d) inset=%s", win:GetFullName(),
        wp.X, wp.Y, ws.X, ws.Y, tostring(g.IgnoreGuiInset))
    return b
end

---------------------------------------------------------------- NHAN VALUE TREN DAU PET (luc dang trade / xem pet)
local petTag = {}
local function headPart(m)
    return m:FindFirstChild("Head") or m:FindFirstChild("head")
        or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
end
local function hasNeon(m)
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") and d.Material == Enum.Material.Neon then return true end
    end
    return false
end
-- tim ten loai cua 1 mo hinh pet (ten mo hinh / thuoc tinh / StringValue con)
local function petItem(m)
    local cands = { m.Name }
    pcall(function()
        for k, v in pairs(m:GetAttributes()) do
            if type(v) == "string" then table.insert(cands, v) end
            if type(k) == "string" then table.insert(cands, k) end
        end
    end)
    for _, d in ipairs(m:GetChildren()) do
        if d:IsA("StringValue") then table.insert(cands, d.Value) table.insert(cands, d.Name) end
    end
    for _, c in ipairs(cands) do
        if type(c) == "string" and #c >= 3 then
            local it = resolveKind(c)
            if it and isPet(it) then return it end
        end
    end
end
-- gom cac mo hinh pet dang hien ra (chi quet noi nong, khong quet ca workspace)
local function collectPetModels()
    local out = {}
    local char = LocalPlayer.Character
    local function take(m) if m:IsA("Model") and m ~= char then out[#out + 1] = m end end
    local pets = workspace:FindFirstChild("Pets")
    if pets then for _, m in ipairs(pets:GetChildren()) do take(m) end end
    for _, m in ipairs(workspace:GetChildren()) do take(m) end
    local cam = workspace.CurrentCamera
    if cam then for _, m in ipairs(cam:GetChildren()) do take(m) end end
    return out
end
local function clearPetTags()
    for m, bb in pairs(petTag) do pcall(function() bb:Destroy() end) petTag[m] = nil end
end
local function updatePets(tradeOpen)
    if not (AM.petTags and tradeOpen and #ITEMS > 0) then clearPetTags() return end
    local seen = {}
    for _, m in ipairs(collectPetModels()) do
        local part = headPart(m)
        local it = part and petItem(m)
        if it then
            seen[m] = true
            local neon = hasNeon(m)
            local age = neon and "neon" or nil
            local bb = petTag[m]
            if not bb or not bb.Parent then
                bb = Instance.new("BillboardGui")
                bb.Name = "AMValuePet"
                bb.Size = UDim2.new(0, 170, 0, 20)
                bb.StudsOffset = Vector3.new(0, 2.6, 0)
                bb.AlwaysOnTop = true
                bb.MaxDistance = 80
                local t = Instance.new("TextLabel")
                t.Size = UDim2.new(1, 0, 1, 0)
                t.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
                t.BackgroundTransparency = 0.3
                t.TextColor3 = Color3.fromRGB(255, 230, 120)
                t.Font = Enum.Font.GothamBold
                t.TextScaled = true
                t.Parent = bb
                Instance.new("UICorner", t).CornerRadius = UDim.new(0, 6)
                local lim = Instance.new("UITextSizeConstraint", t) lim.MaxTextSize = 15
                bb.Parent = gui
                petTag[m] = bb
            end
            bb.Adornee = part
            bb.TextLabel.Text = it.name .. ": " .. shortText(it, age, nil)
        end
    end
    for m, bb in pairs(petTag) do
        if not seen[m] then pcall(function() bb:Destroy() end) petTag[m] = nil end
    end
end

-- cau "tho" theo muc loi/lo (chu co dau viet bang ma \u{..} de file van la ASCII, Roblox hien dung dau) (r = chenh lech / value lon hon, tu -1 den 1)
local MOODS = {
    { 0.5,  "NGON VCL, CH\u{1ED0}T L\u{1EB8} \u{110}I",        Color3.fromRGB(0, 255, 90) },
    { 0.15, "L\u{1EDC}I VL",                      Color3.fromRGB(90, 255, 120) },
    { 0.02, "L\u{1EDD}i t\u{ED}, c\u{169}ng \u{111}\u{1B0}\u{1EE3}c vl",          Color3.fromRGB(170, 255, 170) },
    { -0.02, "Hu\u{1EC1} m\u{1EB9} r\u{1ED3}i",                 Color3.fromRGB(230, 230, 230) },
    { -0.15, "L\u{1ED7} t\u{ED}, c\u{E2}n nh\u{1EAF}c \u{111}i cha",     Color3.fromRGB(255, 170, 170) },
    { -0.5, "L\u{1ED6} VL, NGU \u{C0}",                Color3.fromRGB(255, 90, 90) },
    { -2,   "\u{110}M B\u{1ECA} L\u{1EEA}A R\u{1ED2}I, \u{110}\u{1EEA}NG ACCEPT",  Color3.fromRGB(255, 30, 30) },
}
local function setMood(b, r)
    local m = b:FindFirstChild("AMValueMood")
    if not m then return end
    if not r then m.Text = "" return end
    for _, x in ipairs(MOODS) do
        if r >= x[1] then m.Text = x[2] m.TextColor3 = x[3] return end
    end
end

local wasOpen = false
local function update()
    local g, accept = tradeWindowOpen()
    updatePets(g ~= nil)
    if not g then
        if wasOpen then TRADE = nil end -- dong trade -> xoa du lieu cu
        wasOpen = false
        panel.Visible = false
        if box then box.Visible = false end
        return
    end
    wasOpen = true
    local b = placeBox(g, accept)
    panel.Visible = false
    if #ITEMS == 0 then
        b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        b.Text = "..."
        setMood(b, nil)
        return
    end
    local t = TRADE or tradeFromFarm()
    if not t then
        b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        b.Text = "?"
        setMood(b, nil)
        local cb = b:FindFirstChild("AMValueCopy")
        if cb then cb.Visible = true end
        return
    end
    local mineOffer, theirOffer = t.sender_offer, t.recipient_offer
    local known = isMe(t.sender) or isMe(t.recipient)
    if isMe(t.recipient) then mineOffer, theirOffer = t.recipient_offer, t.sender_offer end
    local myV, myL, myU = sideValue(mineOffer)
    local thV, thL, thU = sideValue(theirOffer)
    local diff = thV - myV
    local verdict
    local base = math.max(myV, thV, 1)
    if math.abs(diff) / base < 0.05 then verdict = '<font color="#FFD866">CONG BANG</font>'
    elseif diff > 0 then verdict = '<font color="#7CFC7C">LOI +' .. fmt(diff) .. '</font>'
    else verdict = '<font color="#FF6B6B">LO -' .. fmt(-diff) .. '</font>' end
    -- mau nen: loi -> xanh, lo -> do; chenh cang nhieu mau cang dam. Khong ghi chu.
    local r = math.clamp(diff / base, -1, 1)
    local grey = Color3.fromRGB(45, 45, 55)
    if math.abs(r) < 0.02 then
        b.BackgroundColor3 = grey
    else
        local k = 0.3 + 0.7 * (math.abs(r) ^ 0.6)
        b.BackgroundColor3 = grey:Lerp(r > 0 and Color3.fromRGB(0, 210, 70) or Color3.fromRGB(230, 30, 30), k)
    end
    -- chi ghi 1 so: value ben kia (mau nen cho biet loi/lo so voi ben minh)
    -- so chenh lech co dau: loi +X, lo -X
    local dstr = ""
    if math.abs(diff) >= 0.001 then dstr = "  " .. (diff > 0 and "+" or "-") .. fmt(math.abs(diff)) end
    b.Text = fmt(thV) .. dstr .. ((myU + thU > 0) and "?" or "")
    setMood(b, (math.abs(r) < 0.02) and 0 or r)
    local cb = b:FindFirstChild("AMValueCopy")
    if cb then cb.Visible = (myU + thU > 0) end -- nut Copy chi hien khi co mon chua co gia
    title.Text = (known and "Ban: " or "Ben 1: ") .. fmt(myV) .. "   |   " .. (known and "Ho: " or "Ben 2: ") .. fmt(thV) .. "   =>   " .. verdict
    local function list(l, u)
        local s = #l > 0 and table.concat(l, ", ") or "(trong)"
        if u > 0 then s = s .. "  [" .. u .. " mon khong co gia]" end
        return s
    end
    detail.Text = (known and "Ban dua: " or "Ben 1: ") .. list(myL, myU) .. "\n" .. (known and "Ho dua: " or "Ben 2: ") .. list(thL, thU)
end

---------------------------------------------------------------- CHAY
task.spawn(loadInventoryDB)
task.spawn(function()
    local ok, src = loadData()
    if ok then print("[AMValue] da tai " .. #ITEMS .. " mon tu " .. tostring(src))
    else
        task.wait(5)
        ok = loadData()
        if not ok then warn("[AMValue] khong tai duoc bang gia (executor can game:HttpGet / request)") end
    end
end)
task.spawn(function()
    while AM.alive do
        pcall(update)
        task.wait(0.5)
    end
end)
print("[AMValue] v3.1 dang chay - mo man hinh trade de xem tong value")
