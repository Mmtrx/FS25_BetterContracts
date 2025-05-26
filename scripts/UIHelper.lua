---This class allows easier creation of configuration options in the general settings page.
---Originally created by Farmsim Tim based on discoveries made by Shad0wlife
---Feel free to use this class in your own mods. You may change anything except for the first three lines of this file.
---
---Changelog:
---v1.1: Fixed choice controls when using string values
---v1.2: Choice controls can now be nillable, too
---v1.3: Adapted for BetterContracts, use an own settings page, separate from general settings

UIHelper = {}

function UIHelper.createSection(settingsPage, i18nTitleId)
 ---Creates a new section with the given title
 ---@param settingsPage table @The mods settings page 
 ---@param i18nTitleId string @The I18N ID of the title to be displayed
 ---@return table|nil @The created section element
	local sectionHeader = settingsPage.subTitlePrefab
	--local sectionHeader = settingsPage:getDescendantById("subTitlePrefab")
	--local sectionHeader = g_inGameMenu.pageSettings:getDescendantByName("sectionHeader")

	local sectionTitle = sectionHeader:clone(settingsPage.settingsLayout)
	if sectionTitle then
		--DebugUtil.printTableRecursively(sectionTitle," ",1,1)
		sectionTitle:setText(g_i18n:getText(i18nTitleId))
		sectionTitle.focusId = FocusManager:serveAutoFocusId()
	end
	return sectionTitle
end
function UIHelper.createSpecial(page, id, i18nTextId, min, max, step, unit, target, callbackFunc)
 ---Creates a new special MTO container, with 2 MTOs
	local elementBox = page.doublePrefab:clone(page.settingsLayout)

	UIHelper.updateFocusIds(elementBox)
	elementBox.id = id .. "Box"
	-- Assign the object which shall receive change events
	for i = 1,2 do
		local elementOption = elementBox.elements[i] 		-- 1: multiTextOption left
		elementOption.focusOnHighlight = true
		elementOption.target = target
		elementOption:setCallback("onClickCallback", callbackFunc)
		target.name = g_inGameMenu.pageSettings.name
		-- Change generic values
		elementOption.id = string.format("%s%d",id,i)
		elementOption:setDisabled(false)

		local texts,digits,tmpStep = {}, 0, step
		while tmpStep < 1 do
			digits = digits + 1
			tmpStep = tmpStep * 10
		end
		local formatTemplate = (".%df"):format(digits)
		if i == 2 then  
			min, max = max, 2*max
		end
		for k = min, max, step do
			local text = ("%" .. formatTemplate):format(k)
			if unit then
				text = ("%s %s"):format(text, unit)
			end
			table.insert(texts, text)
		end
		elementOption:setTexts(texts)
	end
	-- Change the text element
	local textElement = elementBox.elements[3]  			-- MultiTextOption Title
	textElement:setText(g_i18n:getText(i18nTextId))
	-- Change the tooltip
	local toolTip = elementBox.elements[2].elements[1]
	toolTip:setText(g_i18n:getText(id .. "_tooltip"))

	table.insert(target.controls, elementBox)
	return elementBox
end

function UIHelper.updateFocusIds(element)
	--Sets the focusId properties of the element and any children to a new unique ID each
	if not element then
		return
	end
	element.focusId = FocusManager:serveAutoFocusId()
	for _, child in pairs(element.elements) do
		UIHelper.updateFocusIds(child)
	end
end

