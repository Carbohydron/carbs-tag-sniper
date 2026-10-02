local ADDON_NAME = ...

CarbsTagSniperDB = CarbsTagSniperDB or {}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CarbsTagSniper|r: " .. msg)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        CarbsTagSniperDB = CarbsTagSniperDB or {}
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

SLASH_CARBSTAGSNIPER1 = "/cts"
SLASH_CARBSTAGSNIPER2 = "/carbstagsniper"
SlashCmdList["CARBSTAGSNIPER"] = function(msg)
    Print("loaded. Macro management is not implemented yet.")
end
