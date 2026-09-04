-- =====================================================================
-- Base64 decode (pure Lua, no external deps needed)
-- =====================================================================
local B64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function Base64Decode(data)
    data = string.gsub(data, '[^' .. B64_CHARS .. '=]', '')

    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (B64_CHARS:find(x) - 1)
        for i = 6, 1, -1 do
            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0)
        end
        return string.char(c)
    end))
end

-- =====================================================================
-- catbox.moe upload: multipart POST → returns a plain-text image URL
-- =====================================================================
local function UploadToCatbox(fileBytes, callback)
    local boundary = 'CatboxBoundary' .. tostring(math.random(100000, 999999))

    local body = table.concat({
        '--' .. boundary, '\r\n',
        'Content-Disposition: form-data; name="filename"; filename="screenshot.jpg"', '\r\n',
        'Content-Type: image/jpeg', '\r\n',
        '\r\n',
        'ImageData', '\r\n',
        '--' .. boundary, '\r\n',
        'Content-Disposition: form-data; name="image"', '\r\n',
        'Content-Type: image/jpeg', '\r\n',
        '\r\n',
        fileBytes, '\r\n',
        '--' .. boundary .. '--', '\r\n'
    })

    PerformHttpRequest('https://files.catbox.moe/upload.php', function(statusCode, response, headers)
        -- catbox.moe returns a plain-text filename on success (e.g. "abc123.jpg")
        -- or a short error message. We prepend the base domain for the full URL.
        local imageUrl
        if type(response) == 'string' then
            local filename = response:match('([^/%s]+)%s*$')
            if filename then
                imageUrl = 'https://files.catbox.moe/' .. filename
            else
                imageUrl = 'https://files.catbox.moe/' .. response
            end
        else
            imageUrl = ''
        end

        if imageUrl and #imageUrl > 0 then
            callback(imageUrl)
        else
            -- catbox returned an error message
            callback(nil)
        end
    end, 'POST', body, {
        ['Content-Type'] = 'multipart/form-data; boundary=' .. boundary
    })
end

-- =====================================================================
-- Post to Discord via plain JSON embed (no multipart / no file field)
-- =====================================================================
local function PostToDiscordEmbed(playerName, imageUrl)
    local web = Config.WebhookURL

    -- Clean the webhook base for embed URL field (strip the trailing dash)
    local baseUrl = string.gsub(Config.WebhookURL, '[-?]+$', '')
    if baseUrl == '' then baseUrl = Config.WebhookURL end

    -- Build the JSON string properly — no escaping nightmares
    local json_str = '{'
    json_str = json_str .. '"embeds":[{'
    json_str = json_str .. '"color":' .. string.format("%d", 0x00FF88) .. ','
    json_str = json_str .. '"url":"' .. baseUrl .. '/","'
    json_str = json_str .. '"title":"Photo Capture","'
    json_str = json_str .. '"fields":[{'
    json_str = json_str .. '"name":"Player","value":"' .. playerName .. '",inline:true,'
    json_str = json_str .. '"name":"Location","value":"' .. imageUrl .. '",inline:false}'
    json_str = json_str .. '],"'
    json_str = json_str .. '"footer":{"text":"photo uploaded","icon_url":"' .. baseUrl .. '/"},'
    json_str = json_str .. '"thumbnail":{"url":"' .. imageUrl .. '"}}'
    json_str = json_str .. '}'

    PerformHttpRequest(web, function(statusCode, response, headers)
        if statusCode == 200 or statusCode == 204 then
            print(('^2[COI CAM]^7 Disc photo sent for %s.'):format(playerName))
            TriggerClientEvent('chat:addMessage', source, { args = '📸 Photo uploaded.' })
        else
            print(('^1[COI CAM]^7 Disc webhook failed for %s (status %s): %s')
                :format(playerName, tostring(statusCode), tostring(response)))
            TriggerClientEvent('chat:addMessage', source, { args = '⚠️ Photo webhook failed.' })
        end
    end, 'POST', json_str, {
        ['Content-Type'] = 'application/json'
    })
end

-- =====================================================================
-- Upload pipeline: base64 → catbox.moe → discord embed
-- =====================================================================
local MAX_ATTEMPTS = 3

local function UploadPipeline(src, fileBytes, attempt)
    attempt = attempt or 1

    UploadToCatbox(fileBytes, function(imageUrl)
        if not imageUrl then
            print(('^1[COI CAM]^7 catbox returned empty URL for %s'):format(GetPlayerName(src) or src))
            return
        end

        -- Success — now POST the URL to Discord as a plain JSON embed.
        -- No binary handling at all, no 40333, simple and fast.
        PostToDiscordEmbed(GetPlayerName(src) or src, imageUrl)
    end)

    -- Retry logic if catbox fails
    if attempt < MAX_ATTEMPTS then
        CreateThread(function()
            Wait(1500 * attempt)
            UploadPipeline(src, fileBytes, attempt + 1)
        end)
    end
end

-- =====================================================================
-- Events
-- =====================================================================
RegisterNetEvent("coi_cam:capture", function()
    local src = source
    local playerName = GetPlayerName(src)

    TriggerClientEvent('chat:addMessage', src, { args = '📸 Photo captured.' })
    print(('^2[COI CAM]^7 %s took a photo.'):format(playerName))
end)

RegisterNetEvent("coi_cam:upload", function(dataUri)
    local src = source

    if type(dataUri) ~= 'string' then
        print(('^1[COI CAM]^7 Rejected upload from %s: bad payload'):format(GetPlayerName(src) or src))
        return
    end

    local base64Data = dataUri:match('base64,(.*)')
    if not base64Data then
        print(('^1[COI CAM]^7 Rejected upload from %s: not a data URI'):format(GetPlayerName(src) or src))
        return
    end

    local fileBytes = Base64Decode(base64Data)
    if not fileBytes or #fileBytes == 0 then
        print(('^1[COI CAM]^7 Failed to decode screenshot from %s'):format(GetPlayerName(src) or src))
        return
    end

    -- Basic sanity cap (10 MB) so a malformed/spoofed payload can't be used
    -- to push something huge through PerformHttpRequest.
    if #fileBytes > 10 * 1024 * 1024 then
        print(('^1[COI CAM]^7 Rejected oversized upload from %s (%d bytes)')
            :format(GetPlayerName(src) or src, #fileBytes))
        return
    end

    UploadPipeline(src, fileBytes, 1)
end)