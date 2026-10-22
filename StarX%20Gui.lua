-- ==============================================================================
-- StarX Gui | WindUI conversion
-- Original gameplay logic retained; UI calls are adapted to WindUI.
-- ==============================================================================
local WindUI
local success, err = pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if not success or not WindUI then
    warn("StarX Gui: não foi possível carregar WindUI: " .. tostring(err))
    return
end

local WindWindow = WindUI:CreateWindow({
    Title = "StarX Gui",
    Icon = "star",
    Author = "StarX",
    Folder = "StarXGui",
    Size = UDim2.fromOffset(600, 500),
    MinSize = Vector2.new(480, 350),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 180,
    HideSearchBar = true,
})

-- Compatibility layer: adapts the original control calls to WindUI.
local Window = {}
function Window:CreateTab(title, icon)
    local iconValue = icon or "circle"
    if type(iconValue) == "number" then
        iconValue = "rbxassetid://" .. tostring(iconValue)
    end
    local rawTab = WindWindow:Tab({ Title = tostring(title), Icon = tostring(iconValue) })
    local tab = {}

    function tab:CreateButton(cfg)
        cfg = cfg or {}
        return rawTab:Button({ Title = cfg.Name or "Button", Desc = cfg.Description, Callback = cfg.Callback })
    end

    function tab:CreateToggle(cfg)
        cfg = cfg or {}
        return rawTab:Toggle({ Title = cfg.Name or "Toggle", Desc = cfg.Description, Value = cfg.CurrentValue == true, Flag = cfg.Flag, Callback = cfg.Callback })
    end

    function tab:CreateSlider(cfg)
        cfg = cfg or {}
        local range = cfg.Range or {0, 100}
        return rawTab:Slider({
            Title = cfg.Name or "Slider",
            Step = cfg.Increment or 1,
            Value = { Min = range[1] or 0, Max = range[2] or 100, Default = cfg.CurrentValue or range[1] or 0 },
            Flag = cfg.Flag,
            Callback = cfg.Callback,
        })
    end

    function tab:CreateDropdown(cfg)
        cfg = cfg or {}
        local value = cfg.CurrentOption
        if type(value) == "table" then value = value[1] end
        return rawTab:Dropdown({
            Title = cfg.Name or "Dropdown",
            Values = cfg.Options or {},
            Value = value,
            Flag = cfg.Flag,
            Multi = false,
            Callback = cfg.Callback,
        })
    end

    function tab:CreateSection(title)
        return rawTab:Section({ Title = tostring(title or "Section") })
    end

    return tab
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Character, HumanoidRootPart, Humanoid

local function updateCharVars(char)
    Character = char
    if char then
        HumanoidRootPart = char:WaitForChild("HumanoidRootPart", 5)
        Humanoid = char:WaitForChild("Humanoid", 5)
    end
end

LocalPlayer.CharacterAdded:Connect(updateCharVars)
if LocalPlayer.Character then
    updateCharVars(LocalPlayer.Character)
end

-- Lista de Monstros Twisteds para checagem de proximidade (30 studs)
local TwistedMonsterNames = {
    ["CosmoMonster"] = true, ["BoxtenMonster"] = true, ["YattaMonster"] = true, ["ShrimpoMonster"] = true,
    ["RudieMonster"] = true, ["RibeccaMonster"] = true, ["EggsonMonster"] = true, ["LooeyMonster"] = true,
    ["PoppyMonster"] = true, ["BrushaMonster"] = true, ["TishaMonster"] = true, ["FinnMonster"] = true,
    ["BrightneyMonster"] = true, ["FlyteMonster"] = true, ["GingerMonster"] = true, ["SoulvesterMonster"] = true,
    ["ToodlesMonster"] = true, ["GlistenMonster"] = true, ["GigiMonster"] = true, ["GoobMonster"] = true,
    ["ScrapsMonster"] = true, ["CoalMonster"] = true, ["EclipseMonster"] = true, ["CocoaMonster"] = true,
    ["FlutterMonster"] = true, ["ShellyMonster"] = true, ["PebbleMonster"] = true, ["VeeMonster"] = true,
    ["AstroMonster"] = true, ["SproutMonster"] = true, ["BobetteMonster"] = true, ["BassieMonster"] = true,
    ["DyleMonster"] = true, ["DandyMonster"] = true, ["GourdyMonster"] = true, ["TeaganMonster"] = true,
    ["RodgerMonster"] = true, ["RazzleDazzleMonster"] = true, ["ConnieMonster"] = true, ["WaxwellMonster"] = true
}

local function isTwistedNearby(targetPos, maxDist)
    maxDist = maxDist or 30
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and TwistedMonsterNames[obj.Name] then
            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
            if part and (part.Position - targetPos).Magnitude <= maxDist then
                return true
            end
        end
    end
    return false
end

