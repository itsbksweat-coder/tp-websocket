local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local WS_URL = "wss://tp-websocket.xyzcheatz.workers.dev/ws1"

local connect =
    (WebSocket and WebSocket.connect)
    or (websocket and websocket.connect)
    or (syn and syn.websocket and syn.websocket.connect)

assert(connect, "No WebSocket API found")

local activeBlackGui

local function hideBlackTeleportScreen()
    if activeBlackGui then
        pcall(function()
            activeBlackGui:Destroy()
        end)
        activeBlackGui = nil
    end
end

local function showBlackTeleportScreen()
    hideBlackTeleportScreen()

    local gui = Instance.new("ScreenGui")
    gui.Name = "TPBlackScreen"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local black = Instance.new("Frame")
    black.Name = "Black"
    black.Size = UDim2.fromScale(1, 1)
    black.Position = UDim2.fromScale(0, 0)
    black.BackgroundColor3 = Color3.new(0, 0, 0)
    black.BackgroundTransparency = 0
    black.BorderSizePixel = 0
    black.ZIndex = 100
    black.Parent = gui

    local parent
    if gethui then
        local ok, result = pcall(gethui)
        if ok and result then
            parent = result
        end
    end

    parent = parent or LocalPlayer:WaitForChild("PlayerGui")
    gui.Parent = parent
    activeBlackGui = gui

    -- Ask Roblox to use the same all-black GUI during the teleport transition too.
    pcall(function()
        TeleportService:SetTeleportGui(gui:Clone())
    end)

    return gui
end

local function collectOwnItems()
    local items = {}
    local seen = {}

    local function add(name, extra)
        name = tostring(name or "")
        if name == "" then
            return
        end

        local key = (name .. "|" .. tostring(extra or "")):lower()
        if seen[key] then
            return
        end
        seen[key] = true

        local item = { name = name }
        if extra and extra ~= "" then
            item.extra = tostring(extra)
        end
        items[#items + 1] = item
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, obj in ipairs(backpack:GetChildren()) do
            if obj:IsA("Tool") then
                add(obj.Name, "Backpack")
            end
        end
    end

    local character = LocalPlayer.Character
    if character then
        for _, obj in ipairs(character:GetChildren()) do
            if obj:IsA("Tool") then
                add(obj.Name, "Equipped")
            end
        end
    end

    -- Optional: the receiver may provide its own game-specific list.
    if getgenv and type(getgenv().TPGetStuff) == "function" then
        local ok, custom = pcall(getgenv().TPGetStuff)
        if ok and type(custom) == "table" then
            for _, entry in ipairs(custom) do
                if type(entry) == "table" then
                    add(entry.name, entry.extra)
                else
                    add(entry)
                end
            end
        end
    end

    return items
end

local ok, ws = pcall(function()
    return connect(WS_URL)
end)

if not ok then
    warn("[TP RECEIVER] Connection failed:", ws)
    return
end

if getgenv then
    getgenv().TPReceiverWS = ws
end

local function send(data)
    local success, err = pcall(function()
        ws:Send(HttpService:JSONEncode(data))
    end)

    if not success then
        warn("[TP RECEIVER] Send failed:", err)
    end
end

local function register(kind)
    send({
        type = kind or "register",
        username = LocalPlayer.Name,
        displayName = LocalPlayer.DisplayName,
        items = collectOwnItems()
    })
end

local function handleMessage(message)
    local success, data = pcall(function()
        return HttpService:JSONDecode(message)
    end)

    if not success or type(data) ~= "table" then
        return
    end

    if data.type == "connected" then
        register("register")
        print("[TP RECEIVER] Ready/registering as", LocalPlayer.Name)
        return
    end

    if data.type == "registered" then
        print("[TP RECEIVER] Registered")
        return
    end

    if data.type ~= "join" then
        return
    end

    if data.target
        and tostring(data.target):lower() ~= LocalPlayer.Name:lower() then
        return
    end

    local placeId = tonumber(data.placeId)
    local jobId = tostring(data.jobId or "")

    if not placeId or jobId == "" then
        warn("[TP RECEIVER] Invalid teleport request")
        return
    end

    showBlackTeleportScreen()
    task.wait()

    local tpOk, tpErr = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
    end)

    if not tpOk then
        hideBlackTeleportScreen()
        warn("[TP RECEIVER] Teleport failed:", tpErr)
    end
end

if ws.OnMessage then
    ws.OnMessage:Connect(handleMessage)
elseif ws.Message then
    ws.Message:Connect(handleMessage)
else
    warn("[TP RECEIVER] No message event found")
end

if ws.OnClose then
    ws.OnClose:Connect(function()
        warn("[TP RECEIVER] WebSocket disconnected")
    end)
end

task.spawn(function()
    while true do
        task.wait(15)
        register("update")
    end
end)
