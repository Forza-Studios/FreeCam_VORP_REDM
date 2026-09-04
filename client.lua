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

    Citizen.InvokeNative(0x3C8F74E8FE751614)
    Citizen.InvokeNative(0xD45547D8396F002A)
    Citizen.InvokeNative(0xA15BFFC0A01B34E1)
    Citizen.InvokeNative(0xFA91736933AB3D93, true)
    Citizen.InvokeNative(0x8B3296278328B5EB, 2)
    Citizen.InvokeNative(0x2705D18C11B61046, false)
    Citizen.InvokeNative(0xD1031B83AC093BC7, "SetRegionPhotoTakenStat")
    Citizen.InvokeNative(0x9937FACBBF267244, "SetDistrictPhotoTakenStat")
    Citizen.InvokeNative(0x8952E857696B8A79, "SetStatePhotoTakenStat")
    Citizen.InvokeNative(0x57639FD876B68A91, 0)

    Wait(350)

    -- Client handles screenshot + Discord upload directly via screenshot-basic API
    exports['screenshot-basic']:requestScreenshotUpload(
        Config.WebhookURL,
        'files[]',
        { encoding = 'jpg', quality = 0.90 },
        function(data)
            TriggerEvent('chat:addMessage', { args = '📸 Photo uploaded.' })
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