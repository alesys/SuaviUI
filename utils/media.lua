-- SuaviUI Media Registration
-- This file handles the registration of ALL fonts and textures with LibSharedMedia
-- Consolidated from media.lua and resourcebars/Constants.lua
-- All media follows the "Suavi" naming convention

local LSM = LibStub("LibSharedMedia-3.0")

-- Media types from LibSharedMedia
local MediaType = LSM.MediaType
local FONT = MediaType.FONT
local STATUSBAR = MediaType.STATUSBAR
local BACKGROUND = MediaType.BACKGROUND
local BORDER = MediaType.BORDER

------------------------------------------------------------
-- FONTS
------------------------------------------------------------
-- Main UI font
local suaviFontPath = "Interface\\AddOns\\SuaviUI\\assets\\fonts\\suavi.ttf"
LSM:Register(FONT, "Suavifont", suaviFontPath)

-- Poppins family
LSM:Register(FONT, "Suavifont Poppins Black", "Interface\\AddOns\\SuaviUI\\assets\\fonts\\Poppins-Black.ttf")
LSM:Register(FONT, "Suavifont Poppins Bold", "Interface\\AddOns\\SuaviUI\\assets\\fonts\\Poppins-Bold.ttf")
LSM:Register(FONT, "Suavifont Poppins Medium", "Interface\\AddOns\\SuaviUI\\assets\\fonts\\Poppins-Medium.ttf")
LSM:Register(FONT, "Suavifont Poppins SemiBold", "Interface\\AddOns\\SuaviUI\\assets\\fonts\\Poppins-SemiBold.ttf")

-- Expressway
LSM:Register(FONT, "Suavifont Expressway", "Interface\\AddOns\\SuaviUI\\assets\\fonts\\Expressway.TTF")

-- Standard WoW fonts (for compatibility)
LSM:Register(FONT, "Friz Quadrata TT", [[Fonts\FRIZQT___CYR.TTF]])
LSM:Register(FONT, "Morpheus", [[Fonts\MORPHEUS_CYR.TTF]])
LSM:Register(FONT, "Arial Narrow", [[Fonts\ARIALN.TTF]])
LSM:Register(FONT, "Skurri", [[Fonts\SKURRI_CYR.TTF]])

------------------------------------------------------------
-- STATUS BAR TEXTURES
------------------------------------------------------------
-- Main Suavi textures
local suaviTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi.tga"
LSM:Register(STATUSBAR, "Suavitex", suaviTexturePath)
LSM:Register(BACKGROUND, "Suavitex", suaviTexturePath)
LSM:Register(BORDER, "Suavitex", suaviTexturePath)

-- Suavi Reverse
local suaviReverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi_reverse.tga"
LSM:Register(STATUSBAR, "Suavitex Reverse", suaviReverseTexturePath)
LSM:Register(BACKGROUND, "Suavitex Reverse", suaviReverseTexturePath)
LSM:Register(BORDER, "Suavitex Reverse", suaviReverseTexturePath)

-- Square
local squareTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\Square.tga"
LSM:Register(STATUSBAR, "Suavisquare", squareTexturePath)
LSM:Register(BACKGROUND, "Suavisquare", squareTexturePath)
LSM:Register(BORDER, "Suavisquare", squareTexturePath)

-- Suavi v2
local suaviV2TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi_v2.tga"
LSM:Register(STATUSBAR, "Suavitex v2", suaviV2TexturePath)
LSM:Register(BACKGROUND, "Suavitex v2", suaviV2TexturePath)
LSM:Register(BORDER, "Suavitex v2", suaviV2TexturePath)

local suaviV2ReverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi_v2reverse.tga"
LSM:Register(STATUSBAR, "Suavitex v2 Reverse", suaviV2ReverseTexturePath)
LSM:Register(BACKGROUND, "Suavitex v2 Reverse", suaviV2ReverseTexturePath)
LSM:Register(BORDER, "Suavitex v2 Reverse", suaviV2ReverseTexturePath)

-- Suavi v3
local suaviV3TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi_v3.tga"
LSM:Register(STATUSBAR, "Suavitex v3", suaviV3TexturePath)
LSM:Register(BACKGROUND, "Suavitex v3", suaviV3TexturePath)
LSM:Register(BORDER, "Suavitex v3", suaviV3TexturePath)

