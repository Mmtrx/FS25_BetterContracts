--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:		Enhance ingame contracts menu.
-- Author:		Mmtrx
-- Changelog:
--  v1.1.0.0    08.01.2025  UI settings page, discount mode
--  v1.1.1.1    04.02.2025  fix white UI page (#19, #24, #29). Fix server save/load #22, #27, #30.
-- 							fix ContractBoost compat #28
--=======================================================================================================
SettingsPage = {}
local SettingsPage_mt = Class(SettingsPage, FrameElement)
function SettingsPage.new(custom_mt)
	local self = FrameElement.new(nil, custom_mt or SettingsPage_mt)
	self.settings = {}  		-- list of all setting objects 
	self.settingsByName = {}  	-- contains setting objects by name 
	self.controls = {}
	return self
end
function SettingsPage:onClickBC()
	-- callback for mod page tabs button: set the multitext to corresponding state
  local bc = BetterContracts
	local modState = bc.settingsMgr.modState
	if modState == nil then 
		Logging.error("onClick BetterContracts: modState is nil")
		return
	end
	bc.frSet.subCategoryPaging:setState(modState, true)
end

SettingsManager = {}
local SettingsManager_mt = Class(SettingsManager, FrameElement)

function SettingsManager.new(custom_mt)
	local self = FrameElement.new(nil, custom_mt or SettingsManager_mt)
	self.settings = {}  		-- list of all setting objects 
	self.settingsByName = {}  	-- contains setting objects by name 
	self.controls = {}
	return self
end
function addElementAtPosition(element, target, pos)
	if element.parent ~= nil then
		element.parent:removeElement(element)
	end
	table.insert(target.elements, pos, element)
	element.parent = target
end
function SettingsManager:insertSettingsPage()
  -- make additional subCategory tab button  
  local bc = BetterContracts
  local modPage = bc.modPage  			-- modPage = screencontroller
  local bcPage = bc.modPage.bcPage  -- the "TabbedContainer"
  local bcTab = bc.modPage.bcTab 		-- our mod button in subCategoryBox
	local pageSettings = g_inGameMenu.pageSettings
	local pos = #pageSettings.subCategoryTabs +1   -- until now: always 6
	self.modPageNr = pos
	-- our button / page is the last in the list
	addElementAtPosition(bcPage, pageSettings.subCategoryPages[1].parent, pos)
	addElementAtPosition(bcTab, pageSettings.subCategoryBox, pos)
	pageSettings:updateAbsolutePosition()

	bcPage:setTarget(pageSettings, bcPage.target)
	bcTab:setTarget(pageSettings, bcTab.target)
	
	-- dynamically generate our gui elements for settings page
	UIHelper.createControlsDynamically(modPage, self, ControlProperties, "bc_")
	UIHelper.setupAutoBindControls(self, bc.config, SettingsManager.onSettingsChange)  
	
	-- remove prefab controls
	bcPage:getDescendantById("subTitlePrefab"):delete()
	bcPage:getDescendantById("binaryPrefab"):delete()
	bcPage:getDescendantById("multiPrefab"):delete()
	bcPage:getDescendantById("doublePrefab"):delete()

	pageSettings.subCategoryPages[pos] = bcPage
	pageSettings.subCategoryTabs[pos] = bcTab

	debugPrint("** SettingsManager: subCategoryTabs:")
	if BetterContracts.config.debug then
		for i=1,#pageSettings.subCategoryTabs do
			printf("%3d %s",i, pageSettings.subCategoryTabs[i].text)
		end
	end
	return bcPage, bcTab
end
function SettingsManager:init()
	local currentGui = FocusManager.currentGui
	local bc = BetterContracts
	local pageSettings = bc.frSet
	local bcPage, modButton = self:insertSettingsPage()

	self.populateAutoBindControls() 			-- Apply initial values	
	self.refreshMP:setVisible(g_currentMission.missionDynamicInfo.isMultiplayer)

	-- Update the focus manager:
	FocusManager:setGui(pageSettings.name)
	FocusManager:removeElement(bcPage)
	FocusManager:removeElement(modButton) -- if we made our tab button from a gui.xml
	FocusManager:loadElementFromCustomValues(bcPage)
	FocusManager:loadElementFromCustomValues(modButton)
	FocusManager:setGui(currentGui)
	bc.modPage.settingsLayout:invalidateLayout()	

	-- set our header info, to be picked up in updateSubCategoryPages()
	InGameMenuSettingsFrame.SUB_CATEGORY.BCONTRACTS = self.modPageNr
	InGameMenuSettingsFrame.HEADER_SLICES[InGameMenuSettingsFrame.SUB_CATEGORY.BCONTRACTS] = 
		"gui.icon_ingameMenu_contracts"
	InGameMenuSettingsFrame.HEADER_TITLES[InGameMenuSettingsFrame.SUB_CATEGORY.BCONTRACTS] = 
		"bc_name"

	-- adjust settings for our menu page on frame open:
	Utility.appendedFunction(pageSettings,"onFrameOpen", onSettingsFrameOpen)
	
	-- subCategoryPaging callback:
	Utility.overwrittenFunction(pageSettings.subCategoryPaging, 
		"onClickCallback", updateSubCategoryPages) 		
	
	debugPrint("** SettingsManager:initiated")
end
function onSettingsFrameOpen(self)
	-- appended to InGameMenuSettingsFrame:onFrameOpen()
	debugPrint("**onSettingsFrameOpen()")
	self.isOpening = true
	local bc = BetterContracts
	local modPage = bc.modPage
	local settingsMgr = bc.settingsMgr
	local isMultiplayer = g_currentMission.missionDynamicInfo.isMultiplayer

	-- our mod button should always be the last one in subCategoryPaging MTO
	settingsMgr.modState = #g_inGameMenu.pageSettings.subCategoryPaging.texts
	
	-- make controls in development invisible:
	for _, name in ipairs(ControlDevelop) do
		settingsMgr[name]:setVisible(bc.config.debug)
		if ControlDep[name] then 
			for _, nam in ipairs(ControlDep[name]) do
				settingsMgr[nam]:setVisible(bc.config.debug)
			end
		end
	end

	if isMultiplayer and not (g_inGameMenu.isServer or g_inGameMenu.isMasterUser) then  
		modPage.settingsLayout:setVisible(false)
		modPage.bcNoPermissionText:setVisible(true)
	else
		modPage.settingsLayout:setVisible(true)
		modPage.bcNoPermissionText:setVisible(false)

		if settingsMgr.populateAutoBindControls then 
		  -- Note: This method is created dynamically by UIHelper.setupAutoBindControls
			settingsMgr.populateAutoBindControls() 
		end
		-- apply initial disabled states
		settingsMgr:updateDisabled("lazyNPC")				
		settingsMgr:updateDisabled("discountMode")			
		settingsMgr:updateDisabled("hardMode")

		if bc.contractBoost then 
		-- disable if ContractBoost.settings.enableContractValueOverrides is on
			 local disabled = g_currentMission.contractBoostSettings.enableContractValueOverrides
			 settingsMgr.rewardMultiplier.setting:updateDisabled(disabled)
			 settingsMgr.rewardMultiplierMow.setting:updateDisabled(disabled)
		end	
		--  make alternating backgrounds
		modPage.bcPage:setVisible(true)
		self:updateAlternatingElements(modPage.settingsLayout)
	end
	self.isOpening = false
end
function updateSubCategoryPages(self, superf, state)
	-- overwrites InGameMenuSettingsFrame:updateSubCategoryPages() 
	debugPrint("**updateSubCategoryPages state = %d", state)
	local layout = BetterContracts.modPage.settingsLayout
	local retValue = superf(self, state)
	local val = self.subCategoryPaging.texts[state]

	if val ~= nil and tonumber(val) == InGameMenuSettingsFrame.SUB_CATEGORY.BCONTRACTS then
		self.settingsSlider:setDataElement(layout)
		FocusManager:linkElements(self.subCategoryPaging, FocusManager.TOP, 
			layout.elements[#layout.elements].elements[1])
		FocusManager:linkElements(self.subCategoryPaging, FocusManager.BOTTOM, 
			layout:findFirstFocusable(true))
	end
	return retValue
end
function SettingsManager:updateDisabled(controlName)
	-- set disabled states for dependent controls
	 local disabled = self[controlName].elements[1]:getState() == 1
	 for _, nam in ipairs(ControlDep[controlName]) do
		self[nam].setting:updateDisabled(disabled)
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

	 elseif setting.name:sub(1,3) == "gen" then 
		bc:updateGeneration()
	 end	
	 if g_currentMission:getIsClient() then 
	 	SettingsEvent.sendEvent(setting)
	 end
end