local function createElement(settingsPage, template, id, i18nTextId, target, callbackFunc)
	local elementBox = template:clone(settingsPage.settingsLayout)
	-- Remove any existing focus IDs as they would not be unique and cause trouble later on
	UIHelper.updateFocusIds(elementBox)

	elementBox.id = id .. "Box"
	-- Assign the object which shall receive change events
	local elementOption = elementBox.elements[1]  			-- multiTextOption
	elementOption.focusOnHighlight = true
	elementOption.target = target
	elementOption:setCallback("onClickCallback", callbackFunc)
	-- WORKAROUND: The target serves two purposes:
	-- 1.) Any callback will be executed on the target object
	-- 2.) The focus manager will ignore anything which has a different target _name_ than the current UI
	-- => Since we want to allow any target for callbacks, we just copy the general settings page's name to the target
	target.name = g_inGameMenu.pageSettings.name
	-- Change generic values
	elementOption.id = id
	elementOption:setDisabled(false)
	-- Change the text element
	local textElement = elementBox.elements[2]  			-- MultiTextOption Title
	textElement:setText(g_i18n:getText(i18nTextId))
	-- Change the tooltip
	local toolTip = elementOption.elements[1]
	toolTip:setText(g_i18n:getText(id .. "_tooltip"))

	table.insert(target.controls, elementBox)
	return elementBox
end

function UIHelper.createBoolElement(page, id, i18nTextId, target, callbackFunc)
	local template = page.binaryPrefab
	--local template = page:getDescendantById("binaryPrefab")
	--local template = g_inGameMenu.pageSettings.checkWoodHarvesterAutoCutBox
	return createElement(page, template, id, i18nTextId, target, callbackFunc)
end

function UIHelper.createChoiceElement(page, id, i18nTextId, i18nValueMap, target, callbackFunc, nillable)
	local template = page.multiPrefab
	--local template = page:getDescendantById("multiPrefab")
	--local template = g_inGameMenu.pageSettings.multiVolumeVoiceBox
	local choiceElementBox = createElement(page, template, id, i18nTextId, target, callbackFunc)

	local choiceElement = choiceElementBox.elements[1]
	local texts = {}
	if nillable then
		table.insert(texts, "-")
	end
	for _, valueEntry in pairs(i18nValueMap) do
		local value
		if type(valueEntry) == "number" then
			value = tostring(valueEntry)
		elseif type(valueEntry) == "string" then
			value = g_i18n:getText(valueEntry)
			choiceElementBox.hasStrings = true
		else
			-- legacy syntax
			value = g_i18n:getText(valueEntry.i18nTextId)
			choiceElementBox.hasStrings = true
		end
		table.insert(texts, value)
	end
	choiceElement:setTexts(texts)
	return choiceElementBox
end

function UIHelper.createRangeElement(page, id, i18nTextId, minValue, maxValue, step, unit, target, callbackFunc, nillable)
	--Creates an element which allows choosing one out of several integer values
	local template = page.multiPrefab
	--local template = page:getDescendantById("multiPrefab")
	--debugPrint("*createRangeElement id %s, i18nTitleId %s, unit %s, nill %s",
	--	id, i18nTextId, unit, nillable or false)

	-- createElement does the container, multitext, title, and tooltip:
	local rangeElementBox = createElement(page, template, id, i18nTextId, target, callbackFunc)

	local rangeElement = rangeElementBox.elements[1]
	local texts = {}
	if nillable then
		table.insert(texts, "-")
	end
	local digits = 0
	local tmpStep = step
	while tmpStep < 1 do
		digits = digits + 1
		tmpStep = tmpStep * 10
	end
	local isPercent = false
	if unit=="%" then 
		digits = math.max(digits -2, 0)
		isPercent = true
	end

	local formatTemplate = (".%df"):format(digits)
	for i = minValue, maxValue, step do
		local text = ("%" .. formatTemplate):format(isPercent and 100*i or i)
		if unit then
			text = ("%s %s"):format(text, unit)
		end
		table.insert(texts, text)
	end
	rangeElement:setTexts(texts)
	return rangeElementBox
end

