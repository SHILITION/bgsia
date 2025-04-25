getgenv().riftHopEnabled = getgenv().riftHopEnabled or false
getgenv().showRate = getgenv().showRate or false

local Services = setmetatable({}, {__index = function(Self, Index)
    return cloneref(game:GetService(Index))
end})
local Players = Services.Players
local RunService = Services.RunService
local Workspace = Services.Workspace
local ReplicatedStorage = Services.ReplicatedStorage
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Player = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId
local wait = task.wait
local spawn = task.spawn

local StatsUtil = require(ReplicatedStorage.Shared.Utils.Stats.StatsUtil)
local Codes = require(ReplicatedStorage.Shared.Data.Codes)
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local Remote = require(ReplicatedStorage.Shared.Framework.Network.Remote)
local Constants = require(ReplicatedStorage.Shared.Constants)
local PetUtil = require(ReplicatedStorage.Shared.Utils.Stats.PetUtil)
local DataEnchants = require(ReplicatedStorage.Shared.Data.Enchants)
local EnchantsModule = require(ReplicatedStorage.Client.Gui.Frames.Enchants)
local EnchantUtil = require(ReplicatedStorage.Shared.Utils.EnchantUtil)

local Event = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("Event")
local Generic = Workspace:WaitForChild("Rendered"):WaitForChild("Generic")
local Islands = Workspace:WaitForChild("Worlds"):WaitForChild("The Overworld").Islands
local lastHatch = game.Players.LocalPlayer:WaitForChild("PlayerGui").ScreenGui:FindFirstChild("Hatching"):FindFirstChild("Last")
local currencyFrame = Player:WaitForChild("PlayerGui"):WaitForChild("ScreenGui"):WaitForChild("HUD"):WaitForChild("Left"):WaitForChild("Currency")
local rifts = Workspace.Rendered:WaitForChild("Rifts")
local CollectPickupRemote = ReplicatedStorage.Remotes.Pickups.CollectPickup
local HugeNumber = math.huge

local Eggs = {}
local Costs = {}
local Functions = {}
local Toggles = {}
local SigmaEnchants = {}
local Gum = loadstring(game:HttpGet("https://raw.githubusercontent.com/Tion-D/bgsi/refs/heads/main/gums"))()
local Flavors = loadstring(game:HttpGet("https://raw.githubusercontent.com/Tion-D/bgsi/refs/heads/main/flavors"))()
local HatchCount = 1
local HTTP_RETRY_DELAY = 5
local LOOP_DELAY = 1

for i,v in next, Generic:GetChildren() do
    if v.Name:find("Egg") and not table.find(Eggs, v.Name) then
        table.insert(Eggs, v.Name)
    end
end
local worldList = {
    "Spawn",
    "Floating Island",
    "Outer Space",
    "Twilight",
    "Zen",
    "The Void"
}
local worldDestinations = {
    ["Spawn"] = "Workspace.Worlds.The Overworld.PortalSpawn",
    ["Floating Island"] = "Workspace.Worlds.The Overworld.Islands.Floating Island.Island.Portal.Spawn",
    ["Outer Space"] = "Workspace.Worlds.The Overworld.Islands.Outer Space.Island.Portal.Spawn",
    ["Twilight"] = "Workspace.Worlds.The Overworld.Islands.Twilight.Island.Portal.Spawn",
    ["Zen"] = "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn",
    ["The Void"] = "Workspace.Worlds.The Overworld.Islands.The Void.Island.Portal.Spawn"
}