local function isElevatorNearby(targetPos, maxDist)
    maxDist = maxDist or 30
    local elevatorsFolder = Workspace:FindFirstChild("Elevators")
    if elevatorsFolder then
        for _, obj in ipairs(elevatorsFolder:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or obj
                if part and (part.Position - targetPos).Magnitude <= maxDist then
                    return true
                end
            end
        end
    end
    -- Verificar também por nome caso estejam soltos no workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Elevator" or obj.Name == "ElevatorDoor" then
            local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or (obj:IsA("BasePart") and obj)
            if part and (part.Position - targetPos).Magnitude <= maxDist then
                return true
            end
        end
    end
    return false
end

local function canInteractWithPosition(pos)
    if isElevatorNearby(pos, 30) then return false end
    if isTwistedNearby(pos, 30) then return false end
    return true
end

local function teleportTo(name, isExact)
    if not Character or not HumanoidRootPart then return false end
    for _, obj in ipairs(workspace:GetDescendants()) do
        local match = isExact and (obj.Name == name) or obj.Name:lower():find(name:lower())
        if match then
            local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or (obj:IsA("BasePart") and obj)
            if part then
                local targetPos = part:IsA("Model") and part:GetPivot().Position or part.Position
                if isTwistedNearby(targetPos, 30) then
                    WindUI:Notify({ Title = "Teleport", Content = "Twisted Nearby.", Duration = 2 })
                    return false
                end
                HumanoidRootPart.CFrame = (part:IsA("Model") and part:GetPivot() or part.CFrame) + Vector3.new(0, 3, 0)
                return true
            end
        end
    end
    return false
end

-- Função reutilizável para Teleport To Machine
local function performTeleportToMachine()
    if not Character or not HumanoidRootPart then return end
    local ignoredNames = {
        ["VendingMachine"] = true, ["Cooking_ExpressoMachine"] = true,
        ["DanceMachine"] = true, ["Gachapon_Arcade_01"] = true,
        ["Gachapon_Arcade_02"] = true, ["Gachapon_Arcade_03"] = true
    }
    local generators = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if not ignoredNames[obj.Name] and obj:IsA("Model") then
            local nameLower = obj.Name:lower()
            if nameLower == "generator" or nameLower == "generators" or nameLower:find("generator") or nameLower:find("dual_generator") then
                local stats = obj:FindFirstChild("Stats") or (obj.Parent and obj.Parent:FindFirstChild("Stats"))
                local isCompleted = false
                if stats then
                    local completed = stats:FindFirstChild("Completed")
                    if completed and completed.Value == true then isCompleted = true end
                end

                if not isCompleted then
                    local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                    if part and not isTwistedNearby(part.Position, 30) then 
                        table.insert(generators, part) 
                    end
                end
            end
        end
    end
    if #generators > 0 then
        local randomGen = generators[math.random(1, #generators)]
        HumanoidRootPart.CFrame = randomGen.CFrame + Vector3.new(0, 3, 0)
    else
        WindUI:Notify({ Title = "Teleport", Content = "Twisted Nearby.", Duration = 2 })
    end
end

-- ==============================================================================
-- NOCLIP
-- ==============================================================================
local NoclipConnection = nil

local function applyNoclip()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if getconnections then
                pcall(function()
                    for _, conn in ipairs(getconnections(part:GetPropertyChangedSignal("CanQuery"))) do conn:Disconnect() end
                    for _, conn in ipairs(getconnections(part:GetPropertyChangedSignal("CanCollide"))) do conn:Disconnect() end
                    for _, conn in ipairs(getconnections(part:GetPropertyChangedSignal("CanTouch"))) do conn:Disconnect() end
                    for _, conn in ipairs(getconnections(part.Changed)) do conn:Disconnect() end
                end)
            end
            part.CanCollide = false
        end
    end
end

local function toggleNoclip(state)
    if state then
        applyNoclip()
        if not NoclipConnection then
            NoclipConnection = RunService.Stepped:Connect(function()
                local character = LocalPlayer.Character
                if character then
                    for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end
    else
        if NoclipConnection then
            NoclipConnection:Disconnect()
            NoclipConnection = nil
        end
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- ==============================================================================
-- MAIN TAB
-- ==============================================================================
local MainTab = Window:CreateTab("Main", 82594118269653)
local speedValue, tpWalkEnabled, tpWalkSpeed = 16, false, 0.1

MainTab:CreateSlider({ Name = "Speed", Range = {16, 30}, Increment = 1, CurrentValue = 16, Flag = "PlayerSpeed", Callback = function(v) 
    speedValue = v 
    if Humanoid then Humanoid.WalkSpeed = v end
end })

MainTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "NoclipToggle",
    Callback = function(v)
        toggleNoclip(v)
    end
})

MainTab:CreateToggle({ Name = "Enable Tpwalk", CurrentValue = false, Flag = "TPWalkToggle", Callback = function(v) tpWalkEnabled = v end })
MainTab:CreateSlider({ Name = "Tpwalk Speed", Range = {0.1, 0.3}, Increment = 0.05, CurrentValue = 0.1, Flag = "TPWalkSpeed", Callback = function(v) tpWalkSpeed = v end })

RunService.RenderStepped:Connect(function(delta)
    if speedValue > 16 and Humanoid and Humanoid.WalkSpeed ~= speedValue then
        Humanoid.WalkSpeed = speedValue
    end
    if tpWalkEnabled and Character and HumanoidRootPart and Humanoid and Humanoid.MoveDirection.Magnitude > 0 then
        HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + (Humanoid.MoveDirection * tpWalkSpeed * delta * 60)
    end
end)

-- ==============================================================================
-- AUTOMATION TAB
-- ==============================================================================
local AutomationTab = Window:CreateTab("Automation", 71680025256265)

AutomationTab:CreateButton({
    Name = "Autofarm",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/BluuGuy-Sure/BluuHead-Dandy-s-World/refs/heads/main/JustThisOnce.lua"))()
        end)
    end
})

local autoGetToElevatorEnabled = false
AutomationTab:CreateToggle({
    Name = "Auto Get To Elevator",
    CurrentValue = false,
    Flag = "AutoGetToElevatorToggle",
    Callback = function(v)
        autoGetToElevatorEnabled = v
    end
})

task.spawn(function()
    while true do
        task.wait(0.5)
        if autoGetToElevatorEnabled then
            pcall(function()
                local infoFolder = Workspace:FindFirstChild("Info")
                local panicValue = infoFolder and infoFolder:FindFirstChild("Panic")
                local elevatorsFolder = Workspace:FindFirstChild("Elevators")
                
                if panicValue and panicValue.Value == true and elevatorsFolder and HumanoidRootPart then
                    local elevator = elevatorsFolder:FindFirstChild("Elevator") or elevatorsFolder:FindFirstChildOfClass("Model")
                    if elevator then
                        local targetPart = elevator.PrimaryPart or elevator:FindFirstChild("Hitbox") or elevator:FindFirstChildWhichIsA("BasePart")
                        if targetPart then
                            HumanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
                        end
                    end
                end
            end)
        end
    end
end)

-- Método otimizado de Teletransporte rápido sem lag para coleta
local function smartCollectItem(itemObj)
    if not Character or not HumanoidRootPart then return false end
    local targetPart = itemObj:IsA("BasePart") and itemObj or itemObj:FindFirstChildWhichIsA("BasePart", true)
    local prompt = itemObj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not targetPart or not prompt then return false end

    local targetPos = targetPart.Position
    if not canInteractWithPosition(targetPos) then return false end

    local originalPosition = HumanoidRootPart.CFrame
    local startTime = tick()
    local collected = false

    while tick() - startTime < 5 do
        if not Character or not HumanoidRootPart then break end
        HumanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
        pcall(function() fireproximityprompt(prompt) end)
        
        -- Verificar se o item ainda existe/está ativo
        if not itemObj.Parent then
            collected = true
            break
        end
        task.wait(0.1)
    end

    if HumanoidRootPart then
        HumanoidRootPart.CFrame = originalPosition
    end
    return collected
end

-- Estados dos Auto Pick Ups
local autoExtractActive = false
local autoHealsActive = false
local autoCollectActive = false
local autoCollectEventActive = false

AutomationTab:CreateToggle({
    Name = "Auto Pick Up Extraction Items",
    CurrentValue = false,
    Flag = "AutoPickUpExtractionItemsToggle",
    Callback = function(v) autoExtractActive = v end
})

AutomationTab:CreateToggle({
    Name = "Auto Pick Up Heals",
    CurrentValue = false,
    Flag = "AutoPickUpHealsToggle",
    Callback = function(v) autoHealsActive = v end
})

AutomationTab:CreateToggle({
    Name = "Auto Collect Research Capsules",
    CurrentValue = false,
    Flag = "AutoCollectResearchCapsulesToggle",
    Callback = function(v) autoCollectActive = v end
})

AutomationTab:CreateToggle({
    Name = "Auto Collect Event Currency",
    CurrentValue = false,
    Flag = "AutoCollectEventCurrencyToggle",
    Callback = function(v) autoCollectEventActive = v end
})

-- Loop principal sequencial ordenado por etapas para os Auto Pick Ups com verificação de Inventário Cheio
task.spawn(function()
    local extractionNames = {["ExtractionSpeedCandy"]=true, ["Instructions"]=true, ["BonBon"]=true, ["Jawbreaker"]=true, ["JumperCable"]=true}
    local healNames = {["Bandage"]=true, ["HealthKit"]=true}

    local function isInventoryFull()
        local char = LocalPlayer.Character
        if not char then return false end
        local inv = char:FindFirstChild("Inventory")
        if not inv then return false end

        for i = 1, 3 do
            local slot = inv:FindFirstChild("Slot" .. tostring(i))
            if not slot or slot.Value == nil or slot.Value == "" or slot.Value == "None" then
                return false
            end
        end
        return true
    end

    while true do
        task.wait(1)
        if Character and HumanoidRootPart then
            -- Se o inventário NÃO estiver cheio, executa a coleta de curas e extrações[span_1](start_span)[span_1](end_span)
            if not isInventoryFull() then
                -- 1. Primeiro: Extraction Items
                if autoExtractActive then
                    pcall(function()
                        for _, obj in ipairs(Workspace:GetDescendants()) do
                            if not autoExtractActive or isInventoryFull() then break end
                            if extractionNames[obj.Name] then
                                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                                if part and canInteractWithPosition(part.Position) then
                                    smartCollectItem(obj)
                                end
                            end
                        end
                    end)
                end

                -- 2. Segundo: Pick Up Heals
                if autoHealsActive then
                    pcall(function()
                        for _, obj in ipairs(Workspace:GetDescendants()) do
                            if not autoHealsActive or isInventoryFull() then break end
                            if healNames[obj.Name] then
                                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                                if part and canInteractWithPosition(part.Position) then
                                    smartCollectItem(obj)
                                end
                            end
                        end
                    end)
                end
            end

            -- 3. Terceiro: Research Capsules
            if autoCollectActive then
                pcall(function()
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if not autoCollectActive then break end
                        if obj.Name == "ResearchCapsule" then
                            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                            if part and canInteractWithPosition(part.Position) then
                                smartCollectItem(obj)
                            end
                        end
                    end
                end)
            end

            -- 4. Quarto: Event Currency
            if autoCollectEventActive then
                pcall(function()
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if not autoCollectEventActive then break end
                        if obj.Name == "Pumpkin" then
                            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                            if part and canInteractWithPosition(part.Position) then
                                smartCollectItem(obj)
                            end
                        end
                    end
                end)
            end
        end
    end
end)

local autoUseItemsEnabled = false
AutomationTab:CreateToggle({
    Name = "Auto Use Itens",
    CurrentValue = false,
    Flag = "AutoUseItemsToggle",
    Callback = function(v)
        autoUseItemsEnabled = v
    end
})

task.spawn(function()
    while true do
        if autoUseItemsEnabled then
            pcall(function()
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Inventory") then
                    local inv = char.Inventory
                    for i = 1, 3 do
                        local slot = inv:FindFirstChild("Slot" .. tostring(i))
                        if slot and ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("ItemEvent") then
                            ReplicatedStorage.Events.ItemEvent:InvokeServer(char, slot)
                        end
                    end
                end
            end)
        end
        task.wait(1)
    end
end)

local autoAbilityEnabled = false
AutomationTab:CreateToggle({ 
    Name = "Auto Use Ability", 
    CurrentValue = false, 
    Flag = "AutoAbilityToggle", 
    Callback = function(v)
        autoAbilityEnabled = v
    end 
})

task.spawn(function()
    while true do
          if autoAbilityEnabled then
            pcall(function()
                if Character and HumanoidRootPart and ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("AbilityEvent") then
                    ReplicatedStorage.Events.AbilityEvent:InvokeServer(Character, HumanoidRootPart.CFrame, false)
                end
            end)
        end
        task.wait(1.5)
    end
end)

AutomationTab:CreateButton({
    Name = "Auto Escape Squirm",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/alihusam078588-web/Twilight-zone-loader/refs/heads/main/auto%20struggle.lua"))()
        end)
    end
})

-- ==============================================================================
-- ESP TAB
-- ==============================================================================
local EspTab = Window:CreateTab("Esp", 130098091866021)

-- --- SUBSEÇÃO: TWISTED ESP ---
EspTab:CreateSection("Twisteds ESP")

local twistedEspEnabled = false
local twistedDisableNametags = false
local activeTwistedMonsters = {}
local twistedConnection = nil

