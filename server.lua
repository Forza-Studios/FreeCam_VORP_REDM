RegisterNetEvent("coi_cam:capture", function()

    local src = source
    local playerName = GetPlayerName(src)

    -- Client handles screenshot upload now; server only logs it.
    TriggerClientEvent('chat:addMessage', src, { args = '📸 Photo captured.' })

    print(('^2[COI CAM]^7 %s took a photo.'):format(playerName))
end)