local function farmCoins(thresholdY)
    local player = Players.LocalPlayer
    local root = (player.Character or player.CharacterAdded:Wait()):WaitForChild("HumanoidRootPart")
    local startXZ = Vector3.new(root.Position.X, 0, root.Position.Z)
    local targets = {}

    for _, model in ipairs(Workspace.Stages:GetChildren()) do
        if model:IsA("Model") then
            local bestDist, bestPos = math.huge, nil
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then
                    local p = part.Position
                    if p.Y > thresholdY then
                        local d = (Vector3.new(p.X,0,p.Z) - startXZ).Magnitude
                        if d < bestDist then
                            bestDist, bestPos = d, p
                        end
                    end
                end
            end
            if bestPos then
                table.insert(targets, bestPos)
            end
        end
    end

    for _, pos in ipairs(targets) do
        local goal = { CFrame = CFrame.new(pos.X, pos.Y, pos.Z) }
        local tw = TweenService:Create(root, TweenInfo.new(1), goal)
        tw:Play(); tw.Completed:Wait()
        task.wait(0.6)
    end

    Event:FireServer("Teleport", "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn")
end

local hasRun = false

local function sendWebhook(chance, name)
    local time = math.floor(os.time() + 600)
    local timestamp = "<t:" .. time .. ":R>"

    local color
    if chance <= 0.005 then
        color = 16776960
    elseif chance <= 0.05 then
        color = 255
    else
        color = 255
    end

    if getgenv().webhook and getgenv().webhook ~= "" then
        local mention = ""
        if getgenv().UserId and getgenv().UserId ~= 0 then
            mention = "<@" .. getgenv().UserId .. ">"
        end

        local oneIn = math.floor(100 / chance)

        local data = {
            ["content"] = mention,
            ["embeds"] = { {
                ["title"] = "Pet Hatched:",
                ["description"] = "You have hatched a rare pet!",
                ["color"] = color,
                ["fields"] = {
                    {
                        ["name"] = "Pet Name",
                        ["value"] = tostring(name),
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Chance",
                        ["value"] = tostring(chance) .. "% & 1/" .. oneIn,
                        ["inline"] = true
                    }
                },
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            } }
        }

        local response = request({
            Url = getgenv().webhook,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(data)
        })

        if response.StatusCode ~= 200 then
            warn("Webhook failed with status code: " .. response.StatusCode)
        end
    end

    print("sent webhook")
end

local function WebhookMonitor()
    local hasRun = false
    while Toggles.WebhookEnabled do
        task.wait(1)
        if lastHatch.Parent.Visible and not hasRun then
            hasRun = true
            for _, v in ipairs(lastHatch:GetChildren()) do
                if v:IsA("Frame") then
                    local chanceLabel = v:FindFirstChild("Chance")
                    if chanceLabel and chanceLabel:IsA("TextLabel") then
                        local raw = chanceLabel.Text:gsub("%%","")
                        local hatchedChance = tonumber(raw)
                        local name = v.Name
                        if v.Icon and v.Icon:FindFirstChild("Label") and v.Icon.Label:FindFirstChild("Shine") then
                            name = "Shiny "..name
                        end
                        local imageId
                        if v.Icon and v.Icon:FindFirstChild("Label") then
                            imageId = v.Icon.Label.Image
                        end
                        if hatchedChance and hatchedChance <= getgenv().highestChance then
                            sendWebhook(hatchedChance, name, imageId)
                        end
                    end
                end
            end
        elseif not lastHatch.Parent.Visible then
            hasRun = false
        end
    end
end
getgenv().robloxCookie = ""
assert(getgenv().robloxCookie)

local CACHE_TTL = 60
local serverCache = {
    data = nil,
    fetchedAt = 0,
}

local function fetchServers()
    if serverCache.data and tick() - serverCache.fetchedAt < CACHE_TTL then
        return serverCache.data
    end

    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(PlaceId)  -- use your PlaceId var here
    local headers = {
        ["User-Agent"] = "Roblox/WinInet",
        ["Accept"] = "application/json",
        ["Cookie"] = ".ROBLOSECURITY=" .. getgenv().robloxCookie,
    }

    local function doRequest()
        local res = request({
            Url     = url,
            Method  = "GET",
            Headers = headers,
        })

        if not res.Success then
            if res.StatusCode == 429 then
                local retry = tonumber(res.Headers["Retry-After"]) or 1
                task.wait(retry)
                return doRequest()
            else
                error(("Failed to fetch servers: %d %s")
                      :format(res.StatusCode, res.StatusMessage or ""))
            end
        end

        local body = HttpService:JSONDecode(res.Body)
        return body.data
    end

    local data = doRequest()
    serverCache.data    = data
    serverCache.fetchedAt = tick()
    return data
