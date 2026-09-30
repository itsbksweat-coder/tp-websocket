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

local OWNER_ATTRS = {
    "Owner",
    "OwnerName",
    "Username",
    "PlayerName",
    "OwnerId",
    "OwnerUserId",
    "UserId"
}

local BRAINROT_ATTRS = {
    "Animal",
    "AnimalName",
    "Brainrot",
    "BrainrotName",
    "__Animal"
}

local MUTATION_ATTRS = {
    "__Mutation",
    "Mutation"
}

local BAD_NAMES = {
    ["model"] = true,
    ["animal"] = true,
    ["brainrot"] = true,
    ["rig"] = true,
    ["root"] = true,
    ["main"] = true,
    ["podium"] = true,
    ["slot"] = true,
    ["holder"] = true,
    ["display"] = true,
    ["claim"] = true,
    ["base"] = true,
    ["button"] = true,
    ["buttons"] = true,
    ["platform"] = true,
    ["floor"] = true,
    ["sign"] = true,
    ["prompt"] = true,
    ["spawn"] = true,
    ["pivot"] = true
}

local function usableName(value)
    local name = trim(value)
    if name == "" then
        return false
    end

    local lower = name:lower()

    if BAD_NAMES[lower] then
        return false
    end

    if lower:find("podium", 1, true)
        or lower:find("claim", 1, true)
        or lower:find("slot", 1, true)
        or lower:find("button", 1, true) then
        return false
    end

    return true
end

local function valueMatchesLocalPlayer(value)
    if typeof(value) == "Instance" and value:IsA("Player") then
        return value == LocalPlayer
    end

    if type(value) == "number" then
        return value == LocalPlayer.UserId
    end

    if type(value) == "string" then
        local lower = trim(value):lower()
        return lower == LocalPlayer.Name:lower()
            or lower == LocalPlayer.DisplayName:lower()
            or tonumber(lower) == LocalPlayer.UserId
    end

    return false
end

local function objectNamesLocalPlayer(obj)
    for _, attrName in ipairs(OWNER_ATTRS) do
        if valueMatchesLocalPlayer(obj:GetAttribute(attrName)) then
            return true
        end
    end

    for _, childName in ipairs(OWNER_ATTRS) do
        local child = obj:FindFirstChild(childName)

        if child and (
            child:IsA("StringValue")
            or child:IsA("IntValue")
            or child:IsA("NumberValue")
            or child:IsA("ObjectValue")
        ) then
            if valueMatchesLocalPlayer(child.Value) then
                return true
            end
        end
    end

    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        local text = tostring(obj.Text or ""):lower()

        if text:find(LocalPlayer.Name:lower(), 1, true)
            or text:find(LocalPlayer.DisplayName:lower(), 1, true) then
            return true
        end
    end

    return false
end

local function groupBelongsToLocalPlayer(podiums)
    local current = podiums

    for _ = 1, 7 do
        if not current then
            break
        end

        if objectNamesLocalPlayer(current) then
            return true
        end

        current = current.Parent
    end

    local base = podiums.Parent
    if not base then
        return false
    end

    for _, obj in ipairs(base:GetDescendants()) do
        if objectNamesLocalPlayer(obj) then
            return true
        end
    end

    return false
end

local function attrValue(obj, names)
    for _, name in ipairs(names) do
        local value = obj:GetAttribute(name)

        if value ~= nil and trim(value) ~= "" then
            return trim(value)
        end
    end

    return nil
end

local function getMutation(slot)
    local value = attrValue(slot, MUTATION_ATTRS)

    if not value then
        for _, obj in ipairs(slot:GetDescendants()) do
            value = attrValue(obj, MUTATION_ATTRS)

            if value then
                break
            end
        end
    end

    if not value then
        return nil
    end

    local lower = value:lower()

    if lower == "normal" or lower == "none" then
        return nil
    end

    return value
end

