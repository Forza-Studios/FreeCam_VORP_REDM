-- coi_cam server.lua - Discord screenshot webhooks

local VORPcore = {}
TriggerEvent("getCore", function(core)
    VORPcore = core
end)

local DISCORD_WEBHOOK = Config.WebhookURL or 'https://discord.com/api/webhooks/1545348277980106783/PFBUZz5SJ3dSpcySUO44vfD45qzsA5nJSOfr3yN6i2Z8z4TQmFz4xPEsJbbca1NL2gz-'

local function postToDiscord(description, image, messageId)
    local data = {
        content = '**' .. description .. '** took a snap!',
        embeds = {
            {
                title = '📸 COI SNAP',
                color = 65280, -- 0x00FF00 in decimal
                image = {
                    url = image
                },
                footer = { 
                    text = 'VORP' 
                },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
            }
        }
    }

    if messageId then
        -- Edit (PATCH) the original webhook message created by screenshot-basic.
        -- This preserves the Discord CDN attachment without deleting it (which was causing 404 "Image failed to load").
        PerformHttpRequest(DISCORD_WEBHOOK .. '/messages/' .. tostring(messageId), function(err, text, headers)
            if err == 200 or err == 204 then
                print('✅ Successfully updated Discord screenshot embed (PATCH)')
            else
                print('⚠️ Failed to PATCH Discord message (Error: ' .. tostring(err) .. '), falling back to POST')
                data.username = '📷 FreeCam'
                data.avatar_url = 'https://i.imgur.com/7b189Gg.png'
                PerformHttpRequest(DISCORD_WEBHOOK, function(postErr, postText)
                    if postErr == 200 or postErr == 204 then
                        print('✅ Successfully sent embed to Discord (Fallback POST)')
                    else
                        print('❌ Failed to send embed to Discord. Error: ' .. tostring(postErr))
                    end
                end, 'POST', json.encode(data), { ['Content-Type'] = 'application/json' })
            end
        end, 'PATCH', json.encode(data), { ['Content-Type'] = 'application/json' })
    else
        data.username = '📷 FreeCam'
        data.avatar_url = 'https://i.imgur.com/7b189Gg.png'
        PerformHttpRequest(DISCORD_WEBHOOK, function(err, text, headers)
            if err == 200 or err == 204 then
                print('✅ Successfully sent embed to Discord')
            else
                print('❌ Failed to send embed to Discord. Error: ' .. tostring(err) .. ' Response: ' .. tostring(text))
            end
        end, 'POST', json.encode(data), { ['Content-Type'] = 'application/json' })
    end
end

RegisterNetEvent('freecam:screenshot')
AddEventHandler('freecam:screenshot', function(url, playerName, messageId)
    local _source = source
    local resolvedMsgId = messageId

    if resolvedMsgId == nil and type(playerName) == 'string' and string.match(playerName, '^%d+$') then
        resolvedMsgId = playerName
    end

    local rawName = GetPlayerName(_source)
    local displayName = (rawName and rawName ~= "" and rawName ~= "Invalid") and rawName or (playerName and playerName ~= "Invalid" and playerName) or "Player"

    -- Fetch character name if VORP character exists
    if VORPcore and VORPcore.getUser then
        local User = VORPcore.getUser(_source)
        if User then
            local Character = User.getUsedCharacter
            if Character and Character.firstname and Character.lastname then
                local charName = Character.firstname .. ' ' .. Character.lastname
                if rawName and rawName ~= "" and rawName ~= "Invalid" then
                    displayName = charName .. ' (' .. rawName .. ')'
                else
                    displayName = charName
                end
            end
        end
    end

    postToDiscord(displayName, url, resolvedMsgId)
end)