NDefines.NGraphics.COUNTRY_COLOR_SATURATION_MODIFIER = 0.85
NDefines.NGraphics.COUNTRY_COLOR_BRIGHTNESS_MODIFIER = 0.8
NDefines_Graphics.NMapMode.MAP_MODE_TERRAIN_TRANSPARENCY = 0.8
NDefines_Graphics.NGraphics.BORDER_WIDTH = 1.5
NDefines_Graphics.NGraphics.PROVINCE_BORDER_FADE_NEAR = 200
NDefines_Graphics.NGraphics.PROVINCE_BORDER_FADE_FAR = 300
NDefines_Graphics.NGraphics.STATE_BORDER_FADE_NEAR = 400
NDefines_Graphics.NGraphics.STATE_BORDER_FADE_FAR = 500
NDefines_Graphics.NGraphics.CAMERA_ZOOM_SPEED_DISTANCE_MULT = 20
NDefines_Graphics.NGraphics.MAPICON_GROUP_STRATEGIC_SIZE = 1000
NDefines_Graphics.NGraphics.MAP_ICONS_STATE_HUGE = 100
NDefines_Graphics.NGraphics.GRADIENT_BORDERS_FIELD_COUNTRY_REFRESH = 30
NDefines.NMapMode.SUPPLY_MAP_MODE_REACH_COLOR = {
    0.0,   0.45, 0.00, 0.20, 1.0,
    0.02,  0.35, 0.12, 0.45, 1.0,
    0.12,  0.20, 0.15, 0.45, 1.0,
    0.2,   0.27, 0.27, 0.50, 1.0,
    0.4,   0.15, 0.25, 0.40, 1.0,
    0.6,   0.20, 0.42, 0.60, 1.0,
    0.8,   0.35, 0.50, 0.30, 1.0,
    1.0,   0.15, 0.54, 0.15, 1.0,
}
for k, v in pairs(NDefines_Graphics) do NDefines[k] = v end
