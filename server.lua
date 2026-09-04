local WEBHOOK_URL = "https://discord.com/api/webhooks/1545348277980106783/PFBUZz5SJ3dSpcySUO44vfD45qzsA5nJSOfr3yN6i2Z8z4TQmFz4xPEsJbbca1NL2gz-"

RegisterNetEvent("coi_cam:capture", function()

    local src = source
    local playerName = GetPlayerName(src)

    exports["screenshot-basic"]:requestClientScreenshot(src, {
        encoding = "jpg",
        quality = 0.90
    }, function(err, imageData)

        if err then
            print(("^1[COI CAM]^7 Capture failed for %s: %s"):format(playerName, tostring(err)))
            return
        end

        if not imageData then
            print(("^1[COI CAM]^7 No image returned for %s"):format(playerName))
            return
        end

        local boundary = "---------------------------" .. os.time()

        local body =
            "--" .. boundary .. "\r\n" ..
            'Content-Disposition: form-data; name="content"\r\n\r\n' ..
            ("📸 **%s** took a photo."):format(playerName) .. "\r\n" ..
            "--" .. boundary .. "\r\n" ..
            'Content-Disposition: form-data; name="files[0]"; filename="photo.jpg"\r\n' ..
            "Content-Type: image/jpeg\r\n\r\n" ..
            imageData .. "\r\n" ..
            "--" .. boundary .. "--"

        PerformHttpRequest(
            WEBHOOK_URL,
            function(statusCode, response)

                if statusCode == 200 or statusCode == 204 then
                    print(("^2[COI CAM]^7 %s uploaded successfully."):format(playerName))
                else
                    print(("^1[COI CAM]^7 Discord upload failed (%s): %s"):format(
                        statusCode,
                        response or "nil"
                    ))
                end
            end,
            "POST",
            body,
            {
                ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
            }
        )

    end)
end)