EspTab:CreateToggle({
    Name = "Twisted Esp",
    CurrentValue = false,
    Flag = "TwistedEspToggle",
    Callback = function(v)
        twistedEspEnabled = v
        
        local ColorChangingList = { ["GourdyMonster"] = true, ["BassieMonster"] = true, ["BobetteMonster"] = true, ["VeeMonster"] = true, ["DyleMonster"] = true, ["DandyMonster"] = true, ["AstroMonster"] = true, ["PebbleMonster"] = true, ["ShellyMonster"] = true, ["SproutMonster"] = true }
        local Colors = { Color3.fromRGB(148, 0, 211), Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 255, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 165, 0), Color3.fromRGB(0, 0, 255) }
        local CommonList = { ["BoxtenMonster"] = true, ["PoppyMonster"] = true, ["BrushaMonster"] = true, ["ShrimpoMonster"] = true, ["RudieMonster"] = true, ["EggsonMonster"] = true, ["RibeccaMonster"] = true, ["YattaMonster"] = true, ["TishaMonster"] = true, ["LooeyMonster"] = true, ["CosmoMonster"] = true }
        local UncommonList = { ["FinnMonster"] = true, ["TeaganMonster"] = true, ["RodgerMonster"] = true, ["RazzleDazzleMonster"] = true, ["SoulvesterMonster"] = true, ["GingerMonster"] = true, ["FlyteMonster"] = true, ["ConnieMonster"] = true, ["BrightneyMonster"] = true, ["ToodlesMonster"] = true }
        local RareList = { ["GigiMonster"] = true, ["ScrapsMonster"] = true, ["GoobMonster"] = true, ["WaxwellMonster"] = true, ["GlistenMonster"] = true, ["FlutterMonster"] = true, ["EclipseMonster"] = true, ["CocoaMonster"] = true, ["CoalMonster"] = true, ["SquirmMonster"] = true, ["BlottMonster"] = true }
        local BlotHandsList = { ["BlotHand"] = true, ["BlotHand_L"] = true, ["BlotHand_R"] = true }
        local MainList = { ["ShellyMonster"] = true, ["AstroMonster"] = true, ["PebbleMonster"] = true, ["VeeMonster"] = true, ["SproutMonster"] = true, ["BassieMonster"] = true, ["BobetteMonster"] = true, ["GourdyMonster"] = true }
        local LethalList = { ["DandyMonster"] = true, ["DyleMonster"] = true }

        local EasterEventList = { ["CocoaMonster"] = true, ["BassieMonster"] = true, ["FlyteMonster"] = true, ["EggsonMonster"] = true }
        local EasterColors = {Color3.fromRGB(255, 255, 153), Color3.fromRGB(255, 153, 204)}
        local HalloweenEventList = { ["GourdyMonster"] = true, ["EclipseMonster"] = true, ["SoulvesterMonster"] = true, ["RibeccaMonster"] = true }
        local HalloweenColors = {Color3.fromRGB(148, 0, 211), Color3.fromRGB(255, 128, 0)}
        local XmasEventList = { ["BobetteMonster"] = true, ["CoalMonster"] = true, ["GingerMonster"] = true, ["RudieMonster"] = true }
        local XmasColors = {Color3.fromRGB(0, 204, 153), Color3.fromRGB(255, 51, 51)}
        local LethalColors = {Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 0, 0)}

        local AllMonsters = {}
        for k in pairs(CommonList) do AllMonsters[k] = true end
        for k in pairs(UncommonList) do AllMonsters[k] = true end
        for k in pairs(RareList) do AllMonsters[k] = true end
        for k in pairs(BlotHandsList) do AllMonsters[k] = true end
        for k in pairs(ColorChangingList) do AllMonsters[k] = true end
        for k in pairs(LethalList) do AllMonsters[k] = true end

        local function setupMonster(model)
            if not model or not model:IsA("Model") or model:FindFirstChild("ESP_Container") then return end
            
            local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
            if not head then return end

            local container = Instance.new("Folder")
            container.Name = "ESP_Container"
            container.Parent = model

            local highlight = Instance.new("Highlight")
            highlight.Adornee = model
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.Parent = container

            local billboard = Instance.new("BillboardGui", head)
            billboard.Name = "Nametag"
            billboard.Size = UDim2.new(0, 180, 0, 35)
            billboard.StudsOffset = Vector3.new(0, 4.2, 0)
            billboard.AlwaysOnTop = true
            billboard.Enabled = not twistedDisableNametags

            local textLabel = Instance.new("TextLabel", billboard)
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.Font = Enum.Font.FredokaOne
            textLabel.TextSize = 9
            textLabel.TextStrokeTransparency = 0
            textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

            local rarityText = ""
            local baseTextColor = Color3.fromRGB(255, 0, 0)

            if CommonList[model.Name] then rarityText = " | Common"; baseTextColor = Color3.fromRGB(180, 180, 180)
            elseif UncommonList[model.Name] then rarityText = " | Uncommon"; baseTextColor = Color3.fromRGB(50, 255, 50)
            elseif RareList[model.Name] then rarityText = " | Rare"; baseTextColor = Color3.fromRGB(100, 200, 255)
            elseif BlotHandsList[model.Name] then rarityText = ""; baseTextColor = Color3.fromRGB(100, 200, 255)
            elseif MainList[model.Name] then rarityText = " | Main" end

            if LethalList[model.Name] then rarityText = " | Lethal" end

            local rawName = BlotHandsList[model.Name] and "BlotHand" or model.Name:gsub("Monster", "")
            textLabel.Text = "Twisted " .. rawName .. rarityText

            table.insert(activeTwistedMonsters, billboard)

            task.spawn(function()
                local alpha = 0
                local colorIndex = 1

                while twistedEspEnabled and model and model.Parent and highlight and highlight.Parent do
                    local dt = task.wait(0.15)
                    alpha = alpha + (dt / 1.0)
                    if alpha >= 1 then
                        alpha = 0
                        colorIndex = colorIndex % #Colors + 1
                    end

                    local targetColor = baseTextColor
                    local pingPongAlpha = math.abs((tick() % 2) - 1)

                    if LethalList[model.Name] then
                        targetColor = LethalColors[1]:Lerp(LethalColors[2], pingPongAlpha)
                    elseif EasterEventList[model.Name] then
                        targetColor = EasterColors[1]:Lerp(EasterColors[2], pingPongAlpha)
                    elseif HalloweenEventList[model.Name] then
                        targetColor = HalloweenColors[1]:Lerp(HalloweenColors[2], pingPongAlpha)
                    elseif XmasEventList[model.Name] then
                        targetColor = XmasColors[1]:Lerp(XmasColors[2], pingPongAlpha)
                    elseif ColorChangingList[model.Name] then
                        local c1 = Colors[colorIndex]
                        local c2 = Colors[colorIndex % #Colors + 1]
                        targetColor = c1:Lerp(c2, alpha)
                    end

                    highlight.FillColor = targetColor
                    textLabel.TextColor3 = targetColor
                end
            end)
        end

        if twistedEspEnabled then
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and AllMonsters[obj.Name] then
                    setupMonster(obj)
                end
            end

            if twistedConnection then twistedConnection:Disconnect() end
            twistedConnection = Workspace.DescendantAdded:Connect(function(obj)
                if twistedEspEnabled and obj:IsA("Model") and AllMonsters[obj.Name] then
                    task.wait(0.1)
                    setupMonster(obj)
                end
            end)
        else
            if twistedConnection then
                twistedConnection:Disconnect()
                twistedConnection = nil
            end
            activeTwistedMonsters = {}
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj.Name == "ESP_Container" or (obj.Name == "Nametag" and obj.Parent and obj.Parent:IsA("BasePart")) then
                    obj:Destroy()
                end
            end
        end
    end
})

EspTab:CreateToggle({
    Name = "Disable Twisted Esp Nametags",
    CurrentValue = false,
    Flag = "TwistedDisableNametagsToggle",
    Callback = function(v)
        twistedDisableNametags = v
        for _, tag in ipairs(activeTwistedMonsters) do
            if tag and tag.Parent then tag.Enabled = not twistedDisableNametags end
        end
    end
})

-- --- SUBSEÇÃO: PLAYER ESP ---
EspTab:CreateSection("Player ESP")

local playerEspEnabled = false
local playerDisableNametags = false
local activePlayerNametags = {}

EspTab:CreateToggle({
    Name = "Player Esp",
    CurrentValue = false,
    Flag = "PlayerEspToggle",
    Callback = function(v)
        playerEspEnabled = v
        
        local COLOR_NORMAL_BLUE = Color3.fromRGB(0, 50, 150)
        local COLOR_LOW_BLUE = Color3.fromRGB(0, 30, 100)
        local COLOR_CRIT_BLUE = Color3.fromRGB(0, 15, 60)

        local COLOR_NORMAL_GREEN = Color3.fromRGB(0, 255, 0)
        local COLOR_LOW_GREEN = Color3.fromRGB(0, 180, 0)
        local COLOR_CRIT_GREEN = Color3.fromRGB(0, 100, 0)

        local function setupESP(player)
            if player == LocalPlayer then return end

            local function setupCharacter(char)
                if not char then return end
                local humanoidRootPart = char:WaitForChild("HumanoidRootPart", 5)
                local humanoid = char:WaitForChild("Humanoid", 5)
                local head = char:WaitForChild("Head", 5)

                if not humanoidRootPart or not humanoid or not head then return end

                if char:FindFirstChild("CustomChams") then char.CustomChams:Destroy() end
                if char:FindFirstChild("CustomNametag") then char.CustomNametag:Destroy() end

                if not playerEspEnabled then return end

                local highlight = Instance.new("Highlight")
                highlight.Name = "CustomChams"
                highlight.Adornee = char
                highlight.FillTransparency = 0.5
                highlight.OutlineTransparency = 0
                highlight.Parent = char

                local billboard = Instance.new("BillboardGui")
                billboard.Name = "CustomNametag"
                billboard.Adornee = head
                billboard.Size = UDim2.new(0, 200, 0, 50)
                billboard.StudsOffset = Vector3.new(0, 2.5, 0)
                billboard.AlwaysOnTop = true
                billboard.Enabled = not playerDisableNametags
                billboard.Parent = char

                table.insert(activePlayerNametags, billboard)

                local layout = Instance.new("UIListLayout", billboard)
                layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
                layout.VerticalAlignment = Enum.VerticalAlignment.Center

                local nameLabel = Instance.new("TextLabel", billboard)
                nameLabel.Name = "NickLabel"
                nameLabel.Size = UDim2.new(1, 0, 0, 25)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = player.Name
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.TextSize = 9
                nameLabel.Font = Enum.Font.FredokaOne
                nameLabel.TextStrokeTransparency = 0.5

                local healthLabel = Instance.new("TextLabel", billboard)
                healthLabel.Name = "HealthLabel"
                healthLabel.Size = UDim2.new(1, 0, 0, 25)
                healthLabel.BackgroundTransparency = 1
                healthLabel.TextSize = 9
                healthLabel.Font = Enum.Font.FredokaOne
                healthLabel.TextStrokeTransparency = 0.5

                local connection
                connection = RunService.RenderStepped:Connect(function()
                    if not playerEspEnabled or not char or not char.Parent or not humanoid or humanoid.Health <= 0 then
                        if highlight then highlight:Destroy() end
                        if billboard then billboard:Destroy() end
                        if connection then connection:Disconnect() end
                        return
                    end

                    local currentHp = math.floor(humanoid.Health)
                    healthLabel.Text = "Health: " .. currentHp

                    if currentHp == 1 then
                        highlight.FillColor = COLOR_CRIT_BLUE; highlight.OutlineColor = COLOR_CRIT_BLUE; healthLabel.TextColor3 = COLOR_CRIT_GREEN
                    elseif currentHp <= 2 then
                        highlight.FillColor = COLOR_LOW_BLUE; highlight.OutlineColor = COLOR_LOW_BLUE; healthLabel.TextColor3 = COLOR_LOW_GREEN
                    else
                        highlight.FillColor = COLOR_NORMAL_BLUE; highlight.OutlineColor = COLOR_NORMAL_BLUE; healthLabel.TextColor3 = COLOR_NORMAL_GREEN
                    end
                end)
            end

            if player.Character then setupCharacter(player.Character) end
            player.CharacterAdded:Connect(setupCharacter)
        end

        if playerEspEnabled then
            for _, p in ipairs(Players:GetPlayers()) do setupESP(p) end
        else
            activePlayerNametags = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character then
                    if p.Character:FindFirstChild("CustomChams") then p.Character.CustomChams:Destroy() end
                    if p.Character:FindFirstChild("CustomNametag") then p.Character.CustomNametag:Destroy() end
                end
            end
        end
    end
})

EspTab:CreateToggle({
    Name = "Disable Player Esp Nametags",
    CurrentValue = false,
    Flag = "PlayerDisableNametagsToggle",
    Callback = function(v)
        playerDisableNametags = v
        for _, tag in ipairs(activePlayerNametags) do
            if tag and tag.Parent then tag.Enabled = not playerDisableNametags end
        end
    end
})

-- --- SUBSEÇÃO: ITEM ESP ---
EspTab:CreateSection("Item ESP")

local itemEspEnabled = false
local itemDisableNametags = false
local activeItemNametags = {}
local itemConnection = nil

