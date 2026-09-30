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
Main.Size = UDim2.fromOffset(350, 410)
Main.Position = UDim2.new(0.5, -175, 0.5, -205)
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
Title.Size = UDim2.new(1, -130, 1, 0)
Title.Position = UDim2.fromOffset(14, 0)
Title.BackgroundTransparency = 1
Title.Text = "TP Receiver"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local SettingsButton = Instance.new("TextButton")
SettingsButton.Size = UDim2.fromOffset(94, 32)
SettingsButton.Position = UDim2.new(1, -108, 0, 8)
SettingsButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
SettingsButton.TextColor3 = Color3.new(1, 1, 1)
SettingsButton.Text = "Settings"
SettingsButton.TextSize = 13
SettingsButton.Font = Enum.Font.GothamBold
SettingsButton.Parent = Header

local SettingsButtonCorner = Instance.new("UICorner")
SettingsButtonCorner.CornerRadius = UDim.new(0, 8)
SettingsButtonCorner.Parent = SettingsButton

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

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Size = UDim2.fromScale(1, 1)
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
StuffTitle.Text = "Base Stuff"
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

local SettingsPage = Instance.new("Frame")
SettingsPage.Name = "SettingsPage"
SettingsPage.Size = UDim2.new(1, -28, 1, -92)
SettingsPage.Position = UDim2.fromOffset(14, 78)
SettingsPage.BackgroundTransparency = 1
SettingsPage.Visible = false
SettingsPage.Parent = Main

local SettingsTitle = Instance.new("TextLabel")
SettingsTitle.Size = UDim2.new(1, 0, 0, 34)
SettingsTitle.BackgroundTransparency = 1
SettingsTitle.Text = "Teleport Settings"
SettingsTitle.TextColor3 = Color3.new(1, 1, 1)
SettingsTitle.TextSize = 18
SettingsTitle.Font = Enum.Font.GothamBold
SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
SettingsTitle.Parent = SettingsPage

local PlaceLabel = Instance.new("TextLabel")
PlaceLabel.Size = UDim2.new(1, 0, 0, 24)
PlaceLabel.Position = UDim2.fromOffset(0, 42)
PlaceLabel.BackgroundTransparency = 1
PlaceLabel.Text = "PlaceId"
PlaceLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
PlaceLabel.TextSize = 13
PlaceLabel.Font = Enum.Font.GothamBold
PlaceLabel.TextXAlignment = Enum.TextXAlignment.Left
PlaceLabel.Parent = SettingsPage

local PlaceBox = Instance.new("TextBox")
PlaceBox.Size = UDim2.new(1, 0, 0, 42)
PlaceBox.Position = UDim2.fromOffset(0, 68)
PlaceBox.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
PlaceBox.BorderSizePixel = 0
PlaceBox.TextColor3 = Color3.new(1, 1, 1)
PlaceBox.PlaceholderColor3 = Color3.fromRGB(125, 125, 125)
PlaceBox.PlaceholderText = "Enter PlaceId"
PlaceBox.Text = tostring(game.PlaceId)
PlaceBox.TextSize = 14
PlaceBox.Font = Enum.Font.Gotham
PlaceBox.ClearTextOnFocus = false
PlaceBox.TextXAlignment = Enum.TextXAlignment.Left
PlaceBox.Parent = SettingsPage

local PlaceBoxCorner = Instance.new("UICorner")
PlaceBoxCorner.CornerRadius = UDim.new(0, 8)
PlaceBoxCorner.Parent = PlaceBox

local PlacePadding = Instance.new("UIPadding")
PlacePadding.PaddingLeft = UDim.new(0, 10)
PlacePadding.PaddingRight = UDim.new(0, 10)
PlacePadding.Parent = PlaceBox

local JobLabel = Instance.new("TextLabel")
JobLabel.Size = UDim2.new(1, 0, 0, 24)
JobLabel.Position = UDim2.fromOffset(0, 122)
JobLabel.BackgroundTransparency = 1
JobLabel.Text = "JobId"
JobLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
JobLabel.TextSize = 13
JobLabel.Font = Enum.Font.GothamBold
JobLabel.TextXAlignment = Enum.TextXAlignment.Left
JobLabel.Parent = SettingsPage

