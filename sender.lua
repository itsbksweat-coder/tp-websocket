local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local WS_URL = "wss://tp-websocket.xyzcheatz.workers.dev/ws2"

local ALLOWED = {
    ["dbhbsvsvsv"] = true,
    ["carlosprvv"] = true
}

if not ALLOWED[LocalPlayer.Name:lower()] then
    warn("[TP] User not allowed:", LocalPlayer.Name)
    return
end

local connect =
    (WebSocket and WebSocket.connect)
    or (websocket and websocket.connect)
    or (syn and syn.websocket and syn.websocket.connect)

assert(connect, "No WebSocket API found")

local old = (getgenv and getgenv().TPSelectorGui) or nil
if old then
    pcall(function()
        old:Destroy()
    end)
end

local ok, ws = pcall(function()
    return connect(WS_URL)
end)

if not ok then
    warn("[TP] Connection failed:", ws)
    return
end

local guiParent
if gethui then
    guiParent = gethui()
else
    guiParent = LocalPlayer:WaitForChild("PlayerGui")
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TPSelector"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiParent

if getgenv then
    getgenv().TPSelectorGui = ScreenGui
    getgenv().TPSenderWS = ws
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(330, 390)
Main.Position = UDim2.new(0.5, -165, 0.5, -195)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(235, 235, 235)
Stroke.Thickness = 1
Stroke.Transparency = 0.35
Stroke.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 48)
Header.BackgroundTransparency = 1
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Position = UDim2.fromOffset(14, 0)
Title.BackgroundTransparency = 1
Title.Text = "TP Receiver"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -28, 0, 24)
Status.Position = UDim2.fromOffset(14, 47)
Status.BackgroundTransparency = 1
Status.Text = "Connected - loading receivers..."
Status.TextColor3 = Color3.fromRGB(175, 175, 175)
Status.TextSize = 12
Status.Font = Enum.Font.Gotham
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Main

local ListPage = Instance.new("Frame")
ListPage.Name = "ListPage"
ListPage.Size = UDim2.new(1, -28, 1, -92)
ListPage.Position = UDim2.fromOffset(14, 78)
ListPage.BackgroundTransparency = 1
ListPage.Parent = Main

local Refresh = Instance.new("TextButton")
Refresh.Size = UDim2.new(1, 0, 0, 38)
Refresh.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
Refresh.TextColor3 = Color3.fromRGB(10, 10, 10)
Refresh.Text = "Refresh"
Refresh.TextSize = 14
Refresh.Font = Enum.Font.GothamBold
Refresh.AutoButtonColor = true
Refresh.Parent = ListPage

local RefreshCorner = Instance.new("UICorner")
RefreshCorner.CornerRadius = UDim.new(0, 8)
RefreshCorner.Parent = Refresh

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Size = UDim2.new(1, 0, 1, -48)
PlayerList.Position = UDim2.fromOffset(0, 48)
PlayerList.BackgroundTransparency = 1
PlayerList.BorderSizePixel = 0
PlayerList.ScrollBarThickness = 4
PlayerList.CanvasSize = UDim2.new()
PlayerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlayerList.Parent = ListPage

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 7)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = PlayerList

local Empty = Instance.new("TextLabel")
Empty.Size = UDim2.new(1, 0, 0, 50)
Empty.BackgroundTransparency = 1
Empty.Text = "No receivers connected"
Empty.TextColor3 = Color3.fromRGB(150, 150, 150)
Empty.TextSize = 14
Empty.Font = Enum.Font.Gotham
Empty.LayoutOrder = -1000
Empty.Parent = PlayerList

local DetailPage = Instance.new("Frame")
DetailPage.Name = "DetailPage"
DetailPage.Size = UDim2.new(1, -28, 1, -92)
DetailPage.Position = UDim2.fromOffset(14, 78)
DetailPage.BackgroundTransparency = 1
DetailPage.Visible = false
DetailPage.Parent = Main