local itemMap = {
    AirHorn = "Air Horn", SmokeBomb = "Smoke Bomb", ResearchCapsule = "Research Capsule",
    ProteinBar = "Protein Bar", Jawbreaker = "Jawbreaker", EjectButton = "Eject Button",
    HealthKit = "MedKit", Bandage = "Bandage", Tape = "Tape", Instructions = "Instructions",
    ExtractionSpeedCandy = "Extraction Candy", SkillCheckCandy = "SkillCheck Candy",
    StaminaCandy = "Stamina Candy", StealthCandy = "Stealth Candy", SpeedCandy = "Speed Candy",
    Gumball = "Gumball", BonBon = "BonBon", Chocolate = "Chocolate", ChocolateBox = "Chocolate Box",
    Pop = "Pop", PopBottle = "Pop Bottle", JumperCable = "Jumper Cable", Stopwatch = "Stopwatch",
    ChristmasCookie = "Christmas Cookie", DandyEasterEggs = "Dandy Easter Eggs", Pumpkin = "Pumpkins",
    FakeCapsule = "Fake Capsule", Ornament = "Ornament", Basket = "Basket", DandCorn = "DandCorn"
}

local cols = {
    ["Air Horn"] = Color3.fromRGB(255, 50, 50), ["Smoke Bomb"] = Color3.fromRGB(135, 206, 250),
    ["Research Capsule"] = Color3.fromRGB(0, 255, 0), ["Protein Bar"] = Color3.fromRGB(0, 100, 0),
    ["Jawbreaker"] = Color3.fromRGB(148, 0, 211), ["Eject Button"] = Color3.fromRGB(255, 255, 0),
    ["MedKit"] = Color3.fromRGB(255, 0, 127), ["Bandage"] = Color3.fromRGB(255, 20, 147),
    ["Tape"] = Color3.fromRGB(128, 128, 128), ["Instructions"] = Color3.fromRGB(148, 0, 211),
    ["Extraction Candy"] = Color3.fromRGB(148, 0, 211), ["Skill Check Candy"] = Color3.fromRGB(255, 140, 0),
    ["Stamina Candy"] = Color3.fromRGB(0, 100, 0), ["Stealth Candy"] = Color3.fromRGB(135, 206, 250),
    ["Speed Candy"] = Color3.fromRGB(255, 255, 0), ["Gumball"] = Color3.fromRGB(135, 206, 250),
    ["Bon Bon"] = Color3.fromRGB(255, 182, 193), ["Chocolate"] = Color3.fromRGB(255, 255, 0),
    ["Chocolate Box"] = Color3.fromRGB(255, 255, 0), ["Pop"] = Color3.fromRGB(0, 100, 0),
    ["Pop Bottle"] = Color3.fromRGB(255, 0, 0), ["Jumper Cable"] = Color3.fromRGB(148, 0, 211),
    ["Stopwatch"] = Color3.fromRGB(255, 255, 255), ["Christmas Cookie"] = Color3.fromRGB(255, 255, 0),
    ["Dandy Easter Eggs"] = Color3.fromRGB(255, 255, 0), ["Pumpkins"] = Color3.fromRGB(255, 140, 0),
    ["Fake Capsule"] = Color3.fromRGB(255, 255, 0), ["DandCorn"] = Color3.fromRGB(255, 255, 0)
}

local function applyItemESP(obj)
    if not obj or not itemMap[obj.Name] then return end
    if obj:FindFirstChild("ESP_Added") then return end

    local tagFolder = Instance.new("Folder")
    tagFolder.Name = "ESP_Added"
    tagFolder.Parent = obj

    local formattedName = itemMap[obj.Name]
    local monsterNameRaw = ""

    if obj.Name == "ResearchCapsule" then
        local promptFolder = obj:FindFirstChild("Prompt")
        if promptFolder then
            local monsterVal = promptFolder:FindFirstChild("Monster")
            if monsterVal then
                monsterNameRaw = tostring(monsterVal.Value):gsub("Monster", "")
                formattedName = "Research Capsule | Twisted " .. monsterNameRaw
            end
        end
    end

    local itemColor = cols[itemMap[obj.Name]] or Color3.fromRGB(255, 165, 0)

    local hi = Instance.new("Highlight")
    hi.Name = "ItemChams"
    hi.Adornee = obj
    hi.FillColor = itemColor
    hi.FillTransparency = 0.5
    hi.OutlineColor = itemColor
    hi.OutlineTransparency = 0
    hi.Parent = tagFolder

    local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or (obj:IsA("BasePart") and obj)
    if part then
        local bb = Instance.new("BillboardGui")
        bb.Name = "ItemNametag"
        bb.Adornee = part
        bb.Size = UDim2.new(0, 200, 0, 50)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Enabled = not itemDisableNametags
        bb.Parent = tagFolder

        table.insert(activeItemNametags, bb)

        local txt = Instance.new("TextLabel", bb)
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Text = formattedName
        txt.TextColor3 = itemColor
        txt.TextSize = 9
        txt.Font = Enum.Font.FredokaOne
        txt.TextStrokeTransparency = 0
        txt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

        local capsuleList1 = {["shelly"]=true, ["astro"]=true, ["vee"]=true, ["pebble"]=true, ["sprout"]=true}
        local capsuleList2 = {["ribecca"]=true, ["gourdy"]=true, ["soulvester"]=true, ["eclipse"]=true}
        local capsuleList3 = {["bobette"]=true, ["coal"]=true, ["ginger"]=true, ["rudie"]=true}
        local capsuleList4 = {["bassie"]=true, ["cocoa"]=true, ["eggson"]=true, ["flyte"]=true}
        local capsuleList5 = {["dandy"]=true, ["dyle"]=true}

        local mLower = monsterNameRaw:lower()

        task.spawn(function()
            while itemEspEnabled and obj and obj.Parent and hi and txt do
                local t = tick()
                if capsuleList1[mLower] then
                    local colorsSet = {Color3.fromRGB(148,0,211), Color3.fromRGB(135,206,250), Color3.fromRGB(255,255,0), Color3.fromRGB(255,165,0), Color3.fromRGB(255,0,0)}
                    local idx = math.floor((t * 2) % #colorsSet) + 1
                    local nextIdx = (idx % #colorsSet) + 1
                    local alpha = (t * 2) % 1
                    local lerped = colorsSet[idx]:Lerp(colorsSet[nextIdx], alpha)
                    hi.FillColor = lerped; hi.OutlineColor = lerped; txt.TextColor3 = lerped
                elseif capsuleList2[mLower] then
                    local c1, c2 = Color3.fromRGB(148,0,211), Color3.fromRGB(255,128,0)
                    local alpha = math.abs(((t / 2) % 2) - 1)
                    local lerped = c1:Lerp(c2, alpha)
                    hi.FillColor = lerped; hi.OutlineColor = lerped; txt.TextColor3 = lerped
                elseif capsuleList3[mLower] then
                    local c1, c2 = Color3.fromRGB(0,204,153), Color3.fromRGB(255,51,51)
                    local alpha = math.abs(((t / 2) % 2) - 1)
                    local lerped = c1:Lerp(c2, alpha)
                    hi.FillColor = lerped; hi.OutlineColor = lerped; txt.TextColor3 = lerped
                elseif capsuleList4[mLower] then
                    local c1, c2 = Color3.fromRGB(255,255,153), Color3.fromRGB(255,153,204)
                    local alpha = math.abs(((t / 2) % 2) - 1)
                    local lerped = c1:Lerp(c2, alpha)
                    hi.FillColor = lerped; hi.OutlineColor = lerped; txt.TextColor3 = lerped
                elseif capsuleList5[mLower] then
                    local c1, c2 = Color3.fromRGB(0,0,0), Color3.fromRGB(255,0,0)
                    local alpha = math.abs(((t / 2) % 2) - 1)
                    local lerped = c1:Lerp(c2, alpha)
                    hi.FillColor = lerped; hi.OutlineColor = lerped; txt.TextColor3 = lerped
                else
                    local c1, c2 = nil, nil
                    if obj.Name == "HealthKit" or obj.Name == "Bandage" then
                        c1, c2 = Color3.fromRGB(255, 105, 180), Color3.fromRGB(255, 0, 0)
                    elseif obj.Name == "ChocolateBox" or obj.Name == "BoxOfChocolates" then
                        c1, c2 = Color3.fromRGB(0, 100, 0), Color3.fromRGB(255, 255, 0)
                    elseif obj.Name == "PopBottle" or obj.Name == "BottleOfPop" then
                        c1, c2 = Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 100, 0)
                    elseif obj.Name == "SmokeBomb" then
                        c1, c2 = Color3.fromRGB(148, 0, 211), Color3.fromRGB(135, 206, 250)
                    elseif obj.Name == "Pumpkin" or obj.Name == "HolidayCollectibleItem" or obj.Name == "Ornament" or obj.Name == "Basket" then
                        c1, c2 = Color3.fromRGB(255, 140, 0), Color3.fromRGB(148, 0, 211)
                        if obj.Name == "Ornament" then c1, c2 = Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 200, 200) end
                        if obj.Name == "Basket" then c1, c2 = Color3.fromRGB(255, 105, 180), Color3.fromRGB(255, 255, 180) end
                    end
                    if c1 and c2 then
                        local alpha = math.abs(((t / 2) % 2) - 1)
                        local lerpedColor = c1:Lerp(c2, alpha)
                        hi.FillColor = lerpedColor; hi.OutlineColor = lerpedColor; txt.TextColor3 = lerpedColor
                    end
                end
                task.wait(0.15)
            end
        end)
    end
end

EspTab:CreateToggle({
    Name = "Item Esp",
    CurrentValue = false,
    Flag = "ItemEspToggle",
    Callback = function(v)
        itemEspEnabled = v
        if itemEspEnabled then
            for _, o in ipairs(workspace:GetDescendants()) do
                applyItemESP(o)
            end
            
            if itemConnection then itemConnection:Disconnect() end
            itemConnection = workspace.DescendantAdded:Connect(function(o)
                if itemEspEnabled then
                    task.wait(0.1)
                    applyItemESP(o)
                end
            end)
        else
            if itemConnection then
                itemConnection:Disconnect()
                itemConnection = nil
            end
            activeItemNametags = {}
            for _, o in ipairs(workspace:GetDescendants()) do
                local added = o:FindFirstChild("ESP_Added")
                if added then added:Destroy() end
            end
        end
    end
})

EspTab:CreateToggle({
    Name = "Disable Item Esp Nametags",
    CurrentValue = false,
    Flag = "ItemDisableNametagsToggle",
    Callback = function(v)
        itemDisableNametags = v
        for _, tag in ipairs(activeItemNametags) do
            if tag and tag.Parent then
                tag.Enabled = not itemDisableNametags
            end
        end
    end
})