local suaviV3InverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi_v3inverse.tga"
LSM:Register(STATUSBAR, "Suavitex v3 Inverse", suaviV3InverseTexturePath)
LSM:Register(BACKGROUND, "Suavitex v3 Inverse", suaviV3InverseTexturePath)
LSM:Register(BORDER, "Suavitex v3 Inverse", suaviV3InverseTexturePath)

-- Suavi v4
local suaviV4TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi_v4.tga"
LSM:Register(STATUSBAR, "Suavitex v4", suaviV4TexturePath)
LSM:Register(BACKGROUND, "Suavitex v4", suaviV4TexturePath)
LSM:Register(BORDER, "Suavitex v4", suaviV4TexturePath)

local suaviV4InverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi_v4inverse.tga"
LSM:Register(STATUSBAR, "Suavitex v4 Inverse", suaviV4InverseTexturePath)
LSM:Register(BACKGROUND, "Suavitex v4 Inverse", suaviV4InverseTexturePath)
LSM:Register(BORDER, "Suavitex v4 Inverse", suaviV4InverseTexturePath)

-- Suavi v5
local suaviV5TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi_v5.tga"
LSM:Register(STATUSBAR, "Suavitex v5", suaviV5TexturePath)
LSM:Register(BACKGROUND, "Suavitex v5", suaviV5TexturePath)
LSM:Register(BORDER, "Suavitex v5", suaviV5TexturePath)

local suaviV5InverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi_v5_inverse.tga"
LSM:Register(STATUSBAR, "Suavitex v5 Inverse", suaviV5InverseTexturePath)
LSM:Register(BACKGROUND, "Suavitex v5 Inverse", suaviV5InverseTexturePath)
LSM:Register(BORDER, "Suavitex v5 Inverse", suaviV5InverseTexturePath)

-- Suavi v6
local suaviV6TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi_v6.tga"
LSM:Register(STATUSBAR, "Suavitex v6", suaviV6TexturePath)
LSM:Register(BACKGROUND, "Suavitex v6", suaviV6TexturePath)
LSM:Register(BORDER, "Suavitex v6", suaviV6TexturePath)

local suaviV6InverseTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavi_v6inverse.tga"
LSM:Register(STATUSBAR, "Suavitex v6 Inverse", suaviV6InverseTexturePath)
LSM:Register(BACKGROUND, "Suavitex v6 Inverse", suaviV6InverseTexturePath)
LSM:Register(BORDER, "Suavitex v6 Inverse", suaviV6InverseTexturePath)

-- Fade textures (from resourcebars)
LSM:Register(STATUSBAR, "Suavifade Left", [[Interface\AddOns\SuaviUI\assets\textures\fade-left.png]])
LSM:Register(STATUSBAR, "Suavifade Bottom", [[Interface\AddOns\SuaviUI\assets\textures\fade-bottom.png]])
LSM:Register(STATUSBAR, "Suavifade Top", [[Interface\AddOns\SuaviUI\assets\textures\fade-top.png]])

-- Solid texture
LSM:Register(STATUSBAR, "Suavisolid", [[Interface\AddOns\SuaviUI\assets\textures\solid.png]])

-- Transparent (None)
LSM:Register(STATUSBAR, "None", [[Interface\AddOns\SuaviUI\assets\textures\transparent.png]])

-- Stripes (for absorb shield overlays)
local absorbStripeTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\absorb_stripe"
LSM:Register(STATUSBAR, "Suavistripes", absorbStripeTexturePath)

-- Linea (PNG test texture)
local suaviLineaTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\Suavilinea.png"
LSM:Register(STATUSBAR, "Suavilinea", suaviLineaTexturePath)
LSM:Register(BACKGROUND, "Suavilinea", suaviLineaTexturePath)
LSM:Register(BORDER, "Suavilinea", suaviLineaTexturePath)

-- Lineas (PNG test texture - striped variant)
local suaviLineasTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\Suavilineas.png"
LSM:Register(STATUSBAR, "Suavilineas", suaviLineasTexturePath)
LSM:Register(BACKGROUND, "Suavilineas", suaviLineasTexturePath)
LSM:Register(BORDER, "Suavilineas", suaviLineasTexturePath)

