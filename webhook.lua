local webhook = "https://discord.com/api/webhooks/1363752832913772544/B7bSWXh3uVzkiQ2ysIRDTEUsbcULN82nJ3dWFMIBBH-mpmdgelBVsgnDE6HSATpsTjfD"
local rifts = workspace.Rendered:WaitForChild("Rifts")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local function sendWebhook(meters, displayName, multiplier, timerStr)
    if webhook == "" then return end

    local payload = {
        content = "@everyone",
        embeds = {{
            title = "A Rift has spawned:",
            description = "A rift has spawned at: " .. meters,
            color = 3426654,
            fields = {
                { name = "Name",       value = displayName,           inline = true },
                { name = "Multiplier", value = tostring(multiplier), inline = true },
                { name = "Timer",      value = timerStr,             inline = true },
                { name = "Meters",     value = tostring(meters),     inline = true },
                --{ name = "Join Link", value = "https://www.roblox.com/games/"..game.PlaceId.."?gameJobId="..game.JobId, inline = false },
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    local res = request({
        Url = webhook,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(payload)
    })
    if res.StatusCode ~= 200 then
        warn("Webhook failed with status code: " .. res.StatusCode)
    end
end

local function processRift(v)
    task.wait(5)
    local display = v:FindFirstChild("Display")
    if not display then return end
    local gui = display:FindFirstChild("SurfaceGui")
    if not gui then return end

    local timerLabel = gui:FindFirstChild("Timer")
    local timerText = (timerLabel and timerLabel.Text) or "0"

    local secsLeft = 0
    if timerText:find(":") then
        local m, s = timerText:match("(%d+):(%d+)")
        secsLeft = (tonumber(m) or 0) * 60 + (tonumber(s) or 0)
    else
        secsLeft = (tonumber(timerText:match("%d+")) or 0) * 60
    end

    local expiry = os.time() + secsLeft
    local timerValue = ("<t:%d:R>"):format(expiry)

    local luck = gui:FindFirstChild("Icon") and gui.Icon:FindFirstChild("Luck")
    local digits = (luck and luck.Text:match("%d+")) or "0"
    local multNum = tonumber(digits) or 0

    local rawName = v.Name
    local displayName = rawName
    if rawName == "event-1" then
        displayName = "bunny-egg"
    elseif rawName == "event-2" then
        displayName = "pastel-egg"
    elseif rawName == "event-3" then
        displayName = "throwback-egg"
    end

    if rawName == "royal-chest" then
        multNum = 9999999999
    end

    local threshold
    if rawName == "nightmare-egg" then
        threshold = 25
    else
        threshold = 5
    end
    
    local pos = v:GetPivot().Position
    local meters = math.floor(pos.Y)

    if rawName ~= "gift-rift"
    and ( rawName == "event-1"
        or rawName == "event-2"
        or rawName == "event-3"
        or rawName == "nightmare-egg"
        or rawName == "rainbow-egg"
        or rawName == "aura-egg")
    and multNum >= threshold then

        sendWebhook(meters, displayName, multNum, timerValue)
    end
end

for _, v in ipairs(rifts:GetChildren()) do
    task.spawn(processRift, v)
end

rifts.ChildAdded:Connect(function(v)
    task.spawn(processRift, v)
end)