local SelectedName = Instance.new("TextLabel")
SelectedName.Size = UDim2.new(1, 0, 0, 45)
SelectedName.BackgroundTransparency = 1
SelectedName.TextColor3 = Color3.new(1, 1, 1)
SelectedName.TextSize = 18
SelectedName.Font = Enum.Font.GothamBold
SelectedName.TextXAlignment = Enum.TextXAlignment.Left
SelectedName.TextWrapped = true
SelectedName.Parent = DetailPage

local StuffTitle = Instance.new("TextLabel")
StuffTitle.Size = UDim2.new(1, 0, 0, 25)
StuffTitle.Position = UDim2.fromOffset(0, 48)
StuffTitle.BackgroundTransparency = 1
StuffTitle.Text = "Stuff"
StuffTitle.TextColor3 = Color3.fromRGB(185, 185, 185)
StuffTitle.TextSize = 13
StuffTitle.Font = Enum.Font.GothamBold
StuffTitle.TextXAlignment = Enum.TextXAlignment.Left
StuffTitle.Parent = DetailPage

local StuffList = Instance.new("ScrollingFrame")
StuffList.Size = UDim2.new(1, 0, 1, -140)
StuffList.Position = UDim2.fromOffset(0, 75)
StuffList.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
StuffList.BorderSizePixel = 0
StuffList.ScrollBarThickness = 4
StuffList.CanvasSize = UDim2.new()
StuffList.AutomaticCanvasSize = Enum.AutomaticSize.Y
StuffList.Parent = DetailPage

local StuffCorner = Instance.new("UICorner")
StuffCorner.CornerRadius = UDim.new(0, 8)
StuffCorner.Parent = StuffList

local StuffPadding = Instance.new("UIPadding")
StuffPadding.PaddingTop = UDim.new(0, 8)
StuffPadding.PaddingBottom = UDim.new(0, 8)
StuffPadding.PaddingLeft = UDim.new(0, 8)
StuffPadding.PaddingRight = UDim.new(0, 8)
StuffPadding.Parent = StuffList

local StuffLayout = Instance.new("UIListLayout")
StuffLayout.Padding = UDim.new(0, 5)
StuffLayout.Parent = StuffList

local Buttons = Instance.new("Frame")
Buttons.Size = UDim2.new(1, 0, 0, 48)
Buttons.Position = UDim2.new(0, 0, 1, -48)
Buttons.BackgroundTransparency = 1
Buttons.Parent = DetailPage

local Back = Instance.new("TextButton")
Back.Size = UDim2.new(0.48, 0, 1, 0)
Back.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Back.TextColor3 = Color3.new(1, 1, 1)
Back.Text = "Back"
Back.TextSize = 14
Back.Font = Enum.Font.GothamBold
Back.Parent = Buttons

local BackCorner = Instance.new("UICorner")
BackCorner.CornerRadius = UDim.new(0, 8)
BackCorner.Parent = Back

local Teleport = Instance.new("TextButton")
Teleport.Size = UDim2.new(0.48, 0, 1, 0)
Teleport.Position = UDim2.new(0.52, 0, 0, 0)
Teleport.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
Teleport.TextColor3 = Color3.fromRGB(10, 10, 10)
Teleport.Text = "Teleport"
Teleport.TextSize = 14
Teleport.Font = Enum.Font.GothamBold
Teleport.Parent = Buttons

local TeleportCorner = Instance.new("UICorner")
TeleportCorner.CornerRadius = UDim.new(0, 8)
TeleportCorner.Parent = Teleport

local players = {}
local selected = nil

local function send(data)
    local encoded = HttpService:JSONEncode(data)
    local success, err = pcall(function()
        ws:Send(encoded)
    end)

    if not success then
        warn("[TP] Send failed:", err)
        Status.Text = "Send failed"
    end
end

local function clearChildrenExceptLayout(container)
    for _, child in ipairs(container:GetChildren()) do
        if not child:IsA("UIListLayout")
            and not child:IsA("UIPadding")
            and child ~= Empty then
            child:Destroy()
        end
    end
end

