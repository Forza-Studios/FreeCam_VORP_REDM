local WEBHOOK = "https://discord.com/api/webhooks/1545348277980106783/PFBUZz5SJ3dSpcySUO44vfD45qzsA5nJSOfr3yN6i2Z8z4TQmFz4xPEsJbbca1NL2gz-"

RegisterNetEvent("coi_cam:upload", function()
    local src = source

    exports["screenshot-basic"]:requestClientScreenshot(src, {
        encoding = "jpg",
        quality = 0.92
    }, function(err, data)

        if err then
            print("^1[COI CAM]^7 Screenshot failed:", err)
            return
        end

        PerformHttpRequest(
            WEBHOOK,
            function(code)
                print("^2[COI CAM]^7 Discord upload:", code)
            end,
            "POST",
            json.encode({
                username = "COI CAM",
                embeds = {{
                    title = "📸 Screenshot",
                    image = { url = data }
                }}
            }),
            { ["Content-Type"] = "application/json" }
        )
    end)
end)