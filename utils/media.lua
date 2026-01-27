-- SuaviUI Media Registration
-- This file handles the registration of fonts and textures with LibSharedMedia

local LSM = LibStub("LibSharedMedia-3.0")

-- Media types from LibSharedMedia
local MediaType = LSM.MediaType
local FONT = MediaType.FONT
local STATUSBAR = MediaType.STATUSBAR
local BACKGROUND = MediaType.BACKGROUND
local BORDER = MediaType.BORDER

-- Register media synchronously (LSM:Register is lightweight - just table entries)
-- Register the suavi font (used as the main UI font)
    local suaviFontPath = "Interface\\AddOns\\SuaviUI\\assets\\suavi.ttf"
    LSM:Register(FONT, "suavi", suaviFontPath)

    -- Register Poppins fonts
    LSM:Register(FONT, "Poppins Black", "Interface\\AddOns\\SuaviUI\\assets\\Poppins-Black.ttf")
    LSM:Register(FONT, "Poppins Bold", "Interface\\AddOns\\SuaviUI\\assets\\Poppins-Bold.ttf")
    LSM:Register(FONT, "Poppins Medium", "Interface\\AddOns\\SuaviUI\\assets\\Poppins-Medium.ttf")
    LSM:Register(FONT, "Poppins SemiBold", "Interface\\AddOns\\SuaviUI\\assets\\Poppins-SemiBold.ttf")

    -- Register Expressway font
    LSM:Register(FONT, "Expressway", "Interface\\AddOns\\SuaviUI\\assets\\Expressway.TTF")

    -- Register the suavi Logo texture
    local logoTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suaviLogo.tga"
    LSM:Register(BACKGROUND, "suaviLogo", logoTexturePath)

    -- Register the suavi texture
    local suaviTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi.tga"
    LSM:Register(BACKGROUND, "suavi", suaviTexturePath)
    LSM:Register(STATUSBAR, "suavi", suaviTexturePath)
    LSM:Register(BORDER, "suavi", suaviTexturePath)

    -- Register the suavi Reverse texture
    local suaviReverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi_reverse.tga"
    LSM:Register(BACKGROUND, "suavi Reverse", suaviReverseTexturePath)
    LSM:Register(STATUSBAR, "suavi Reverse", suaviReverseTexturePath)
    LSM:Register(BORDER, "suavi Reverse", suaviReverseTexturePath)

    -- Register Square texture
    local squareTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\Square.tga"
    LSM:Register(BACKGROUND, "Square", squareTexturePath)
    LSM:Register(STATUSBAR, "Square", squareTexturePath)
    LSM:Register(BORDER, "Square", squareTexturePath)

    -- Register suavi v2 texture
    local suaviV2TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi_v2.tga"
    LSM:Register(BACKGROUND, "suavi v2", suaviV2TexturePath)
    LSM:Register(STATUSBAR, "suavi v2", suaviV2TexturePath)
    LSM:Register(BORDER, "suavi v2", suaviV2TexturePath)

    -- Register suavi v2 Reverse texture
    local suaviV2ReverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi_v2reverse.tga"
    LSM:Register(BACKGROUND, "suavi v2 Reverse", suaviV2ReverseTexturePath)
    LSM:Register(STATUSBAR, "suavi v2 Reverse", suaviV2ReverseTexturePath)
    LSM:Register(BORDER, "suavi v2 Reverse", suaviV2ReverseTexturePath)

    -- Register suavi v3 texture
    local suaviV3TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi_v3.tga"
    LSM:Register(BACKGROUND, "suavi v3", suaviV3TexturePath)
    LSM:Register(STATUSBAR, "suavi v3", suaviV3TexturePath)
    LSM:Register(BORDER, "suavi v3", suaviV3TexturePath)

    -- Register suavi v3 Inverse texture
    local suaviV3InverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi_v3inverse.tga"
    LSM:Register(BACKGROUND, "suavi v3 Inverse", suaviV3InverseTexturePath)
    LSM:Register(STATUSBAR, "suavi v3 Inverse", suaviV3InverseTexturePath)
    LSM:Register(BORDER, "suavi v3 Inverse", suaviV3InverseTexturePath)

    -- Register suavi v4 texture
    local suaviV4TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi_v4.tga"
    LSM:Register(BACKGROUND, "suavi v4", suaviV4TexturePath)
    LSM:Register(STATUSBAR, "suavi v4", suaviV4TexturePath)
    LSM:Register(BORDER, "suavi v4", suaviV4TexturePath)

    -- Register suavi v4 Inverse texture
    local suaviV4InverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi_v4inverse.tga"
    LSM:Register(BACKGROUND, "suavi v4 Inverse", suaviV4InverseTexturePath)
    LSM:Register(STATUSBAR, "suavi v4 Inverse", suaviV4InverseTexturePath)
    LSM:Register(BORDER, "suavi v4 Inverse", suaviV4InverseTexturePath)

    -- Register suavi v5 texture
    local suaviV5TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi_v5.tga"
    LSM:Register(BACKGROUND, "suavi v5", suaviV5TexturePath)
    LSM:Register(STATUSBAR, "suavi v5", suaviV5TexturePath)
    LSM:Register(BORDER, "suavi v5", suaviV5TexturePath)

    -- Register suavi v5 Inverse texture
    local suaviV5InverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi_v5_inverse.tga"
    LSM:Register(BACKGROUND, "suavi v5 Inverse", suaviV5InverseTexturePath)
    LSM:Register(STATUSBAR, "suavi v5 Inverse", suaviV5InverseTexturePath)
    LSM:Register(BORDER, "suavi v5 Inverse", suaviV5InverseTexturePath)

    -- Register suavi v6 texture
    local suaviV6TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi_v6.tga"
    LSM:Register(BACKGROUND, "suavi v6", suaviV6TexturePath)
    LSM:Register(STATUSBAR, "suavi v6", suaviV6TexturePath)
    LSM:Register(BORDER, "suavi v6", suaviV6TexturePath)

    -- Register suavi v6 Inverse texture
    local suaviV6InverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\suavi_v6inverse.tga"
    LSM:Register(BACKGROUND, "suavi v6 Inverse", suaviV6InverseTexturePath)
    LSM:Register(STATUSBAR, "suavi v6 Inverse", suaviV6InverseTexturePath)
    LSM:Register(BORDER, "suavi v6 Inverse", suaviV6InverseTexturePath)

    -- Register SUI Stripes texture (for absorb shield overlays)
    local absorbStripeTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\absorb_stripe"
    LSM:Register(STATUSBAR, "SUI Stripes", absorbStripeTexturePath)