local function renderStuff(info)
    for _, child in ipairs(StuffList:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    local items = type(info.items) == "table" and info.items or {}

    if #items == 0 then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -4, 0, 30)
        label.BackgroundTransparency = 1
        label.Text = "Nothing detected"
        label.TextColor3 = Color3.fromRGB(145, 145, 145)
        label.TextSize = 13
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = StuffList
        return
    end

    for _, item in ipairs(items) do
        local name
        local extra = ""

        if type(item) == "table" then
            name = tostring(item.name or "Unknown")
            if item.extra then
                extra = tostring(item.extra)
            end
        else
            name = tostring(item)
        end

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -4, 0, extra ~= "" and 40 or 28)
        label.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
        label.BorderSizePixel = 0
        label.Text = extra ~= "" and (name .. "\n" .. extra) or name
        label.TextColor3 = Color3.fromRGB(235, 235, 235)
        label.TextSize = 12
        label.Font = Enum.Font.Gotham
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Parent = StuffList

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = label

        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0, 8)
        p.PaddingRight = UDim.new(0, 8)
        p.Parent = label
    end
end

local function openPlayer(info)
    selected = info
    SelectedName.Text = (info.displayName or info.username) .. "  @" .. info.username
    renderStuff(info)

    ListPage.Visible = false
    DetailPage.Visible = true
end

local function renderPlayers()
    clearChildrenExceptLayout(PlayerList)

    Empty.Visible = #players == 0

    for index, info in ipairs(players) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -2, 0, 48)
        button.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
        button.BorderSizePixel = 0
        button.TextColor3 = Color3.new(1, 1, 1)
        button.TextSize = 14
        button.Font = Enum.Font.GothamBold
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.Text = "   " .. tostring(info.displayName or info.username) .. "  @" .. tostring(info.username)
        button.LayoutOrder = index
        button.Parent = PlayerList

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button

        button.MouseButton1Click:Connect(function()
            openPlayer(info)
        end)
    end

    Status.Text = tostring(#players) .. " receiver(s) online"
end

local function requestPlayers()
    send({ type = "list" })
end

Refresh.MouseButton1Click:Connect(requestPlayers)

Back.MouseButton1Click:Connect(function()
    selected = nil
    DetailPage.Visible = false
    ListPage.Visible = true
end)

Teleport.MouseButton1Click:Connect(function()
    if not selected or not selected.username then
        Status.Text = "Select a receiver first"
        return
    end

    if game.JobId == "" then
        Status.Text = "Current JobId is empty"
        return
    end

    Status.Text = "Sending TP to @" .. selected.username

    send({
        type = "join",
        target = selected.username,
        placeId = game.PlaceId,
        jobId = game.JobId
    })
end)

local dragging = false
local dragStart
local startPos
local dragInput

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

local function onMessage(message)
    local success, data = pcall(function()
        return HttpService:JSONDecode(message)
    end)

    if not success or type(data) ~= "table" then
        return
    end

    if data.type == "connected" then
        Status.Text = "Connected - loading receivers..."
        requestPlayers()
        return
    end

    if data.type == "players" then
        players = type(data.players) == "table" and data.players or {}
        renderPlayers()

        if selected and selected.username then
            for _, info in ipairs(players) do
                if tostring(info.username):lower() == tostring(selected.username):lower() then
                    selected = info
                    if DetailPage.Visible then
                        SelectedName.Text = (info.displayName or info.username) .. "  @" .. info.username
                        renderStuff(info)
                    end
                    break
                end
            end
        end
        return
    end

    if data.type == "sent" then
        local count = tonumber(data.receivers) or 0
        if count > 0 then
            Status.Text = "TP sent to @" .. tostring(data.target or selected and selected.username or "?")
        else
            Status.Text = "Receiver is no longer online"
            requestPlayers()
        end
        return
    end

    if data.type == "error" then
        Status.Text = tostring(data.error or "Server error")
    end
end

if ws.OnMessage then
    ws.OnMessage:Connect(onMessage)
elseif ws.Message then
    ws.Message:Connect(onMessage)
else
    warn("[TP] No WebSocket message event found")
end

if ws.OnClose then
    ws.OnClose:Connect(function()
        Status.Text = "Disconnected"
    end)
end

requestPlayers()