end

local function hopToNext()
    local servers = fetchServers()
    for _, srv in ipairs(servers) do
        if srv.playing < srv.maxPlayers then
            local ok, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceId, srv.id, Players.LocalPlayer)
            end)
            if not ok then
                warn("Teleport busy, retrying in 3s:", err)
                task.wait(3)
                return hopToNext()
            end
            return
        end
    end
end


local flat = function(vec) return Vector3.new(vec.X, 0, vec.Z) end

local function processRift(v)
    local display = v:FindFirstChild("Display")
    local gui = display and display:FindFirstChild("SurfaceGui")
    local icon = gui and gui:FindFirstChild("Icon")
    local luck = icon and icon:FindFirstChild("Luck")
    local multNum = 0

    if luck then
        local ok = pcall(function()
            multNum = tonumber(luck.Text:match("%d+")) or 0
        end)
        if not ok then multNum = 0 end
    end

    if v.Name == "royal-chest" then
        multNum = math.huge
    end

    if table.find(SelectedRifts, v.Name)
    and (v.Name == "aura-egg" or multNum >= getgenv().minRiftMultiplier) then

        Event:FireServer("Teleport", worldDestinations[v.Name] or "Workspace.Worlds.The.Overworld.FastTravel.Spawn")
        task.wait(0.5)

        local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
        local root = char.PrimaryPart
        root.CFrame = CFrame.new(root.Position.X, -60, root.Position.Z)

        local targetPos = v:GetPivot().Position
        while v.Parent
          and (flat(targetPos) - flat(root.Position)).Magnitude > 1 do

            local dt  = RunService.RenderStepped:Wait()
            local dir = (flat(targetPos) - flat(root.Position)).Unit

            root.Velocity = root.Velocity + dir * 25 * dt
            local base = flat(root.Position) - Vector3.new(0,40,0)
            root.CFrame = CFrame.new(base + dir * 25 * dt)
        end

        root:PivotTo(CFrame.new(targetPos) + Vector3.new(0,40,0))

        if Toggles.HatchEgg then
            task.spawn(function()
                while getRemaining(v) > 3 and table.find(getgenv().riftFarm, v.Name) do
                    Event:FireServer("HatchEgg", SelectableEgg, HatchCount or 6)
                    task.wait(.5)
                end
            end)
        end

        repeat task.wait() until not v.Parent
        --hopToNext()

    else
        --hopToNext()
    end
end

local function RiftHopLoop()
    for _, v in ipairs(rifts:GetChildren()) do
        processRift(v)
    end
    rifts.ChildAdded:Connect(processRift)
end

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local function Notify(title, content)
    Fluent:Notify({
        Title    = title,
        Content  = content,
        Duration = 5,
    })
end

