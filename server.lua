-- coi_cam server.lua - Discord screenshot webhooks

local DISCORD_WEBHOOK = Config.WebhookURL or 'https://discord.com/api/webhooks/1545348277980106783/PFBUZz5SJ3dSpcySUO44vfD45qzsA5nJSOfr3yN6i2Z8z4TQmFz4xPEsJbbca1NL2gz-'

local function postToDiscord(description, image, messageId)
    local data = {
        username = '📷 FreeCam',
        avatar_url = 'https://i.imgur.com/7b189Gg.png', -- Optional avatar
        content = description .. ' took a screenshot!',
        embeds = {
            {
                title = '📸 FreeCam Screenshot',
                color = 65280, -- 0x00FF00 in decimal
                image = {
                    url = image
                },
                footer = { 
                    text = 'VORP' 
                }
            }
        }
    }

    PerformHttpRequest(DISCORD_WEBHOOK, function(err, text, headers)
        if err == 200 or err == 204 then
            print('✅ Successfully sent embed to Discord')
            -- Try to delete the original unformatted image message
            if messageId then
                PerformHttpRequest(DISCORD_WEBHOOK .. '/messages/' .. messageId, function(delErr, delText, delHeaders) end, 'DELETE', '', { ['Content-Type'] = 'application/json' })
            end
        else
            print('❌ Failed to send embed to Discord. Error: ' .. tostring(err) .. ' Response: ' .. tostring(text))
        end
    end, 'POST', json.encode(data), { ['Content-Type'] = 'application/json' })
end

RegisterNetEvent('freecam:screenshot')
AddEventHandler('freecam:screenshot', function(url, playerName, messageId)
    postToDiscord(playerName, url, messageId)
end)