-- --- SUBSEÇÃO: HALLOWEEN EVENT ESP ---
EspTab:CreateSection("Halloween Event ESP")

local halloweenCardsEspEnabled = false
local halloweenCardsDisableNametags = false
local activeHalloweenCardsNametags = {}
local halloweenCardsConnection = nil

local function applyHalloweenCardsESP(obj)
    if not obj or obj.Name ~= "CollectablePiece" or obj:FindFirstChild("HalloweenCardESP") then return end

    local folder = Instance.new("Folder")
    folder.Name = "HalloweenCardESP"
    folder.Parent = obj

    local highlight = Instance.new("Highlight")
    highlight.Name = "Chams"
    highlight.Adornee = obj
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
    highlight.Parent = folder

    local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or (obj:IsA("BasePart") and obj)
    if part then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "Nametag"
        billboard.Adornee = part
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Enabled = not halloweenCardsDisableNametags
        billboard.Parent = folder

        table.insert(activeHalloweenCardsNametags, billboard)

        local textLabel = Instance.new("TextLabel", billboard)
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "Halloween Card"
        textLabel.TextSize = 9
        textLabel.Font = Enum.Font.FredokaOne
        textLabel.TextStrokeTransparency = 0
        textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

        task.spawn(function()
            local orange = Color3.fromRGB(255, 128, 0)
            local purple = Color3.fromRGB(148, 0, 211)
            while halloweenCardsEspEnabled and obj and obj.Parent and highlight and textLabel do
                local alpha = math.abs(((tick() / 2) % 2) - 1)
                local lerpedColor = orange:Lerp(purple, alpha)
                highlight.FillColor = lerpedColor
                textLabel.TextColor3 = lerpedColor
                task.wait(0.1)
            end
        end)
    end
end

EspTab:CreateToggle({
    Name = "Esp Halloween Cards",
    CurrentValue = false,
    Flag = "HalloweenCardsEspToggle",
    Callback = function(v)
        halloweenCardsEspEnabled = v
        if halloweenCardsEspEnabled then
            for _, obj in ipairs(workspace:GetDescendants()) do
                applyHalloweenCardsESP(obj)
            end
            if halloweenCardsConnection then halloweenCardsConnection:Disconnect() end
            halloweenCardsConnection = workspace.DescendantAdded:Connect(function(obj)
                if halloweenCardsEspEnabled then
                    task.wait(0.1)
                    applyHalloweenCardsESP(obj)
                end
            end)
        else
            if halloweenCardsConnection then
                halloweenCardsConnection:Disconnect()
                halloweenCardsConnection = nil
            end
            activeHalloweenCardsNametags = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                local espFolder = obj:FindFirstChild("HalloweenCardESP")
                if espFolder then espFolder:Destroy() end
            end
        end
    end
})

EspTab:CreateToggle({
    Name = "Disable Halloween Cards Nametags",
    CurrentValue = false,
    Flag = "DisableHalloweenCardsNametagsToggle",
    Callback = function(v)
        halloweenCardsDisableNametags = v
        for _, tag in ipairs(activeHalloweenCardsNametags) do
            if tag and tag.Parent then
                tag.Enabled = not halloweenCardsDisableNametags
            end
        end
    end
})

local halloweenDoorsEspEnabled = false
local halloweenDoorsDisableNametags = false
local activeHalloweenDoorsNametags = {}
local halloweenDoorsConnection = nil

local function applyHalloweenDoorsESP(obj)
    if not obj or obj.Name ~= "TrickOrTreatDoor_Origin" or obj:FindFirstChild("HalloweenDoorESP") then return end

    local folder = Instance.new("Folder")
    folder.Name = "HalloweenDoorESP"
    folder.Parent = obj

    local highlight = Instance.new("Highlight")
    highlight.Name = "Chams"
    highlight.Adornee = obj
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
    highlight.Parent = folder

    local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or (obj:IsA("BasePart") and obj)
    if part then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "Nametag"
        billboard.Adornee = part
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Enabled = not halloweenDoorsDisableNametags
        billboard.Parent = folder

        table.insert(activeHalloweenDoorsNametags, billboard)

        local textLabel = Instance.new("TextLabel", billboard)
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "Halloween Door"
        textLabel.TextSize = 9
        textLabel.Font = Enum.Font.FredokaOne
        textLabel.TextStrokeTransparency = 0
        textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

        task.spawn(function()
            local orange = Color3.fromRGB(255, 128, 0)
            local purple = Color3.fromRGB(148, 0, 211)
            while halloweenDoorsEspEnabled and obj and obj.Parent and highlight and textLabel do
                local alpha = math.abs(((tick() / 2) % 2) - 1)
                local lerpedColor = orange:Lerp(purple, alpha)
                highlight.FillColor = lerpedColor
                textLabel.TextColor3 = lerpedColor
                task.wait(0.1)
            end
        end)
    end
end

EspTab:CreateToggle({
    Name = "Esp Halloween Doors",
    CurrentValue = false,
    Flag = "HalloweenDoorsEspToggle",
    Callback = function(v)
        halloweenDoorsEspEnabled = v
        if halloweenDoorsEspEnabled then
            for _, obj in ipairs(workspace:GetDescendants()) do
                applyHalloweenDoorsESP(obj)
            end
            if halloweenDoorsConnection then halloweenDoorsConnection:Disconnect() end
            halloweenDoorsConnection = workspace.DescendantAdded:Connect(function(obj)
                if halloweenDoorsEspEnabled then
                    task.wait(0.1)
                    applyHalloweenDoorsESP(obj)
                end
            end)
        else
            if halloweenDoorsConnection then
                halloweenDoorsConnection:Disconnect()
                halloweenDoorsConnection = nil
            end
            activeHalloweenDoorsNametags = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                local espFolder = obj:FindFirstChild("HalloweenDoorESP")
                if espFolder then espFolder:Destroy() end
            end
        end
    end
})

EspTab:CreateToggle({
    Name = "Disable Halloween Doors Nametags",
    CurrentValue = false,
    Flag = "DisableHalloweenDoorsNametagsToggle",
    Callback = function(v)
        halloweenDoorsDisableNametags = v
        for _, tag in ipairs(activeHalloweenDoorsNametags) do
            if tag and tag.Parent then
                tag.Enabled = not halloweenDoorsDisableNametags
            end
        end
    end
})

EspTab:CreateSection("Machine ESP")

local generatorEspEnabled = false
local generatorDisableNametags = false
local activeGeneratorNametags = {}
local generatorConn = nil

local function isMachineCompleted(model)
    local stats = model:FindFirstChild("Stats") or (model.Parent and model.Parent:FindFirstChild("Stats"))
    if stats then
        local completed = stats:FindFirstChild("Completed")
        if completed and completed.Value == true then
            return true
        end
    end
    return false
end

EspTab:CreateToggle({
    Name = "Machine Esp",
    CurrentValue = false,
    Flag = "GeneratorEspToggle",
    Callback = function(v)
        generatorEspEnabled = v
        if generatorEspEnabled then
            local ignoredNames = {
                ["VendingMachine"] = true, ["Cooking_ExpressoMachine"] = true,
                ["DanceMachine"] = true, ["Gachapon_Arcade_01"] = true,
                ["Gachapon_Arcade_02"] = true, ["Gachapon_Arcade_03"] = true
            }

            local function applyESP(model)
                if not model or not model:IsA("Model") or ignoredNames[model.Name] or model.Name == "BaseMachine" or model:FindFirstChild("CustomESP") then return end
                
                local nameLower = model.Name:lower()
                local isMachine = (nameLower == "generator" or nameLower == "generators" or nameLower:find("generator") or nameLower:find("dual_generator") or nameLower:find("machine"))
                if not isMachine then return end

                if isMachineCompleted(model) then return end

                local folder = Instance.new("Folder")
                folder.Name = "CustomESP"
                folder.Parent = model

                local highlight = Instance.new("Highlight")
                highlight.Name = "Chams"
                highlight.Adornee = model
                highlight.FillColor = Color3.fromRGB(80, 80, 80)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.FillTransparency = 0.4
                highlight.OutlineTransparency = 0
                highlight.Parent = folder

                local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local billboard = Instance.new("BillboardGui")
                    billboard.Name = "Nametag"
                    billboard.Adornee = part
                    billboard.Size = UDim2.new(0, 200, 0, 50)
                    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
                    billboard.AlwaysOnTop = true
                    billboard.Enabled = not generatorDisableNametags
                    billboard.Parent = folder

                    table.insert(activeGeneratorNametags, billboard)

                    local textLabel = Instance.new("TextLabel", billboard)
                    textLabel.Size = UDim2.new(1, 0, 1, 0)
                    textLabel.BackgroundTransparency = 1
                    textLabel.Text = "Machine | 0/0"
                    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    textLabel.TextSize = 9
                    textLabel.Font = Enum.Font.FredokaOne
                    textLabel.TextStrokeTransparency = 0
                    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

                    task.spawn(function()
                        while generatorEspEnabled and model and model.Parent and folder and folder.Parent do
                            if model.Name == "BaseMachine" or isMachineCompleted(model) then
                                folder:Destroy()
                                break
                            end

                            local requiredVal = model:FindFirstChild("RequiredAmount", true)
                            local currentVal = model:FindFirstChild("CurrentAmount", true)
                            local connieVal = model:FindFirstChild("Connie", true)

                            local reqAmt = requiredVal and requiredVal.Value or 0
                            local curAmt = currentVal and currentVal.Value or 0

                            -- Simplifica número do CurrentAmount (ex: 32.9 -> 32)
                            local simpleCurAmt = math.floor(tonumber(curAmt) or 0)

                            if connieVal and connieVal.Value == true then
                                highlight.FillColor = Color3.fromRGB(135, 206, 250)
                                highlight.OutlineColor = Color3.fromRGB(135, 206, 250)
                                textLabel.TextColor3 = Color3.fromRGB(135, 206, 250)
                                textLabel.Text = "Possesed Machine"
                            else
                                highlight.FillColor = Color3.fromRGB(80, 80, 80)
                                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                                textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                                textLabel.Text = "Machine | " .. tostring(simpleCurAmt) .. "/" .. tostring(reqAmt)
                            end

                            task.wait(0.2)
                        end
                    end)
                end
            end

            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") then applyESP(obj) end
            end

            if not generatorConn then
                generatorConn = workspace.DescendantAdded:Connect(function(obj)
                    if generatorEspEnabled and obj:IsA("Model") then
                        task.wait(0.1)
                        if obj.Name == "BaseMachine" then
                            local custom = obj:FindFirstChild("CustomESP")
                            if custom then custom:Destroy() end
                        else
                            applyESP(obj)
                        end
                    end
                end)
            end
        else
            if generatorConn then
                generatorConn:Disconnect()
                generatorConn = nil
            end
            activeGeneratorNametags = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") then
                    local custom = obj:FindFirstChild("CustomESP")
                    if custom then custom:Destroy() end
                end
            end
        end
    end
})

