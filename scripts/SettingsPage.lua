SettingsPage = {}
local SettingsPage_mt = Class(SettingsPage, FrameElement)

function SettingsPage.new(custom_mt)
	local self = FrameElement.new(nil, custom_mt or SettingsPage_mt)
	self.settings = {}  		-- list of all setting objects 
	self.settingsByName = {}  	-- contains setting objects by name 
	self.controls = {}
	return self
end