local Window = Fluent:CreateWindow({
    Title = "MidasHub",
    SubTitle = "discord.gg/FDAhrbbT7F",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" })
}

Tabs.Main:AddSection("Money")

Tabs.Main:AddToggle("Blow Bubbles", {
    Title = "Blow Bubbles",
    Default = false,
    Callback = function(v) 
        Toggles.BlowBubbles = v 
    end
})
Tabs.Main:AddToggle("Sell Bubbles", {
    Title = "Sell Bubbles",
    Default = false,
    Callback = function(v) 
        Toggles.SellBubbles = v 
    end
})
Tabs.Main:AddToggle("Auto Collect Loot Nearby", {
    Title = "Auto Collect Loot Nearby",
    Default = false,
    Callback = function(v)
        Toggles.AutoCollectLoot = v
    end
})

Tabs.Main:AddToggle("AutoFarmCoins", {
    Title = "Auto Farm Coins (turn this on with collect loot)",
    Default = false,
    Callback = function(on)
        Toggles.StageTeleportHighY = on
        if on then
            task.spawn(function()
                while Toggles.StageTeleportHighY do
                    farmCoins(13576)
                end
            end)
        end
    end
})

Tabs.Main:AddSection("Eggs & Pets")

Tabs.Main:AddInput("Hatch Count", {
    Title = "Hatch Count",
    Default = tostring(HatchCount),
    Placeholder = "Number of eggs hatch",
    Callback = function(val)
        HatchCount = tonumber(val) or 1
    end
})

Tabs.Main:AddToggle("Auto Hatch Eggs", {
    Title = "Auto Hatch Eggs",
    Default = false,
    Callback = function(v) 
        Toggles.HatchEgg = v 
    end
})
Tabs.Main:AddDropdown("Eggs", {
    Title = "Eggs",
    Values = Eggs,
    Default = Eggs[1],
    Callback= function(val) 
        SelectableEgg = val 
    end
})
Tabs.Main:AddToggle("Equip Best Pet", {
    Title = "Equip Best Pet",
    Default = false,
    Callback = function(v) 
        Toggles.EquipBest = v 
    end
})

Tabs.Main:AddSection("Teleport & Loot")

Tabs.Main:AddDropdown("Select World", {
    Title = "Select World",
    Values = worldList,
    Default = SelectedWorld,
    Callback= function(val)
        SelectedWorld = val
    end
})

Tabs.Main:AddButton({
    Title = "Teleport to World",
    Description = "Teleport to Selected Island",
    Callback = function()

        local dest = worldDestinations[SelectedWorld]
        if dest then
            Event:FireServer("Teleport", dest)
        end
    end
})

-- Tabs.Main:AddSection("Auto‑Enchant")

-- local enchantedPetId
-- local oldNamecall
-- oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
--     if checkcaller() then
--         return oldNamecall(self, ...)
--     end
--     local method = getnamecallmethod()
--     local args = (...)
--     if typeof(self) == "Instance" and method == "InvokeServer" then
--         if self.Name == "Function" and args[1] == "RerollEnchants" then
--             enchantedPetId = args[2]
--         end
--     end
--     return oldNamecall(self, ...)
-- end))

-- getgenv().desiredEnchants = {"team‑up","bubbler","looter","gleaming"}

-- Tabs.Main:AddDropdown("WantEnchants", {
--     Title = "Desired Enchants",
--     Values = getgenv().desiredEnchants,
--     Default = getgenv().desiredEnchants,
--     Multi = true,
--     Callback= function(vals)
--         getgenv().desiredEnchants = vals
--     end
-- })

-- Tabs.Main:AddToggle("EnableAutoEnchant", {
--     Title = "Auto Enchant",
--     Default = getgenv().autoEnchantEnabled,
--     Callback = function(on)
--         getgenv().autoEnchantEnabled = on
--         if on then
--             spawn(function()
--                 while getgenv().autoEnchantEnabled do
--                     task.wait(0.1)
--                     if not enchantedPetId then
--                         getgenv().autoEnchantEnabled = false
--                         break
--                     end

--                     local data = LocalData:Get()
--                     local myPet
--                     for _,p in ipairs(data.Pets) do
--                         if p.Id == enchantedPetId then
--                             myPet = p
--                             break
--                         end
--                     end
--                     if not myPet then
--                         warn("Pet not in inventory, stopping.")
--                         getgenv().autoEnchantEnabled = false
--                         break
--                     end

--                     local texts = {}
--                     for i = 1, EnchantUtil:GetMaxEnchantSlots(myPet) do
--                         local slot = EnchantSlots:FindFirstChild("Enchant"..i)
--                         if slot then
--                             texts[i] = slot:FindFirstChild("Title").Text:lower()
--                         end
--                     end

--                     local done = false
--                     for _, txt in pairs(texts) do
--                         for _, want in ipairs(getgenv().desiredEnchants) do
--                             if txt:find(want) then
--                                 done = true
--                                 break
--                             end
--                         end
--                         if done then break end
--                     end
--                     if done then
--                         getgenv().autoEnchantEnabled = false
--                         break
--                     end

--                     if #myPet.Enchants < EnchantUtil:GetMaxEnchantSlots(myPet) then
--                         Remote:InvokeServer("RerollEnchants", enchantedPetId)
--                     else
--                         for idx, txt in pairs(texts) do
--                             local good = false
--                             for _, want in ipairs(getgenv().desiredEnchants) do
--                                 if txt:find(want) then
--                                     good = true
--                                     break
--                                 end
--                             end
--                             if not good then
--                                 Remote:FireServer("RerollEnchant", enchantedPetId, idx)
--                                 break
--                             end
--                         end
--                     end
--                 end
--             end)
--         end
--     end
-- })