-- Lineas2 (PNG test texture - variant 2)
local suaviLineas2TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\Suavilineas2.png"
LSM:Register(STATUSBAR, "Suavilineas2", suaviLineas2TexturePath)
LSM:Register(BACKGROUND, "Suavilineas2", suaviLineas2TexturePath)
LSM:Register(BORDER, "Suavilineas2", suaviLineas2TexturePath)

-- DJ (Custom texture)
local djTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\DJ"
LSM:Register(STATUSBAR, "DJ", djTexturePath)
LSM:Register(BACKGROUND, "DJ", djTexturePath)
LSM:Register(BORDER, "DJ", djTexturePath)

-- Diagonal textures
local suaviDiag1TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavidiag1.png"
LSM:Register(STATUSBAR, "Suavidiag1", suaviDiag1TexturePath)
LSM:Register(BACKGROUND, "Suavidiag1", suaviDiag1TexturePath)
LSM:Register(BORDER, "Suavidiag1", suaviDiag1TexturePath)

local suaviDiag2TexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavidiag2.png"
LSM:Register(STATUSBAR, "Suavidiag2", suaviDiag2TexturePath)
LSM:Register(BACKGROUND, "Suavidiag2", suaviDiag2TexturePath)
LSM:Register(BORDER, "Suavidiag2", suaviDiag2TexturePath)

-- Horde faction texture
local suaviHordeLeftPath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suavihorde-left.png"
LSM:Register(STATUSBAR, "Suavihorde Left", suaviHordeLeftPath)
LSM:Register(BACKGROUND, "Suavihorde Left", suaviHordeLeftPath)
LSM:Register(BORDER, "Suavihorde Left", suaviHordeLeftPath)

------------------------------------------------------------
-- BACKGROUND TEXTURES
------------------------------------------------------------
-- Bevelled backgrounds
LSM:Register(BACKGROUND, "Suavibevel", [[Interface\AddOns\SuaviUI\assets\textures\bevelled.png]])
LSM:Register(BACKGROUND, "Suavibevel Grey", [[Interface\AddOns\SuaviUI\assets\textures\bevelled-grey.png]])

-- Logo
local logoTexturePath = "Interface\\AddOns\\SuaviUI\\assets\\textures\\suaviLogo.tga"
LSM:Register(BACKGROUND, "Suavilogo", logoTexturePath)

------------------------------------------------------------
-- BORDER TEXTURES
------------------------------------------------------------
LSM:Register(BORDER, "Suaviborder Classic", [[Interface\AddOns\SuaviUI\assets\textures\blizzard-classic.png]])
LSM:Register(BORDER, "Suaviborder Classic Thin", [[Interface\AddOns\SuaviUI\assets\textures\blizzard-classic-thin.png]])

------------------------------------------------------------
-- MEDIA FETCH HELPER (with fallback for old profiles)
------------------------------------------------------------
-- Default fallback texture path
local solidTexturePath = [[Interface\AddOns\SuaviUI\assets\textures\solid.png]]

-- Safe fetch function that falls back to Suavisolid if texture not found
function SuaviUI:FetchTexture(mediaType, name)
    if not name or name == "" then
        return LSM:Fetch(mediaType, "Suavisolid") or solidTexturePath
    end
    local path = LSM:Fetch(mediaType, name)
    if not path then
        -- Texture not found, fall back to solid
        return LSM:Fetch(mediaType, "Suavisolid") or solidTexturePath
    end
    return path
end

------------------------------------------------------------
-- MEDIA VALIDATION
------------------------------------------------------------
function SuaviUI:CheckMediaRegistration()
    local suaviFontRegistered = LSM:IsValid(FONT, "Suavifont")
    local logoTextureRegistered = LSM:IsValid(BACKGROUND, "Suavilogo")
    local suaviTextureRegistered = LSM:IsValid(STATUSBAR, "Suavitex")
    
    if not (suaviFontRegistered and logoTextureRegistered and suaviTextureRegistered) then
        SuaviUI:Print("Media registration failed:")
        if not suaviFontRegistered then SuaviUI:Print("- Suavifont not registered") end
        if not logoTextureRegistered then SuaviUI:Print("- Suavilogo not registered") end
        if not suaviTextureRegistered then SuaviUI:Print("- Suavitex not registered") end
    end
end 



