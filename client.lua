local Cam, Controller = nil, nil
local Speed = 0.05
local StartFov = 70.0
local ShowHud = true
local TakingShot = false

local function LoadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
end

local function NativePhoto()
    if TakingShot then return end
    TakingShot = true

    if not AnimpostfxIsRunning("PhotoMode_Bounds") then
        AnimpostfxPlay("PhotoMode_Bounds")
    end

    AnimpostfxPlay("CameraViewFinder")

    -- NOTE: A previous version of this function also fired Rockstar's own
    -- native "save to Social Club" pipeline (SAVE_HIGH_QUALITY_PHOTO,
    -- 0x57639FD876B68A91). That native is asynchronous and requires polling
    -- GET_STATUS_OF_SAVE_HIGH_QUALITY_PHOTO (0xD6663EC374092383) until it
    -- reports completion before continuing. This script never did that, so
    -- the game's internal high-res capture job could still be in progress
    -- when the code moved on -- leaving the screen stuck black even though
    -- the photo itself saved fine (which is why it still showed up in your
    -- Social Club gallery). It's removed here since screenshot-basic below
    -- already handles the capture we actually need.

    Wait(350)

    -- Client only captures the screenshot locally (base64 data URI).
    -- The upload to Discord happens server-side (see server.lua) so the
    -- webhook URL never has to live in a client script, and the HTTP
    -- request doesn't carry the NUI/browser fingerprint that trips
    -- Discord/Cloudflare's bot filtering (error 40333).
    exports['screenshot-basic']:requestScreenshot(
        { encoding = 'jpg', quality = 0.90 },
        function(dataUri)
            if not dataUri or not dataUri:find('base64,') then
                print('COI CAM: screenshot capture failed or returned unexpected data')
                return
            end

            -- Latent event: rate-limited so a big image doesn't spike the
            -- player's bandwidth or block other network traffic. bps below
            -- caps the transfer at ~2 MB/s, which a single JPEG screenshot
            -- will comfortably fit inside a second or two.
            TriggerLatentServerEvent('coi_cam:upload', 2 * 1024 * 1024, dataUri)

            TriggerEvent('chat:addMessage', { args = '📸 Photo captured, uploading...' })
        end
    )

    Wait(150)

    AnimpostfxStop("CameraViewFinder")
    AnimpostfxStop("PhotoMode_Bounds")

    TakingShot = false
end

local function OpenAlbum()
    LaunchAppWithEntry("social_club_feed", "launch_to_photos")
end

local function EnableCam()
    local pos = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local fov = GetGameplayCamFov()

    LoadModel(`scriptedball`)
    Controller = CreateObjectNoOffset(`scriptedball`, pos.x, pos.y, pos.z, false, false, false, false)
    FreezeEntityPosition(Controller, true)
    SetEntityVisible(Controller, false)

    Cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamRot(Cam, rot.x, rot.y, rot.z, 2)
    SetCamFov(Cam, fov)
    StartFov = fov
    AttachCamToEntity(Cam, Controller, 0.0, 0.0, 0.0, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function DisableCam()
    if not Cam then return end

    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(Cam, true)
    DeleteObject(Controller)

    Cam = nil
    Controller = nil
end

RegisterKeyMapping("camtoggle", "Toggle COI Camera (FreeCam)", "keyboard", "F1")

RegisterCommand("camtoggle", function()
    if Cam then
        DisableCam()
    else
        EnableCam()
    end
end, false)

RegisterCommand("cam", function()
    if Cam then
        DisableCam()
    else
        EnableCam()
    end
end, false)

CreateThread(function()

    TriggerEvent("chat:addSuggestion", "/cam", "Toggle COI Camera")

    while true do
        Wait(0)

        if Cam then

            local pos = GetCamCoord(Cam)
            local rot = GetCamRot(Cam, 2)
            local fov = GetCamFov(Cam)

            DisableAllControlActions(0)

            EnableControlAction(0, `INPUT_MP_TEXT_CHAT_ALL`)
            EnableControlAction(0, `INPUT_FRONTEND_ACCEPT`)

            if not ShowHud then
                HideHudAndRadarThisFrame()
            end

            if IsDisabledControlJustPressed(0, `INPUT_FRONTEND_ACCEPT`) then
                NativePhoto()
            end

            if IsDisabledControlJustPressed(0, `INPUT_OPEN_JOURNAL`) then
                OpenAlbum()
            end

            if IsDisabledControlJustPressed(0, `INPUT_COVER`) then
                ShowHud = not ShowHud
            end

            if IsDisabledControlPressed(0, `INPUT_CREATOR_LT`) then
                Speed = math.min(Speed + 0.001, 1.0)
            end

            if IsDisabledControlPressed(0, `INPUT_CREATOR_RT`) then
                Speed = math.max(Speed - 0.001, 0.001)
            end

            if IsDisabledControlPressed(0, `INPUT_JUMP`) then
                pos = vector3(pos.x, pos.y, pos.z + Speed)
            end

            if IsDisabledControlPressed(0, `INPUT_SPRINT`) then
                pos = vector3(pos.x, pos.y, pos.z - Speed)
            end

            local axisX = GetDisabledControlNormal(0, 0xA987235F)
            local axisY = GetDisabledControlNormal(0, 0xD2047988)

            rot = vector3(
                math.max(math.min(89.9, rot.x - axisY * 8), -89.9),
                rot.y,
                rot.z - axisX * 8
            )

            local yaw = -rot.z * math.pi / 180
            local fx = Speed * math.sin(yaw)
            local fy = Speed * math.cos(yaw)

            local side = math.rad((-rot.z + 90) % 360)
            local sx = Speed * math.sin(side)
            local sy = Speed * math.cos(side)

            if IsDisabledControlPressed(0, `INPUT_MOVE_UP_ONLY`) then
                pos = vector3(pos.x + fx, pos.y + fy, pos.z)
            end

            if IsDisabledControlPressed(0, `INPUT_MOVE_DOWN_ONLY`) then
                pos = vector3(pos.x - fx, pos.y - fy, pos.z)
            end

            if IsDisabledControlPressed(0, `INPUT_MOVE_LEFT_ONLY`) then
                pos = vector3(pos.x - sx, pos.y - sy, pos.z)
            end

            if IsDisabledControlPressed(0, `INPUT_MOVE_RIGHT_ONLY`) then
                pos = vector3(pos.x + sx, pos.y + sy, pos.z)
            end

            if IsDisabledControlPressed(0, `INPUT_GAME_MENU_TAB_RIGHT_SECONDARY`) then
                fov = math.min(fov + 1, 120.0)
            end

            if IsDisabledControlPressed(0, `INPUT_GAME_MENU_TAB_LEFT_SECONDARY`) then
                fov = math.max(fov - 1, 20.0)
            end

            SetEntityCoordsNoOffset(Controller, pos.x, pos.y, pos.z, false, false, false)
            SetCamRot(Cam, rot.x, rot.y, rot.z, 2)
            SetCamFov(Cam, fov)

            if ShowHud then
                SetTextScale(0.35, 0.35)
                SetTextCentre(true)

                DisplayText(
                    CreateVarString(
                        10,
                        "LITERAL_STRING",
                        "COI CAMERA | Enter=Photo | J=Album | Q=HUD | F1=Exit"
                    ),
                    0.5,
                    0.92
                )
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(r)
    if r == GetCurrentResourceName() then
        DisableCam()
    end
end)