EspTab:CreateToggle({
    Name = "Disable Machine Esp Nametags",
    CurrentValue = false,
    Flag = "GeneratorDisableNametagsToggle",
    Callback = function(v)
        generatorDisableNametags = v
        for _, tag in ipairs(activeGeneratorNametags) do
            if tag and tag.Parent then tag.Enabled = not generatorDisableNametags end
        end
    end
})

EspTab:CreateSection("Ichor Puddles ESP")

local ichorEspEnabled = false
local ichorDisableNametags = false
local activeIchorNametags = {}
local ichorConnection = nil

local function applyIchor(obj)
    if obj:FindFirstChild("IchorESP") then return end
    local name = obj.Name
    if name == "Ichor_Puddle_01" or name == "Ichor_Puddle_02" or name == "Ichor_Puddle_03" or name == "FinnIchorPuddle" then
        local folder = Instance.new("Folder")
        folder.Name = "IchorESP"
        folder.Parent = obj

        local highlight = Instance.new("Highlight", folder)
        highlight.Adornee = obj
        highlight.FillColor = Color3.fromRGB(0, 0, 0)
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0

        local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or (obj:IsA("BasePart") and obj)
        if part then
            local bb = Instance.new("BillboardGui", folder)
            bb.Name = "Nametag"
            bb.Adornee = part
            bb.Size = UDim2.new(0, 200, 0, 50)
            bb.StudsOffset = Vector3.new(0, 2.5, 0)
            bb.AlwaysOnTop = true
            bb.Enabled = not ichorDisableNametags

            table.insert(activeIchorNametags, bb)

            local txt = Instance.new("TextLabel", bb)
            txt.Size = UDim2.new(1, 0, 1, 0)
            txt.BackgroundTransparency = 1
            txt.Text = (name == "FinnIchorPuddle") and "Finn Ichor Puddle" or "Ichor Puddle"
            txt.TextColor3 = Color3.fromRGB(0, 0, 0)
            txt.TextSize = 9
            txt.Font = Enum.Font.FredokaOne
            txt.TextStrokeTransparency = 0
            txt.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)

            if name == "FinnIchorPuddle" then
                task.spawn(function()
                    local c1 = Color3.fromRGB(135, 206, 250)
                    local c2 = Color3.fromRGB(0, 0, 0)
                    while ichorEspEnabled and obj and obj.Parent and highlight and txt do
                        local alpha = math.abs(((tick() / 2) % 2) - 1)
                        local lerped = c1:Lerp(c2, alpha)
                        highlight.FillColor = lerped
                        highlight.OutlineColor = lerped
                        txt.TextColor3 = lerped
                        task.wait(0.15)
                    end
                end)
            end
        end
    end
end

EspTab:CreateToggle({
    Name = "Ichor Puddles Esp",
    CurrentValue = false,
    Flag = "IchorPuddlesEspToggle",
    Callback = function(v)
        ichorEspEnabled = v
        if ichorEspEnabled then
            for _, obj in ipairs(workspace:GetDescendants()) do applyIchor(obj) end
            
            if ichorConnection then ichorConnection:Disconnect() end
            ichorConnection = workspace.DescendantAdded:Connect(function(obj)
                if ichorEspEnabled then
                    task.wait(0.1)
                    applyIchor(obj)
                end
            end)
        else
            if ichorConnection then
                ichorConnection:Disconnect()
                ichorConnection = nil
            end
            activeIchorNametags = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                local custom = obj:FindFirstChild("IchorESP")
                if custom then custom:Destroy() end
            end
        end
    end
})

EspTab:CreateToggle({
    Name = "Disable Ichor Puddles Nametags",
    CurrentValue = false,
    Flag = "IchorDisableNametagsToggle",
    Callback = function(v)
        ichorDisableNametags = v
        for _, tag in ipairs(activeIchorNametags) do
            if tag and tag.Parent then tag.Enabled = not ichorDisableNametags end
        end
    end
})

EspTab:CreateSection("Elevators ESP")

local elevatorEspEnabled = false
local elevatorDisableNametags = false
local activeElevatorNametags = {}
local elevatorConnection = nil

local function applyElevator(obj)
    if obj:FindFirstChild("ElevatorESP") or obj.Name ~= "ElevatorDoor" then return end
    
    local folder = Instance.new("Folder")
    folder.Name = "ElevatorESP"
    folder.Parent = obj

    local highlight = Instance.new("Highlight", folder)
    highlight.Adornee = obj
    highlight.FillColor = Color3.fromRGB(0, 0, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
    highlight.OutlineTransparency = 0

    local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or (obj:IsA("BasePart") and obj)
    if part then
        local bb = Instance.new("BillboardGui", folder)
        bb.Name = "Nametag"
        bb.Adornee = part
        bb.Size = UDim2.new(0, 200, 0, 50)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Enabled = not elevatorDisableNametags

        table.insert(activeElevatorNametags, bb)

        local txt = Instance.new("TextLabel", bb)
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Text = "Elevator"
        txt.TextColor3 = Color3.fromRGB(255, 255, 255)
        txt.TextSize = 12
        txt.Font = Enum.Font.FredokaOne
        txt.TextStrokeTransparency = 0
    end
end

EspTab:CreateToggle({
    Name = "Elevator Esp",
    CurrentValue = false,
    Flag = "ElevatorEspToggle",
    Callback = function(v)
        elevatorEspEnabled = v
        if elevatorEspEnabled then
            for _, obj in ipairs(workspace:GetDescendants()) do applyElevator(obj) end
            
            if elevatorConnection then elevatorConnection:Disconnect() end
            elevatorConnection = workspace.DescendantAdded:Connect(function(obj)
                if elevatorEspEnabled then
                    task.wait(0.1)
                    applyElevator(obj)
                end
            end)
        else
            if elevatorConnection then
                elevatorConnection:Disconnect()
                elevatorConnection = nil
            end
            activeElevatorNametags = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                local custom = obj:FindFirstChild("ElevatorESP")
                if custom then custom:Destroy() end
            end
        end
    end
})

EspTab:CreateToggle({
    Name = "Disable Elevator Esp Nametags",
    CurrentValue = false,
    Flag = "ElevatorDisableNametagsToggle",
    Callback = function(v)
        elevatorDisableNametags = v
        for _, tag in ipairs(activeElevatorNametags) do
            if tag and tag.Parent then tag.Enabled = not elevatorDisableNametags end
        end
    end
})

local fakeElevatorEspEnabled = false
local fakeElevatorDisableNametags = false
local activeFakeElevatorNametags = {}
local fakeElevatorConnection = nil

local function applyFakeElevator(obj)
    if obj:FindFirstChild("FakeElevatorESP") then return end
    if obj.Name:lower():find("fakeelevator") or obj.Name:lower():find("fake_elevator") then
        local folder = Instance.new("Folder")
        folder.Name = "FakeElevatorESP"
        folder.Parent = obj

        local highlight = Instance.new("Highlight", folder)
        highlight.Adornee = obj
        highlight.FillColor = Color3.fromRGB(255, 255, 150)
        highlight.FillTransparency = 0.7
        highlight.OutlineColor = Color3.fromRGB(255, 255, 150)
        highlight.OutlineTransparency = 0.5

        local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or (obj:IsA("BasePart") and obj)
        if part then
            local bb = Instance.new("BillboardGui", folder)
            bb.Name = "Nametag"
            bb.Adornee = part
            bb.Size = UDim2.new(0, 200, 0, 50)
            bb.StudsOffset = Vector3.new(0, 2.5, 0)
            bb.AlwaysOnTop = true
            bb.Enabled = not fakeElevatorDisableNametags

            table.insert(activeFakeElevatorNametags, bb)

            local txt = Instance.new("TextLabel", bb)
            txt.Size = UDim2.new(1, 0, 1, 0)
            txt.BackgroundTransparency = 1
            txt.Text = "Fake Elevator"
            txt.TextColor3 = Color3.fromRGB(255, 255, 150)
            txt.TextSize = 12
            txt.Font = Enum.Font.FredokaOne
            txt.TextStrokeTransparency = 0
        end
    end
end

EspTab:CreateToggle({
    Name = "Fake Elevator Esp",
    CurrentValue = false,
    Flag = "FakeElevatorEspToggle",
    Callback = function(v)
        fakeElevatorEspEnabled = v
        if fakeElevatorEspEnabled then
            for _, obj in ipairs(workspace:GetDescendants()) do applyFakeElevator(obj) end
            
            if fakeElevatorConnection then fakeElevatorConnection:Disconnect() end
            fakeElevatorConnection = workspace.DescendantAdded:Connect(function(obj)
                if fakeElevatorEspEnabled then
                    task.wait(0.1)
                    applyFakeElevator(obj)
                end
            end)
        else
            if fakeElevatorConnection then
                fakeElevatorConnection:Disconnect()
                fakeElevatorConnection = nil
            end
            activeFakeElevatorNametags = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                local custom = obj:FindFirstChild("FakeElevatorESP")
                if custom then custom:Destroy() end
            end
        end
    end
})

EspTab:CreateToggle({
    Name = "Disable Fake Elevator Nametags",
    CurrentValue = false,
    Flag = "FakeElevatorDisableNametagsToggle",
    Callback = function(v)
        fakeElevatorDisableNametags = v
        for _, tag in ipairs(activeFakeElevatorNametags) do
            if tag and tag.Parent then tag.Enabled = not fakeElevatorDisableNametags end
        end
    end
})

-- ==============================================================================
-- TELEPORT TAB
-- ==============================================================================
local TeleportTab = Window:CreateTab("Teleport", 122323156868835)

TeleportTab:CreateButton({ Name = "Teleport To Elevator", Callback = function() 
    if not Character or not HumanoidRootPart then return end
    local elevatorsFolder = Workspace:FindFirstChild("Elevators")
    local targetPos = nil
    if elevatorsFolder then
        local elevator = elevatorsFolder:FindFirstChild("Elevator") or elevatorsFolder:FindFirstChildOfClass("Model")
        if elevator then
            local part = elevator.PrimaryPart or elevator:FindFirstChildWhichIsA("BasePart", true)
            if part then targetPos = part.Position end
        end
    end
    if not targetPos then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Elevator" or obj.Name == "ElevatorDoor" then
                local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or (obj:IsA("BasePart") and obj)
                if part then targetPos = part.Position; break end
            end
        end
    end
    if targetPos then
        if isTwistedNearby(targetPos, 30) then
            WindUI:Notify({ Title = "Teleport", Content = "Twisted Nearby.", Duration = 2 })
            return
        end
        HumanoidRootPart.CFrame = CFrame.new(targetPos) + Vector3.new(0, 3, 0)
    else
        teleportTo("elevator", false)
    end
end })

TeleportTab:CreateButton({ 
    Name = "Teleport To Machine", 
    Callback = function()
        performTeleportToMachine()
    end 
})

-- Botão Flutuante (ScreenGui) para o Teleport To Machine Button
local screenGuiButton = nil

TeleportTab:CreateToggle({
    Name = "Teleport To Machine Button",
    CurrentValue = false,
    Flag = "TpMachineButtonToggle",
    Callback = function(v)
        if v then
            if not screenGuiButton then
                local sg = Instance.new("ScreenGui")
                sg.Name = "TpMachineButtonGui"
                sg.ResetOnSpawn = false

                -- Tenta anexar ao CoreGui, senão usa PlayerGui
                local parentGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                pcall(function()
                    if gethui then
                        parentGui = gethui()
                    elseif game:GetService("CoreGui") then
                        parentGui = game:GetService("CoreGui")
                    end
                end)
                sg.Parent = parentGui

                local imgButton = Instance.new("ImageButton")
                imgButton.Name = "TpMachineBtn"
                imgButton.Size = UDim2.new(0, 65, 0, 65) -- Tamanho pequeno e discreto
                imgButton.Position = UDim2.new(0.85, 0, 0.5, 0)
                imgButton.BackgroundTransparency = 1
                imgButton.Image = "rbxassetid://123753414381011"
                imgButton.ScaleType = Enum.ScaleType.Fit
                imgButton.Active = true
                imgButton.Draggable = true -- Permite arrastar o botão pela tela
                imgButton.Parent = sg

                -- Efeito visual ao clicar no botão
                imgButton.MouseButton1Down:Connect(function()
                    imgButton.Size = UDim2.new(0, 58, 0, 58)
                end)

                imgButton.MouseButton1Up:Connect(function()
                    imgButton.Size = UDim2.new(0, 65, 0, 65)
                end)

                imgButton.MouseButton1Click:Connect(function()
                    performTeleportToMachine()
                end)

                screenGuiButton = sg
            end
        else
            if screenGuiButton then
                screenGuiButton:Destroy()
                screenGuiButton = nil
            end
        end
    end
})

TeleportTab:CreateSection("Items Teleport")
local itemsList = {"AirHorn", "SmokeBomb", "ResearchCapsule", "ProteinBar", "Jawbreaker", "EjectButton", "HealthKit", "Bandage", "Tape", "Instructions", "ExtractionSpeedCandy", "SkillCheckCandy", "StaminaCandy", "StealthCandy", "SpeedCandy", "Gumball", "BonBon", "Chocolate", "ChocolateBox", "Pop", "PopBottle", "JumperCable", "Stopwatch", "ChristmasCookie", "DandyEasterEggs", "Pumpkin", "FakeCapsule"}
local selectedItem = itemsList[1]
TeleportTab:CreateDropdown({ Name = "Select Your Item", Options = itemsList, CurrentOption = {itemsList[1]}, Flag = "SelectedItemTp", Callback = function(opt) selectedItem = type(opt) == "table" and opt[1] or opt end })
TeleportTab:CreateButton({ Name = "Teleport to Selected Item", Callback = function() teleportTo(selectedItem, true) end })

-- ==============================================================================
-- PLAYER TAB
-- ==============================================================================
local PlayerTab = Window:CreateTab("Player", 73824491911988)

PlayerTab:CreateButton({
    Name = "Anti Lag",
    Callback = function()
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9

            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") then
                    v.Enabled = false
                end
            end

            local function optimizeObject(object)
                if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") or object:IsA("Light") then
                    object.Enabled = false
                elseif object:IsA("BasePart") then
                    object.Material = Enum.Material.SmoothPlastic
                    object.Reflectance = 0
                    object.CastShadow = false
                elseif object:IsA("Decal") or object:IsA("Texture") then
                    object.Transparency = 1
                end
            end

            for _, descendant in pairs(Workspace:GetDescendants()) do optimizeObject(descendant) end
            Workspace.DescendantAdded:Connect(function(descendant)
                task.wait()
                optimizeObject(descendant)
            end)
        end)
    end
})

