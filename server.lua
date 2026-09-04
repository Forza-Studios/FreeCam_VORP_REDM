-- =====================================================================
-- URL Encode (required for ImgBB)
-- =====================================================================

local function UrlEncode(str)
    if not str then return "" end

    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)

    return str
end

-- =====================================================================
-- ImgBB Upload
-- =====================================================================

local MAX_ATTEMPTS = 3

local function UploadToImgBB(base64Data, callback)
    local body =
        "key=" .. UrlEncode(Config.ImgBBKey) ..
        "&image=" .. UrlEncode(base64Data)

    PerformHttpRequest(
        "https://api.imgbb.com/1/upload",
        function(statusCode, response)
            if statusCode ~= 200 then
                print(("^1[COI CAM]^7 ImgBB Error %s: %s")
                    :format(statusCode, tostring(response)))
                callback(nil, ("HTTP %s"):format(statusCode))
                return
            end

            local ok, data = pcall(json.decode, response)

           if ok and data and data.success and data.data and data.data.url then
    print("^2[COI CAM]^7 ImgBB URL: " .. (data.data.display_url or data.data.url))
    callback(data.data.display_url or data.data.url)
else
                print(("^1[COI CAM]^7 Invalid ImgBB response: %s")
                    :format(tostring(response)))
                callback(nil, "Invalid response")
            end
        end,
        "POST",
        body,
        {
            ["Content-Type"] = "application/x-www-form-urlencoded"
        }
    )
end

-- =====================================================================
-- Discord Embed
-- =====================================================================

local function PostToDiscordEmbed(src, playerName, imageUrl)
    local payload = json.encode({
        embeds = {{
            title = "Photo Capture",
            color = 0x00FF88,
            fields = {
                {
                    name = "Player",
                    value = playerName,
                    inline = true
                }
            },
            image = {
                url = imageUrl
            },
            footer = {
                text = "COI CAM"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    })

    PerformHttpRequest(
        Config.WebhookURL,
        function(statusCode, response)
            if statusCode == 200 or statusCode == 204 then
                print(("^2[COI CAM]^7 Photo uploaded for %s")
                    :format(playerName))

                TriggerClientEvent("chat:addMessage", src, {
                    args = {"COI CAM", "📸 Photo uploaded."}
                })
            else
                print(("^1[COI CAM]^7 Discord webhook failed (%s): %s")
                    :format(statusCode, tostring(response)))
            end
        end,
        "POST",
        payload,
        {
            ["Content-Type"] = "application/json"
        }
    )
end

-- =====================================================================
-- Upload Pipeline
-- =====================================================================

local function UploadPipeline(src, base64Data, attempt)
    attempt = attempt or 1

    UploadToImgBB(base64Data, function(imageUrl, err)

        if imageUrl then
            PostToDiscordEmbed(src, GetPlayerName(src) or tostring(src), imageUrl)
            return
        end

        if attempt < MAX_ATTEMPTS then
            print(("^3[COI CAM]^7 ImgBB upload failed (%s). Retrying (%d/%d)...")
                :format(err or "unknown", attempt + 1, MAX_ATTEMPTS))

            SetTimeout(1500 * attempt, function()
                UploadPipeline(src, base64Data, attempt + 1)
            end)
        else
            print(("^1[COI CAM]^7 ImgBB upload failed permanently for %s: %s")
                :format(GetPlayerName(src) or tostring(src), err or "unknown"))

            TriggerClientEvent("chat:addMessage", src, {
                args = {"COI CAM", "⚠️ Image upload failed."}
            })
        end
    end)
end

-- =====================================================================
-- Events
-- =====================================================================

RegisterNetEvent("coi_cam:capture", function()
    local src = source
    local playerName = GetPlayerName(src)

    TriggerClientEvent("chat:addMessage", src, {
        args = {"COI CAM", "📸 Photo captured."}
    })

    print(("^2[COI CAM]^7 %s took a photo."):format(playerName))
end)

RegisterNetEvent("coi_cam:upload", function(dataUri)
    local src = source

    if type(dataUri) ~= "string" then
        print(("^1[COI CAM]^7 Bad upload payload from %s")
            :format(GetPlayerName(src) or tostring(src)))
        return
    end

    local base64Data = dataUri:match("base64,(.*)")

    if not base64Data then
        print(("^1[COI CAM]^7 Invalid data URI from %s")
            :format(GetPlayerName(src) or tostring(src)))
        return
    end

    -- Approximate binary size (base64 is ~33% larger)
    local estimatedBytes = math.floor(#base64Data * 0.75)

    if estimatedBytes > 10 * 1024 * 1024 then
        print(("^1[COI CAM]^7 Oversized upload from %s (%d bytes)")
            :format(GetPlayerName(src) or tostring(src), estimatedBytes))
        return
    end

    UploadPipeline(src, base64Data, 1)
end)