local JobBox = Instance.new("TextBox")
JobBox.Size = UDim2.new(1, 0, 0, 42)
JobBox.Position = UDim2.fromOffset(0, 148)
JobBox.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
JobBox.BorderSizePixel = 0
JobBox.TextColor3 = Color3.new(1, 1, 1)
JobBox.PlaceholderColor3 = Color3.fromRGB(125, 125, 125)
JobBox.PlaceholderText = "Enter JobId"
JobBox.Text = tostring(game.JobId)
JobBox.TextSize = 14
JobBox.Font = Enum.Font.Gotham
JobBox.ClearTextOnFocus = false
JobBox.TextXAlignment = Enum.TextXAlignment.Left
JobBox.Parent = SettingsPage

local JobBoxCorner = Instance.new("UICorner")
JobBoxCorner.CornerRadius = UDim.new(0, 8)
JobBoxCorner.Parent = JobBox

local JobPadding = Instance.new("UIPadding")
JobPadding.PaddingLeft = UDim.new(0, 10)
JobPadding.PaddingRight = UDim.new(0, 10)
JobPadding.Parent = JobBox

local UseCurrent = Instance.new("TextButton")
UseCurrent.Size = UDim2.new(1, 0, 0, 42)
UseCurrent.Position = UDim2.fromOffset(0, 206)
UseCurrent.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
UseCurrent.TextColor3 = Color3.fromRGB(10, 10, 10)
UseCurrent.Text = "Use Current Server"
UseCurrent.TextSize = 14
UseCurrent.Font = Enum.Font.GothamBold
UseCurrent.Parent = SettingsPage

local UseCurrentCorner = Instance.new("UICorner")
UseCurrentCorner.CornerRadius = UDim.new(0, 8)
UseCurrentCorner.Parent = UseCurrent

local SettingsBack = Instance.new("TextButton")
SettingsBack.Size = UDim2.new(1, 0, 0, 42)
SettingsBack.Position = UDim2.new(0, 0, 1, -42)
SettingsBack.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
SettingsBack.TextColor3 = Color3.new(1, 1, 1)
SettingsBack.Text = "Back"
SettingsBack.TextSize = 14
SettingsBack.Font = Enum.Font.GothamBold
SettingsBack.Parent = SettingsPage

local SettingsBackCorner = Instance.new("UICorner")
SettingsBackCorner.CornerRadius = UDim.new(0, 8)
SettingsBackCorner.Parent = SettingsBack

local players = {}
local selected = nil
local currentPage = "list"
local connected = true

local function showPage(name)
    currentPage = name
    ListPage.Visible = name == "list"
    DetailPage.Visible = name == "detail"
    SettingsPage.Visible = name == "settings"
end

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
        label.Text = "No base brainrots detected"
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
    showPage("detail")
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

    Status.Text = tostring(#players) .. " receiver(s) online - auto updating"
end

local function requestPlayers()
    if connected then
        send({ type = "list" })
    end
end

Back.MouseButton1Click:Connect(function()
    selected = nil
    showPage("list")
end)

SettingsButton.MouseButton1Click:Connect(function()
    showPage("settings")
end)

SettingsBack.MouseButton1Click:Connect(function()
    showPage("list")
end)

UseCurrent.MouseButton1Click:Connect(function()
    PlaceBox.Text = tostring(game.PlaceId)
    JobBox.Text = tostring(game.JobId)
    Status.Text = "Settings set to current server"
end)

Teleport.MouseButton1Click:Connect(function()
    if not selected or not selected.username then
        Status.Text = "Select a receiver first"
        return
    end

    local placeId = tonumber(PlaceBox.Text)
    local jobId = tostring(JobBox.Text or ""):match("^%s*(.-)%s*$")

    if not placeId or placeId <= 0 then
        Status.Text = "Invalid PlaceId in Settings"
        return
    end

    if jobId == "" then
        Status.Text = "Invalid JobId in Settings"
        return
    end

    Status.Text = "Sending TP to @" .. selected.username

    send({
        type = "join",
        target = selected.username,
        placeId = placeId,
        jobId = jobId
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
        connected = true
        Status.Text = "Connected - loading receivers..."
        requestPlayers()
        return
    end

    if data.type == "players" then
        players = type(data.players) == "table" and data.players or {}
        renderPlayers()

        if selected and selected.username then
            local found
            for _, info in ipairs(players) do
                if tostring(info.username):lower() == tostring(selected.username):lower() then
                    selected = info
                    found = true
                    if currentPage == "detail" then
                        SelectedName.Text = (info.displayName or info.username) .. "  @" .. info.username
                        renderStuff(info)
                    end
                    break
                end
            end

            if not found and currentPage == "detail" then
                selected = nil
                Status.Text = "Receiver went offline"
                showPage("list")
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
        connected = false
        Status.Text = "Disconnected"
    end)
end

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(3)
        requestPlayers()
    end
end)

requestPlayers()
