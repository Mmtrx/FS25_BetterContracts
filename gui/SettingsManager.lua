--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:		Enhance ingame contracts menu.
-- Author:		Mmtrx
-- Changelog:
--  v1.1.0.0    08.01.2025  UI settings page, discount mode
--=======================================================================================================
SettingsManager = {}
local SettingsManager_mt = Class(SettingsManager, TabbedMenuFrameElement)

function SettingsManager.new(target, custom_mt)
	local self = GuiElement.new(target, custom_mt or SettingsManager_mt)
	self.settings = {}  		-- list of all setting objects 
	self.settingsByName = {}  	-- contains setting objects by name 
	self.controls = {}
	return self
end
function InGameMenuSettingsFrame:showSettings()
	-- callback for mod page tabs button
	-- set the multitext to corresponding state
	local modState = BetterContracts.settingsMgr.modState
	self.subCategoryPaging:setState(modState, true)
end
function InGameMenuSettingsFrame:onClickControls()
	-- set to last but one state
	self.subCategoryPaging:setState(#self.subCategoryPaging.texts -1, true)
end

function SettingsManager:insertSettingsPage()
   -- make additional subCategory tab button  
	local pageSettings = g_inGameMenu.pageSettings
	local modButton = pageSettings.subCategoryTabs[1]:clone(pageSettings.subCategoryBox)
	modButton.textUpperCase = false
	modButton:setText("BetterContracts")
	modButton.onClickCallback = InGameMenuSettingsFrame.showSettings
	-- overwrite controls setting button callback:
	pageSettings.subCategoryTabs[5].onClickCallback = InGameMenuSettingsFrame.onClickControls

	table.insert(pageSettings.subCategoryTabs, modButton) 
	self.modPageNr = #pageSettings.subCategoryPages + 1   -- until now: always 6
	--self.modState = #pageSettings.subCategoryPaging.texts + 1 -- moved to frameOpen

	pageSettings.subCategoryPaging:addText(self.modPageNr)
	pageSettings.subCategoryBox:invalidateLayout()

	debugPrint("**insertSettingsPage subCategoryTabs:")
	if BetterContracts.config.debug then
		for i=1,#pageSettings.subCategoryTabs do
			printf("%d %s",i, pageSettings.subCategoryTabs[i].text)
		end
	end

   -- make additional subCategory page  
	local modPage = pageSettings.subCategoryPages[1]:clone(pageSettings)

	table.insert(pageSettings.subCategoryPages, modPage)
	modPage.id = "subCategoryPages[6]"
	modPage.settingsLayout =
		modPage:getFirstDescendant(function(elem) 
		return elem.profile == "fs25_settingsLayout" 
		end) 
	modPage.noPermission = 		
		modPage:getFirstDescendant(function(elem) 
		return elem.profile == "fs25_settingsNoPermissionText" 
		end) 

	modPage.settingsLayout.id = "settingsLayout"
	modPage.settingsLayout.scrollDirection = "vertical"
	modPage.noPermission:setVisible(false)

	-- remove inner controls
	for i = #modPage.settingsLayout.elements,1,-1 do
		modPage.settingsLayout.elements[i]:delete()
	end
	UIHelper.updateFocusIds(modPage)
	
	return modPage
end
function SettingsManager:init()
	local bc = BetterContracts
	local modPage = self:insertSettingsPage()
	bc.modPage = modPage  -- cloned from generalSettings: id="subCategoryPages[2]"

	-- dynamically generate our gui elements for settings page
    UIHelper.createControlsDynamically(modPage, self, ControlProperties, "bc_")
   	--InfoDialog.show(string.format("***settingsPage after createControlsDynamically %s",self))

    UIHelper.setupAutoBindControls(self, bc.config, SettingsManager.onSettingsChange)  

    self.populateAutoBindControls() 			-- Apply initial values	
    self.refreshMP:setVisible(g_currentMission.missionDynamicInfo.isMultiplayer)

    -- make controls in development invisible:
    for _, name in ipairs(ControlDevelop) do
    	self[name]:setVisible(bc.config.debug)
    	if ControlDep[name] then 
    		for _, nam in ipairs(ControlDep[name]) do
		    	self[nam]:setVisible(bc.config.debug)
    		end
    	end
    end
	modPage.settingsLayout:invalidateLayout()	-- Update the focus manager

	-- adjust settings for our menu page when it is selected:
	Utility.appendedFunction(InGameMenuSettingsFrame,"onFrameOpen",onSettingsFrameOpen)
	
	-- save the original subCategoryPaging callback:
	modPage.updateSubCategoryPages = g_inGameMenu.pageSettings.subCategoryPaging.onClickCallback  
	-- install our own:
	g_inGameMenu.pageSettings.subCategoryPaging.onClickCallback = updateSubCategoryPages
end
function SettingsManager:updateDisabled(controlName)
	-- set disabled states for dependent controls
    local disabled = self[controlName].elements[1]:getState() == 1
    for _, nam in ipairs(ControlDep[controlName]) do
    	self[nam].setting:updateDisabled(disabled)
    end
end
function updateSubCategoryPages(self, state)
	-- overwrites InGameMenuSettingsFrame:updateSubCategoryPages() 
	debugPrint("**updateSubCategoryPages state = %d", state)
	local modPage = BetterContracts.modPage
	local modState = BetterContracts.settingsMgr.modState
	if state == modState then 
		self.settingsSlider:setDataElement(modPage.settingsLayout)
		FocusManager:linkElements(self.subCategoryPaging, FocusManager.TOP, 
			modPage.settingsLayout.elements[#modPage.settingsLayout.elements].elements[1])
		FocusManager:linkElements(self.subCategoryPaging, FocusManager.BOTTOM, 
			modPage.settingsLayout.elements[1].elements[1])
		
		modPage.updateSubCategoryPages(self, state)
		-- set page header:
		self.categoryHeaderIcon:setImageSlice(nil, "gui.icon_ingameMenu_contracts")
		self.categoryHeaderText:setText(g_i18n:getText("bc_name"))
	else
		return modPage.updateSubCategoryPages(self, state)
	end
end
function onSettingsFrameOpen(self)
	-- appended to InGameMenuSettingsFrame:onFrameOpen()
	local modPage = BetterContracts.modPage
	local settingsPage = BetterContracts.settingsMgr
	local isMultiplayer = g_currentMission.missionDynamicInfo.isMultiplayer

	-- our mod button should always be the last one in subCategoryPaging MTO
	settingsPage.modState = #g_inGameMenu.pageSettings.subCategoryPaging.texts

	if isMultiplayer and not (g_inGameMenu.isServer or g_inGameMenu.isMasterUser) then  
		modPage.settingsLayout:setVisible(false)
		--modPage.gameSettingsSeparator:setVisible(false)
		modPage.noPermission:setVisible(true)
	else
		modPage.settingsLayout:setVisible(true)
		--modPage.gameSettingsSeparator:setVisible(true)
		modPage.noPermission:setVisible(false)

		if settingsPage.populateAutoBindControls then 
        -- Note: This method is created dynamically by UIHelper.setupAutoBindControls
			settingsPage.populateAutoBindControls() 
		end
		-- apply initial disabled states
    	settingsPage:updateDisabled("lazyNPC")				
    	settingsPage:updateDisabled("discountMode")			
    	settingsPage:updateDisabled("hardMode")		
	
		--  make alternating backgrounds
		local light = true
		for _, elem in pairs(modPage.settingsLayout.elements) do
			if elem.name == "sectionHeader" then
				light = true
			else
				local color = InGameMenuSettingsFrame.COLOR_ALTERNATING[light]
				elem:setImageColor(nil, unpack(color))
				light = not light
			end
		end
	end
end
function SettingsManager:onSettingsChange(control, newValue) 
	-- called by the controls onClick callback. Callback has already set the corresponding
	-- bc.config value on client who changed it
	local bc = BetterContracts
    local setting = control.setting

    -- disable dependent settings if needed
    if setting.name == "lazyNPC" then  
    	for _, nam in ipairs(ControlDep.lazyNPC) do
    		self[nam].setting:updateDisabled(not newValue)
    	end
    elseif setting.name == "discountMode" then  
    	for _, nam in ipairs(ControlDep.discountMode) do
    		self[nam].setting:updateDisabled(not newValue)
    	end
    	-- adjust map context farmland box:
    	bc:discountVisible(newValue)

    elseif setting.name == "hardMode" then 
    	for _, nam in ipairs(ControlDep.hardMode) do
    		self[nam].setting:updateDisabled(not newValue)
    	end
    elseif setting.name == "toDeliver" then 
		HarvestMission.SUCCESS_FACTOR = newValue
    end	
    SettingsEvent.sendEvent(setting)
end
