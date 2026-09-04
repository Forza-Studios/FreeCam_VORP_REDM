-- coi_cam server.lua - Discord screenshot webhooks

local config
if not config then
	config = LoadConfigFile('../config.lua') or {}
end

local DISCORD_WEBHOOK = config.WebhookURL or 'https://discord.com/api/webhooks/1545348277980106783/PFBUZz5SJ3dSpcySUO44vfD45qzsA5nJSOfr3yN6i2Z8z4TQmFz4xPEsJbbca1NL2gz-'

local function postToDiscord(description, image)
    local data = {
        username = '📷 FreeCam',
        color = 0x00FF00,
        content = description,
        fields = {
            {
                name = 'Sent By',
                value = description,
                inline = false
            }
        }
    }

    if image ~= nil then
        data.embedding = {
            image.url = image,
            title = '📸 FreeCam Screenshot',
            color = 0x00FF00,
            footer = { text = 'VORP' }
        }
    end

    local success, result = PerformGetRequest('POST', DISCORD_WEBHOOK, json.encode(data))
    if success then
        print('✅ Successfully sent image to Discord')
    else
        print('❌ Failed to send image to Discord: ' .. tostring(result))
    end
end

RegisterNetEvent('freecam:screenshot')
AddEventHandler('freecam:screenshot', function(url, playerName)
    postToDiscord(playerName, url)
end)