-- Function to check if our media is registered
function SuaviUI:CheckMediaRegistration()
    local suaviFontRegistered = LSM:IsValid(FONT, "suavi")
    local logoTextureRegistered = LSM:IsValid(BACKGROUND, "suaviLogo")
    local suaviTextureRegistered = LSM:IsValid(BACKGROUND, "suavi")
    local suaviReverseTextureRegistered = LSM:IsValid(BACKGROUND, "suavi Reverse")
    
    -- Silent check - only print if there's a failure
    if not (suaviFontRegistered and logoTextureRegistered and suaviTextureRegistered and suaviReverseTextureRegistered) then
        SuaviUI:Print("Media registration failed:")
        if not suaviFontRegistered then SuaviUI:Print("- suavi font not registered") end
        if not logoTextureRegistered then SuaviUI:Print("- suaviLogo texture not registered") end
        if not suaviTextureRegistered then SuaviUI:Print("- suavi texture not registered") end
        if not suaviReverseTextureRegistered then SuaviUI:Print("- suavi Reverse texture not registered") end
    end
end

-- Register any additional fonts or textures here
-- Example:
-- LSM:Register(FONT, "MyCustomFont", "Interface\\AddOns\\SuaviUI\\assets\\mycustomfont.ttf")
-- LSM:Register(STATUSBAR, "MyCustomTexture", "Interface\\AddOns\\SuaviUI\\assets\\mycustomtexture.tga") 