local noSlipperyEnabled = false
local defaultPhysicalProperties = {}
local brakeConnection = nil

PlayerTab:CreateToggle({
    Name = "No Slippery",
    CurrentValue = false,
    Flag = "NoSlipperyToggle",
    Callback = function(v)
        noSlipperyEnabled = v
        local char = LocalPlayer.Character
        
        if noSlipperyEnabled then
            local physicalProperties = PhysicalProperties.new(15.0, 3.0, 0.0, 1.0, 1.0)
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not defaultPhysicalProperties[part] then defaultPhysicalProperties[part] = part.CustomPhysicalProperties end
                        part.CustomPhysicalProperties = physicalProperties
                    end
                end
            end

            if not brakeConnection then
                brakeConnection = RunService.RenderStepped:Connect(function(dt)
                    if not noSlipperyEnabled then return end
                    local currentCharacter = LocalPlayer.Character
                    if not currentCharacter then return end
                    
                    local humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
                    local rootPart = currentCharacter:FindFirstChild("HumanoidRootPart")
                    
                    if humanoid and rootPart and humanoid.Health > 0 then
                        local velocity = rootPart.AssemblyLinearVelocity
                        local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
                        if humanoid.MoveDirection.Magnitude == 0 and horizontalVelocity.Magnitude > 0.5 then
                            local brakeFactor = math.clamp(dt * 25, 0, 1)
                            rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X * (1 - brakeFactor), velocity.Y, velocity.Z * (1 - brakeFactor))
                        end
                    end
                end)
            end
        else
            if brakeConnection then brakeConnection:Disconnect(); brakeConnection = nil end
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CustomPhysicalProperties = defaultPhysicalProperties[part]
                    end
                end
            end
            defaultPhysicalProperties = {}
        end
    end
})

LocalPlayer.CharacterAdded:Connect(function(char)
    if noSlipperyEnabled then
        task.delay(1, function()
            if noSlipperyEnabled and char then
                local physicalProperties = PhysicalProperties.new(15.0, 3.0, 0.0, 1.0, 1.0)
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CustomPhysicalProperties = physicalProperties end
                end
            end
        end)
    end
end)

local itemAuraEnabled = false
PlayerTab:CreateToggle({
    Name = "Item Aura",
    CurrentValue = false,
    Flag = "ItemAuraToggle",
    Callback = function(v)
        itemAuraEnabled = v
    end
})

task.spawn(function()
    while true do
        if itemAuraEnabled and HumanoidRootPart then
            pcall(function()
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") then
                        local parentPart = obj.Parent
                        if parentPart then
                            local promptPos = parentPart:IsA("BasePart") and parentPart.Position or (parentPart:IsA("Model") and (parentPart.PrimaryPart and parentPart.PrimaryPart.Position or parentPart:GetPivot().Position))
                            if promptPos then
                                -- Checa se está perto do jogador
                                if (promptPos - HumanoidRootPart.Position).Magnitude <= (obj.MaxActivationDistance or 15) then
                                    -- Checa se NÃO está dentro/próximo de GourdyMonster ou FakeCapsule
                                    local isForbidden = false
                                    local currentAncestor = parentPart
                                    while currentAncestor and currentAncestor ~= workspace do
                                        if currentAncestor.Name == "GourdyMonster" or currentAncestor.Name == "FakeCapsule" then
                                            isForbidden = true
                                            break
                                        end
                                        currentAncestor = currentAncestor.Parent
                                    end

                                    -- Checa se NÃO está próximo de um Elevator (15 studs)
                                    local isNearElevator = isElevatorNearby(promptPos, 15)

                                    if not isForbidden and not isNearElevator and canInteractWithPosition(promptPos) then
                                        fireproximityprompt(obj)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
        task.wait(0.1) -- Loop rápido para ativação instantânea do prompt
    end
end)

PlayerTab:CreateButton({
    Name = "Infinite Stamina",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/abelsrighthand/AbstractLite/refs/heads/main/abstractlite(infstam).lua"))()
        end)
    end
})

PlayerTab:CreateButton({
    Name = "Ability Infinite Range",
    Callback = function()
        pcall(function()
            local toonsTable = {Shelly = true, Sprout = true, Cosmo = true, Scraps = true, Glisten = true}
            for _, conn in pairs(getconnections(RunService.RenderStepped)) do
                local func = conn.Function
                if func then
                    local ok, upvals = pcall(getupvalues, func)
                    if ok and upvals then
                        for _, val in pairs(upvals) do
                            if typeof(val) == "table" and val.Name and toonsTable[val.Name] and val.PlayerRadius then
                                val.PlayerRadius = 500
                            end
                        end
                    end
                end
            end
        end)
    end
})

-- ==============================================================================
-- MACHINE TAB
-- ==============================================================================
local MachineTab = Window:CreateTab("Machine", 120555476154580)
MachineTab:CreateToggle({ Name = "Instant Skillcheck", CurrentValue = false, Flag = "InstantSkillcheck", Callback = function(v) getgenv().scinstant = v end })

local instantStashGigiEnabled = false
local originalHoldDurations = {}

MachineTab:CreateToggle({
    Name = "Instant Stash Gigi Machine Prompt",
    CurrentValue = false,
    Flag = "InstantStashGigiPrompt",
    Callback = function(v)
        instantStashGigiEnabled = v
        if instantStashGigiEnabled then
            task.spawn(function()
                while instantStashGigiEnabled do
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            if not originalHoldDurations[obj] then originalHoldDurations[obj] = obj.HoldDuration end
                            obj.HoldDuration = 0
                        end
                    end
                    task.wait(2)
                end
            end)
        else
            for prompt, originalDuration in pairs(originalHoldDurations) do
                if prompt and prompt.Parent then prompt.HoldDuration = originalDuration end
            end
            originalHoldDurations = {}
        end
    end
})