function UIHelper.createControlsDynamically(settingsPage, owningTable, controlProperties, prefix)
 --[[ 
	For each control defined in controlProperties list, a on_<name>_changed 
	callback will be called on change.
	owningTable: table which owns the controls and will receive the callbacks.
	Every control name will be available as <owningTable>.<name> and will be
	added to <owningTable.controls>
	prefix: optional prefix for every control name. This will also be 
	prepended to the i18n keys
 ]]
	local uiControl, id, callback
	for _, controlProps in ipairs(controlProperties) do
		if controlProps.title ~= nil then  
			uiControl = UIHelper.createSection(settingsPage, controlProps.title)
			table.insert(owningTable.controls, uiControl)
			owningTable[controlProps.title] = uiControl
		else
			local id = prefix .. controlProps.name
			local title = controlProps.ui or id  -- set a MTO title from basegame l10n
			local callback = "on_" .. controlProps.name .. "_changed"
			local setting = BCcontrol.new(controlProps.name)

			if controlProps.special ~= nil then 
				uiControl = UIHelper.createSpecial(settingsPage, id, title,
				controlProps.min, controlProps.max, controlProps.step, controlProps.unit,
				owningTable, callback)
	
				uiControl.min = controlProps.min
				uiControl.max = controlProps.max
				uiControl.step = controlProps.step

			elseif controlProps.min ~= nil then
				-- number range control
				uiControl = UIHelper.createRangeElement(
				settingsPage, id, title, 
				controlProps.min, controlProps.max, controlProps.step, controlProps.unit,
				owningTable, callback, controlProps.nillable)
	
				uiControl.min = controlProps.min
				uiControl.max = controlProps.max
				uiControl.step = controlProps.step
				uiControl.nillable = controlProps.nillable
	
			elseif controlProps.values ~= nil then
				-- enum control
				uiControl = UIHelper.createChoiceElement(settingsPage, id, title, controlProps.values, 
					owningTable, callback, controlProps.nillable)
				uiControl.values = controlProps.values -- for mapping values later on, if necessary
				uiControl.nillable = controlProps.nillable
			else
				-- bool switch
				uiControl = UIHelper.createBoolElement(settingsPage, id, title, owningTable, callback)
			end
			uiControl.name = controlProps.name
			uiControl.propName = controlProps.propName -- not used in BC 
			uiControl.autoBind = controlProps.autoBind
			uiControl.setting = setting
			setting.guiElement = uiControl
			
			-- allow accessing the control by its name
			owningTable[controlProps.name] = uiControl 
			-- allow accessing the control by its name
			owningTable.settingsByName[controlProps.name] = setting
			table.insert(owningTable.settings, setting)
		end
		--  table.insert(owningTable.controls, uiControl)  -- already done by createElement()
	
		-- Allow mouse/keyboard selection of the settings
		UIHelper.registerFocusControls(settingsPage, owningTable.controls)
		settingsPage.settingsLayout:invalidateLayout()
	end
end

function UIHelper.registerFocusControls(page, controls)
	-- Hooks into the focus manager at just the right point in time to
	-- register any relevant controls.
	-- Make sure you also supply your section headers here!
	FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
		for _, control in ipairs(controls) do
			if not control.focusId or not FocusManager.currentFocusData.idToElementMapping[control.focusId] then
				if not FocusManager:loadElementFromCustomValues(control, nil, nil, false, false) then
					Logging.warning("Failed loading focus element for %s. Keyboard/controller menu navigation might be bugged.", 
						control.id or control.name)
				end
			end
		end
		-- Invalidate the layout in order to relink items properly
		page.settingsLayout:invalidateLayout()
	end)