Tabs.Main:AddSection("Rift Hopping")

Tabs.Main:AddDropdown("Select Rift Types", {
    Title = "Select Rift Types",
    Values = {"nightmare-egg","void-egg","rainbow-egg","aura-egg"},
    Default = {},
    Multi = true,
    Callback = function(vals)
        SelectedRifts = vals
    end
})

Tabs.Main:AddDropdown("Min Rift Multi", {
    Title   = "Min Rift Multiplier",
    Values  = { "10x", "25x" },
    Default = (getgenv().minRiftMultiplier == 25 and "25x" or "10x"),
    Callback = function(choice)
        local n = tonumber(choice:match("%d+")) or 10
        getgenv().minRiftMultiplier = n
    end,
})

Tabs.Main:AddToggle("AutoRiftHop", {
    Title = "Auto Rift Hop",
    Default = getgenv().riftHopEnabled,
    Description = "Automatically hop for selected rifts",
    Callback = function(state)
      Toggles.RiftHop = state
      getgenv().riftHopEnabled = state
      if state then
        spawn(RiftHopLoop)
      end
    end
})

Tabs.Main:AddSection("Shop")

Tabs.Main:AddToggle("BuyBestGum", {
    Title = "Buy Best Gum",
    Default = false,
    Callback = function(v) 
        Toggles.GumBuy = v 
    end
})
Tabs.Main:AddToggle("Buy Best Flavor", {
    Title = "Buy Best Flavor",
    Default = false,
    Callback = function(v) 
        Toggles.FlavorBuy = v 
    end
})

Tabs.Main:AddSection("Prizes & Minigames")

Tabs.Main:AddToggle("Claim Prizes", {
    Title = "Claim Prizes",
    Default = false,
    Callback = function(v) 
        Toggles.ClaimPrizes = v 
    end
})

Tabs.Main:AddToggle("Doggy Win", {
    Title = "Doggy Win",
    Default = false,
    Callback = function(v) 
        Toggles.DoggyWin = v 
    end
})

Tabs.Main:AddSection("Misc")

Tabs.Main:AddButton({
    Title = "Unlock Islands",
    Callback = function()
        for _,isl in ipairs(Islands:GetChildren()) do
            if isl:IsA("Folder") then
                local hit = isl.Island:FindFirstChild("UnlockHitbox", true)
                if hit then
                    firetouchinterest(Player.Character.PrimaryPart, hit, 0)
                    firetouchinterest(Player.Character.PrimaryPart, hit, 1)
                end
            end
        end
    end
})

Tabs.Main:AddButton({
    Title = "Redeem All Codes",
    Callback = function()
        for codeName,_ in pairs(Codes) do
            Event:FireServer("RedeemCode", codeName)
        end
    end
})

Tabs.Main:AddSection("Webhook Settings")

Tabs.Main:AddInput("Webhook URL", {
	Title = "Webhook URL",
	Default = getgenv().webhook,
	Placeholder = "https://discord.com/api/...",
	Callback = function(val) 
        getgenv().webhook = val 
    end
})