MachineTab:CreateButton({ 
    Name = "Auto Arcade Machine", 
    Callback = function() 
        pcall(function() 
            loadstring(game:HttpGet("https://raw.githubusercontent.com/christmas-cookie/extensions/refs/heads/main/arcademachine", true))() 
        end) 
    end 
})

local autoSwimmyEnabled = false
MachineTab:CreateToggle({
    Name = "Auto Swimmy Barnaby Machine (LOBBY)",
    CurrentValue = false,
    Flag = "AutoSwimmyToggle",
    Callback = function(v)
        autoSwimmyEnabled = v
    end
})

task.spawn(function()
    pcall(function()
        local sharedData = ReplicatedStorage:FindFirstChild("SharedData")
        if not sharedData then return end
        local arcadeGames = sharedData:FindFirstChild("ArcadeGames")
        if not arcadeGames then return end
        local barnabymodule = require(arcadeGames:WaitForChild("SwimmyBarnaby"))
        local pg = LocalPlayer:WaitForChild("PlayerGui")

        local function barnabify(session)
            if not autoSwimmyEnabled then return end
            session.forcekill = false

            if type(session.tick) == "function" or (getmetatable(session) and session.tick) then
                local oldtick = session.tick
                session.tick = function(self, ...)
                    if not autoSwimmyEnabled then return oldtick(self, ...) end
                    if self.forcekill then return -1 end
                    local result = oldtick(self, ...)
                    return (result == -1) and 0 or result
                end
            end

            if type(session.Jump) == "function" then session.Jump = function() end end
            if session.Fish and type(session.Fish.Jump) == "function" then session.Fish.Jump = function() end end

            pcall(function()
                local uisource = arcadeGames.SwimmyBarnaby.ClientUI
                local customui = uisource:Clone()
                customui.Name = "end me"
                if customui:IsA("ScreenGui") then customui.DisplayOrder = 999999999 end
                customui.Parent = pg

                local bottom = customui.Bottom
                local mobile = bottom.Mobile
                local unpressed = mobile.Unpressed
                local textlabel = unpressed.TextLabel
                
                textlabel.Text = "END GAME"
                bottom.Visible = true
                bottom.ZIndex = 9e9

                mobile.Activated:Connect(function()
                    session.forcekill = true
                    customui:Destroy()
                end)
            end)

            if session.Fish then
                pcall(function() session.Fish:SetGravity(0) end)
                if session.Fish.Part then
                    task.spawn(function()
                        while session.SessionId and not session.forcekill and autoSwimmyEnabled do
                            pcall(function()
                                local cf = session.Fish.Part:GetPivot()
                                session.Fish.Part:PivotTo(CFrame.new(cf.X, 0, cf.Z))
                            end)
                            task.wait()
                        end
                    end)
                end
            end

            task.spawn(function()
                while session.SessionId and not session.forcekill and autoSwimmyEnabled do
                    pcall(function()
                        if session.Parent then
                            for _, child in ipairs(session.Parent:GetChildren()) do
                                if child:IsA("Model") and (child.Name:find("Obstacle") or child:FindFirstChild("BendySeaweed")) then
                                    for _, descendant in ipairs(child:GetDescendants()) do
                                        if descendant:IsA("BasePart") then descendant:Destroy() end
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.3)
                end
            end)
        end

        local oldstart = barnabymodule.Start
        barnabymodule.Start = function(self, creators)
            if autoSwimmyEnabled and creators and creators.Obstacle then
                local oldvein = creators.Obstacle
                creators.Obstacle = function(...)
                    local vein = oldvein(...)
                    if vein and vein.Model then
                        pcall(function()
                            for _, part in ipairs(vein.Model:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = false
                                    part.CanTouch = false
                                end
                            end
                        end)
                    end
                    return vein
                end
            end
            local res = oldstart(self, creators)
            if autoSwimmyEnabled then barnabify(self) end
            return res
        end

        task.spawn(function()
            while true do
                if autoSwimmyEnabled then
                    for _, v in ipairs(getgc(true)) do
                        if type(v) == "table" and rawget(v, "GAME_CONFIG") and rawget(v, "SessionId") then
                            barnabify(v)
                        end
                    end
                end
                task.wait(2.5)
            end
        end)
    end)
end)

task.spawn(function()
    getgenv().scinstant = false
    pcall(function()
        local events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
        if events then
            local event = events:FindFirstChild("SkillcheckUpdate")
            if event and getcallbackvalue then
                local ogcb = getcallbackvalue(event, "OnClientInvoke")
                if ogcb then
                    local hook
                    hook = hookfunction(ogcb, function(...)
                        if getgenv().scinstant then return "supercomplete" end
                        return hook(...)
                    end)
                end
            end
        end
    end)
end)

-- ==============================================================================
-- MAP TAB
-- ==============================================================================
local MapTab = Window:CreateTab("Map", 113248535106613)

local altFbConn = nil
MapTab:CreateToggle({
    Name = "Alternative Fullbright",
    CurrentValue = false,
    Flag = "AltFullbrightToggle",
    Callback = function(v)
        if v then
            local function setFb()
                Lighting.Brightness, Lighting.GlobalShadows, Lighting.OutdoorAmbient, Lighting.Ambient, Lighting.ClockTime, Lighting.FogEnd, Lighting.FogStart = 2, true, Color3.fromRGB(120,120,120), Color3.fromRGB(100,100,100), 14, 100000, 0
            end
            setFb()
            altFbConn = Lighting.Changed:Connect(setFb)
        else
            if altFbConn then altFbConn:Disconnect(); altFbConn = nil end
            Lighting.Brightness = 1; Lighting.GlobalShadows = true; Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127); Lighting.Ambient = Color3.fromRGB(0, 0, 0); Lighting.ClockTime = 12; Lighting.FogEnd = 10000
        end
    end
})

local fbConn = nil
MapTab:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Flag = "FullbrightToggle",
    Callback = function(v)
        if v then
            local function clearFogAndBright()
                Lighting.Brightness = 3; Lighting.ClockTime = 14; Lighting.FogEnd = 999999; Lighting.FogStart = 0; Lighting.GlobalShadows = false; Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255); Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            end
            clearFogAndBright()
            fbConn = RunService.RenderStepped:Connect(clearFogAndBright)
        else
            if fbConn then fbConn:Disconnect(); fbConn = nil end
            Lighting.Brightness = 1; Lighting.ClockTime = 12; Lighting.FogEnd = 10000; Lighting.FogStart = 0; Lighting.GlobalShadows = true; Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127); Lighting.Ambient = Color3.fromRGB(0, 0, 0)
        end
    end
})

-- ==============================================================================
-- FUN TAB
-- ==============================================================================
local FunTab = Window:CreateTab("Fun", 71680025256265)

local spinning = false
local spinSpeed = 25
local spinConnection = nil

FunTab:CreateToggle({ Name = "Spin", CurrentValue = false, Callback = function(v)
    spinning = v
    if spinning then
        spinConnection = RunService.RenderStepped:Connect(function()
            if HumanoidRootPart then
                HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(0, math.rad(spinSpeed), 0)
            end
        end)
    else
        if spinConnection then spinConnection:Disconnect(); spinConnection = nil end
    end
end })

FunTab:CreateSlider({ Name = "Spin Speed", Range = {1, 100}, Increment = 1, CurrentValue = 25, Flag = "SpinSpeedFlag", Callback = function(v) spinSpeed = v end })

local fovEnabled = false
local fovValue = 70
local fovConnection = nil

FunTab:CreateToggle({
    Name = "FOV Changer",
    CurrentValue = false,
    Flag = "FovToggle",
    Callback = function(v)
        fovEnabled = v
        if fovEnabled then
            fovConnection = RunService.RenderStepped:Connect(function()
                if Camera then Camera.FieldOfView = fovValue end
            end)
        else
            if fovConnection then fovConnection:Disconnect(); fovConnection = nil end
            if Camera then Camera.FieldOfView = 70 end
        end
    end
})

FunTab:CreateSlider({
    Name = "FOV Value", Range = {10, 120}, Increment = 1, CurrentValue = 70, Flag = "FovSlider",
    Callback = function(v)
        fovValue = v
        if fovEnabled and Camera then Camera.FieldOfView = fovValue end
    end
})

local jumpEnabled = false
local jumpPowerVal = 50
local jumpConnection = nil

FunTab:CreateToggle({ Name = "Enable Jump", CurrentValue = false, Flag = "EnableJumpToggle", Callback = function(v)
    jumpEnabled = v
    if jumpEnabled then
        jumpConnection = RunService.RenderStepped:Connect(function()
            if Humanoid then
                Humanoid.UseJumpPower = true
                Humanoid.JumpPower = jumpPowerVal
                pcall(function() LocalPlayer.Character:SetAttribute("CanJump", true) end)
            end
        end)
    else
        if jumpConnection then jumpConnection:Disconnect(); jumpConnection = nil end
    end
end })

FunTab:CreateSlider({ Name = "Jump Power", Range = {10, 250}, Increment = 5, CurrentValue = 50, Flag = "JumpPowerSlider", Callback = function(v)
    jumpPowerVal = v
    if jumpEnabled and Humanoid then
        Humanoid.UseJumpPower = true
        Humanoid.JumpPower = jumpPowerVal
    end
end })

UserInputService.JumpRequest:Connect(function()
    if jumpEnabled and Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

FunTab:CreateButton({
    Name = "HardCore Mode",
    Callback = function()
        pcall(function()
            Lighting.FogColor = Color3.fromRGB(0, 0, 0)
            Lighting.FogStart = 0
            Lighting.FogEnd = 50
            Lighting.Brightness = 0
            
            pcall(function()
                for _, sound in ipairs(workspace:GetDescendants()) do
                    if sound:IsA("Sound") then sound.Volume = 0 end
                end
                game:GetService("SoundService").Volume = 0
            end)

            task.spawn(function()
                while true do
                    pcall(function()
                        local currentRoom = Workspace:FindFirstChild("CurrentRoom")
                        if currentRoom and currentRoom:FindFirstChild("Monsters") then
                            currentRoom.Monsters:ClearAllChildren()
                        end

                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 22
                            speedValue = 22
                        end
                    end)
                    task.wait(0.5)
                end
            end)
            
            WindUI:Notify({ Title = "Good Luck. :)", Content = "", Duration = 2 })
        end)
    end
})

FunTab:CreateButton({ Name = "Kill Yourself", Callback = function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    end
end })

FunTab:CreateButton({ Name = "YouTube Music", Callback = function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/zxcursedsocute/Youtube-Music-Player-Free/refs/heads/main/loader"))()
    end)
end })