local function getBrainrotName(slot)
    -- 1) Exact game-data attributes are strongest.
    local value = attrValue(slot, BRAINROT_ATTRS)
    if value and usableName(value) then
        return value
    end

    for _, obj in ipairs(slot:GetDescendants()) do
        value = attrValue(obj, BRAINROT_ATTRS)

        if value and usableName(value) then
            return value
        end
    end

    -- 2) Exact named StringValues.
    for _, valueName in ipairs({
        "Animal",
        "AnimalName",
        "Brainrot",
        "BrainrotName"
    }) do
        local obj = slot:FindFirstChild(valueName, true)

        if obj and obj:IsA("StringValue") and usableName(obj.Value) then
            return trim(obj.Value)
        end
    end

    -- 3) Prefer the model carrying the mutation attribute, since that is
    -- normally the spawned brainrot model rather than Claim/Base slot parts.
    for _, obj in ipairs(slot:GetDescendants()) do
        if obj:GetAttribute("__Mutation") ~= nil
            or obj:GetAttribute("Mutation") ~= nil then

            local current = obj

            for _ = 1, 6 do
                if not current or current == slot then
                    break
                end

                if current:IsA("Model") and usableName(current.Name) then
                    return current.Name
                end

                current = current.Parent
            end
        end
    end

    -- 4) Score descendant models and reject known slot/UI models.
    local bestName
    local bestScore = -1

    for _, obj in ipairs(slot:GetDescendants()) do
        if obj:IsA("Model") and usableName(obj.Name) then
            local score = 1

            if obj:GetAttribute("__Mutation") ~= nil
                or obj:GetAttribute("Mutation") ~= nil then
                score += 20
            end

            if attrValue(obj, BRAINROT_ATTRS) then
                score += 30
            end

            local partCount = 0
            local hasHumanoid = obj:FindFirstChildOfClass("Humanoid") ~= nil
            local hasRoot = obj:FindFirstChild("HumanoidRootPart", true) ~= nil

            for _, desc in ipairs(obj:GetDescendants()) do
                if desc:IsA("BasePart") then
                    partCount += 1
                end
            end

            if hasHumanoid then
                score += 8
            end

            if hasRoot then
                score += 6
            end

            score += math.min(partCount, 8)

            if score > bestScore then
                bestScore = score
                bestName = obj.Name
            end
        end
    end

    return bestName
end

local function collectOwnBaseItems()
    if getgenv and type(getgenv().TPGetStuff) == "function" then
        local ok, custom = pcall(getgenv().TPGetStuff)

        if ok and type(custom) == "table" then
            return custom
        end
    end

    local rawItems = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "AnimalPodiums" and groupBelongsToLocalPlayer(obj) then
            for _, slot in ipairs(obj:GetChildren()) do
                local brainrotName = getBrainrotName(slot)

                if brainrotName and usableName(brainrotName) then
                    rawItems[#rawItems + 1] = {
                        name = brainrotName,
                        mutation = getMutation(slot)
                    }
                end
            end

            break
        end
    end

    local order = {}
    local counts = {}

    for _, item in ipairs(rawItems) do
        local mutation = item.mutation or ""
        local key = item.name:lower() .. "\0" .. mutation:lower()

        if not counts[key] then
            counts[key] = {
                name = item.name,
                mutation = item.mutation,
                count = 0
            }
            order[#order + 1] = key
        end

        counts[key].count += 1
    end

    local items = {}

    for _, key in ipairs(order) do
        local entry = counts[key]
        local extras = {}

        if entry.mutation then
            extras[#extras + 1] = "Mutation: " .. entry.mutation
        end

        if entry.count > 1 then
            extras[#extras + 1] = "x" .. tostring(entry.count)
        end

        local result = {
            name = entry.name
        }

        if #extras > 0 then
            result.extra = table.concat(extras, " | ")
        end

        items[#items + 1] = result
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
    send({
        type = kind or "register",
        username = LocalPlayer.Name,
        displayName = LocalPlayer.DisplayName,
        items = collectOwnBaseItems()
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