Tabs.Main:AddInput("UserID",{
	Title = "Ping User ID",
	Default = getgenv().UserId and tostring(getgenv().UserId) or "",
	Placeholder = "User ID to ping (optional)",
	Callback = function(val)
        getgenv().UserId = tonumber(val) 
    end
})

Tabs.Main:AddInput("Max Chance (%)",{
	Title = "Max Chance (%)",
	Default = tostring(getgenv().highestChance),
	Placeholder = "e.g. 0.1",
	Callback = function(val) 
        getgenv().highestChance = tonumber(val) or getgenv().highestChance 
    end
})

Tabs.Main:AddToggle("Enable Webhook", {
	Title = "Enable Webhook",
	Default = false,
	Callback = function(state)
		Toggles.WebhookEnabled = state
		if state then
			spawn(WebhookMonitor)
		end
	end
})

-- Tabs.Main:AddSection("Season Scan")

-- Tabs.Main:AddButton({
--     Title = "Look For Secret Pet",
--     Callback = function()
--         task.spawn(function()
--             local playerData = LocalData:Get()
--             local currentSeason = SeasonUtil:GetCurrentSeason()
--             if not (playerData and currentSeason) then
--                 Notify("Season Scan", "No season data available.")
--                 return
--             end

--             for segment = 1, 100000 do
--                 local info = SeasonUtil:GetInfiniteSegment(playerData, currentSeason, segment)
--                 local free = info.Rewards.Free
--                 local premium = info.Rewards.Premium

--                 if free.Type == "Pet" or premium.Type == "Pet" then
--                     local petName = (free.Type == "Pet" and free.Name) or premium.Name
--                     local msg = ("[#%d] Pet → %s"):format(segment, petName)
--                     print(msg)
--                     Notify("Infinite Pass Pet", msg)

--                     if free.Rarity == "Secret" or premium.Rarity == "Secret" then
--                         local secretMsg = ("SECRET at level %d!"):format(segment)
--                         print("  → SECRET at level", segment)
--                         Notify("🔒 Secret Pet!", secretMsg)
--                     end
--                 end

--                 if segment % 100 == 0 then
--                     task.wait()
--                 end
--             end

--             Notify("Season Scan", "Done scanning 100 000 segments.")
--         end)
--     end
-- })

RunService.RenderStepped:Connect(function()
    if Toggles.BlowBubbles then
        Event:FireServer("BlowBubble")       
    end
    if Toggles.SellBubbles then
        Event:FireServer("SellBubble")       
    end
    if Toggles.HatchEgg then
        Event:FireServer("HatchEgg", SelectableEgg, HatchCount) 
    end
    if Toggles.EquipBest then
        Event:FireServer("EquipBestPets")   
    end
end)

spawn(function()
    while wait() do
        if Toggles.DoggyWin then
            for i=1,3 do wait(.2)
                Event:FireServer("DoggyJumpWin",i)
            end
        end
        if Toggles.ClaimPrizes then
            for i=1,100 do wait(.2)
                Event:FireServer("ClaimPrize",i)
            end
        end
        if Toggles.GumBuy then
            for i=1,#Gum do wait(.2)
                Event:FireServer("GumShopPurchase", i)
            end
        end
        if Toggles.FlavorBuy then
            for i=1,#Flavors do wait(.2)
                Event:FireServer("GumShopPurchase", i)
            end
        end
        if Toggles.AutoCollectLoot then
            StatsUtil.GetPickupRange = function()
                return 9e9
            end
            for _, model in ipairs(Workspace.Rendered:GetDescendants()) do
                if model:IsA("Model") and #model.Name == 36 then
                    CollectPickupRemote:FireServer(model.Name)
                end
            end
        end
    end
end)

if getgenv().riftHopEnabled then
    Toggles.RiftHop = true
    spawn(RiftHopLoop)
end

if getgenv().showRate then
    for _, name in ipairs({"Coins","Gems","Tokens"}) do
        addRateDisplay(name)
    end
end