end
function UIHelper.setupAutoBindControls(owningTable, targetTable, updateFunc)
	-- Define and store a function to populate the automatically bound controls
   --[[
	Call it when the settings frame gets opened, so that UI controls are 
	being populated with data from targetTable  and updates the properties
	 in targetTable when the user changes values.
	If you need to populate the controls at additional points in time, 
	you can call the "populateAutoBindControls" function in owningTable
	 after calling this method.
	targetTable: table which holds the settings. The name of the controls
	 and the name of the settings must be identical
	updateFunc: function will be called whenever any auto-bound 
	value changes
   ]]
	owningTable.populateAutoBindControls = function()
		for _, control in ipairs(owningTable.controls) do
			if control.autoBind then
				local value = UIHelper.getAutoBoundValueFromTable(control, targetTable)
				UIHelper.setControlValue(control, value)
				control.setting.current = control.elements[1]:getState()
			end
		end
	end

	-- Dynamically create callbacks
	for _, control in ipairs(owningTable.controls) do
		if control.autoBind then
			local callbackName = "on_autoBind_" .. control.name .. "_changed"
			owningTable[callbackName] = function(self, newState)
				local newValue = UIHelper.getControlValue(control, newState)
				UIHelper.setAutoBoundValueInTable(control, newValue, targetTable)
				control.setting.current = newState
				if updateFunc then  -- updateFunc is onSettingsChange
					updateFunc(owningTable, control, newValue)
				end
			end
			-- Update the callback
			control.elements[1]:setCallback("onClickCallback", callbackName)
		end
	end
end

function UIHelper.getAutoBoundValueFromTable(control, targetTable)
-- Reads the current value of an auto bound control from the settings 
-- object (rather than from the UI control's current state)
	if control.subTable == nil then
		return targetTable[control.propName or control.name]
	else
		return targetTable[control.subTable][control.propName or control.name]
	end
end

function UIHelper.setAutoBoundValueInTable(control, value, targetTable)
-- Writes the current value for an auto bound control to the settings object
	if control.subTable == nil then
		targetTable[control.propName or control.name or "ERROR"] = value
	else
		targetTable[control.subTable][control.propName or control.name] = value
	end
end

function UIHelper.setRangeValue(control, value)
-- Sets a range control to the given value. The method will find 
-- the appropriate index for the value automatically.
	local valueIndex
	if control.nillable and value == nil then
		valueIndex = 1
	else
		valueIndex = math.floor(((value - control.min) / control.step + 1) + 0.5) -- floor(x+0.5) = round(x)
		if control.nillable then
			valueIndex = valueIndex + 1
		end
	end
	control.elements[1]:setState(valueIndex)
end

function UIHelper.getRangeValue(control, controlState)
--Retrieves the current value of a UI range control.
	if control.nillable and controlState == 1 then
		return nil
	else
		local offset = 1
		if control.nillable then
			offset = 2
		end
		return control.min + control.step * (controlState - offset)
	end
end

function UIHelper.setChoiceValue(control, value)
-- Sets a choice control to the given state or (for range controls) value.
-- The method will find the appropriate state index for a range 
-- value automatically.
	if control.hasStrings then
		control.elements[1]:setState(value)
	else
		-- Find the index of the value which is being used
		for index, val in control.values do
			if val == value then
				control.elements[1]:setState(index)
			end
		end
	end
end

function UIHelper.getChoiceValue(control, controlState)
-- Retrieves the current value of a UI choice control.
	if control.hasStrings then
		return controlState
	else
		return control.values[controlState]
	end
end

function UIHelper.setBoolValue(control, value)
--Sets the current value for a UI yes/no control.
	control.elements[1]:setState(value and 2 or 1)
end

function UIHelper.getBoolValue(controlState)
--Gets the current value of a UI yes/no control
	return controlState == 2
end

function UIHelper.setControlValue(control, value)
--Sets the given value for the given control. The function will 
-- automatically determine whether this is a yes/no, an enum,
-- or a number range value
	if control.min ~= nil then
		UIHelper.setRangeValue(control, value)
	elseif control.values ~= nil then
		UIHelper.setChoiceValue(control, value)
	else
		UIHelper.setBoolValue(control, value)
	end
end

function UIHelper.getControlValue(control, controlState)
-- Retrieves the value from the given control based on the 
--control state (obtained from the callback function)
	if control.min ~= nil then
		return UIHelper.getRangeValue(control, controlState)
	elseif control.values ~= nil then
		return UIHelper.getChoiceValue(control, controlState)
	else
		return UIHelper.getBoolValue(controlState)
	end
end