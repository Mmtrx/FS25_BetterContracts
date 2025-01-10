---This class allows easier creation of configuration options in the general settings page.
---Originally created by Farmsim Tim based on discoveries made by Shad0wlife
---Feel free to use this class in your own mods. You may change anything except for the first three lines of this file.
---
---Changelog:
---v1.1: Fixed choice controls when using string values
---v1.2: Choice controls can now be nillable, too
---v1.3: Adapted for BetterContracts, use an own settings page, separate from general settings
---@class UIHelper
UIHelper = {}

---Creates a new section with the given title
---@param settingsPage table @The mods settings page 
---@param i18nTitleId string @The I18N ID of the title to be displayed
---@return table|nil @The created section element
function UIHelper.createSection(settingsPage, i18nTitleId)
	local sectionHeader = g_inGameMenu.pageSettings:getDescendantByName("sectionHeader")

	local sectionTitle = sectionHeader:clone(settingsPage.settingsLayout)
	if sectionTitle then
		--DebugUtil.printTableRecursively(sectionTitle," ",1,1)
		sectionTitle:setText(g_i18n:getText(i18nTitleId))
		sectionTitle.focusId = FocusManager:serveAutoFocusId()
	end
	return sectionTitle
end

---Sets the focusId properties of the element and any children to a new unique ID each
---@param element table the element
function UIHelper.updateFocusIds(element)
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
	target.name = settingsPage.name
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

---Adds a simple yes/no switch to the UI
---@param page   				table       @The mods object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nTextId            string      @The key in the internationalization XML (must be two keys with a _short and _long suffix)
---@param target                table       @The object which contains the callback func
---@param callbackFunc          string      @The name of the function to call when the value changes
---@return                      table       @The created object
function UIHelper.createBoolElement(page, id, i18nTextId, target, callbackFunc)
	local template = g_inGameMenu.pageSettings.checkWoodHarvesterAutoCutBox
	return createElement(page, template, id, i18nTextId, target, callbackFunc)
end

---Creates an element which allows choosing one out of several text values
---@param page   				table       @The mods object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nTextId            string      @The key in the internationalization XML (must be two keys with a _short and _long suffix)
---@param i18nValueMap          table       @An map of values containing translation IDs for the possible values
---@param target                table       @The object which contains the callback func
---@param callbackFunc          string      @The name of the function to call when the value changes
---@param nillable              string      @If set to true, the first entry will mean the setting has no effect. The text value will be "-".
---@return                      table       @The created object
function UIHelper.createChoiceElement(page, id, i18nTextId, i18nValueMap, target, callbackFunc, nillable)
	local template = g_inGameMenu.pageSettings.multiVolumeVoiceBox
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

---Creates an element which allows choosing one out of several integer values
---@param page   				table       @The mods object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nTextId            string      @The key in the internationalization XML (must be two keys with a _short and _long suffix)
---@param minValue              integer     @The first value which can be selected
---@param maxValue              integer     @The last value which can be selected
---@param step                  integer     @The difference between any two values. Make sure this matches max value
---@param unit                  string      @The unit to be displayed (may be empty)
---@param target                table       @The object which contains the callback func
---@param callbackFunc          string      @The name of the function to call when the value changes
---@param nillable              string      @If set to true, the first entry will mean the setting has no effect. The text value will be "-".
---@return                      table       @The created object
function UIHelper.createRangeElement(page, id, i18nTextId, minValue, maxValue, step, unit, target, callbackFunc, nillable)
	-- createElement does the container, multitext, title, and tooltip
	local template = g_inGameMenu.pageSettings.multiVolumeVoiceBox
	--debugPrint("*createRangeElement id %s, i18nTitleId %s, unit %s, nill %s",
	--	id, i18nTextId, unit, nillable or false)
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

---Dynamically creates controls based on the controlProperties configuration table.
---For bool values, supply just the name, for ranges, additionally supply min, max and step, and for choices, supply a values table in addition to the name
---For choices, you can also set nillable to true to get a "-" item for base game behavior, for example.
---For every control name, a <prefix>_<name>_long and _short text must exist in the l10n files.
---The _short text will be the title of the setting, the _long" text will be its tool tip.
---For each control, a on_<name>_changed callback will be called on change.
---@param settingsPage table @The general settings page
---@param owningTable table @The table which owns the controls and will receive the callbacks. Every control name will be available as <owningTable>.<name> and will be added to <owningTable.controls>
---@param controlProperties table @A table comprised of entries as described above
---@param prefix string @An optional prefix for every control name. This will also be prepended to the i18n keys
function UIHelper.createControlsDynamically(settingsPage, owningTable, controlProperties, prefix)
	local uiControl, id, callback
	for _, controlProps in ipairs(controlProperties) do
		if controlProps.title ~= nil then  
			uiControl = UIHelper.createSection(settingsPage, controlProps.title)  --
			table.insert(owningTable.controls, uiControl)
			owningTable[controlProps.title] = uiControl
		else
			local id = prefix .. controlProps.name
			local title = controlProps.ui or id  -- set a MTO title from basegame l10n
			local callback = "on_" .. controlProps.name .. "_changed"

			local setting = BCcontrol.new(controlProps.name)

			if controlProps.min ~= nil then
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

---Hooks into the focus manager at just the right point in time to register any relevant controls.
---Make sure you also supply your section headers here!
---@param controls table @A list of controls
function UIHelper.registerFocusControls(page, controls)
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

---Makes sure UI controls are being populated with data from targetTable when the settings frame gets opened, and updates the properties in targetTable when the user changes values.
---If you need to populate the controls at additional points in time, you can call the "populateAutoBindControls" function in owningTable after calling this method.
---Whenever a value changes, the updateFunc will be called, if it was supplied
---@param owningTable table @The table which owns the controls.
---@param targetTable table @The table which holds the settings. The name of the controls and the name of the settings must be identical
---@param updateFunc function @This function will be called whenever any auto-bound value changes
function UIHelper.setupAutoBindControls(owningTable, targetTable, updateFunc)
	-- Define and store a function which is able to populate the automatically bound controls
	-- will be called from my own onFrameOpen, appended to basegame frame open func
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

---Reads the current value of an auto bound control from the settings object (rather than from the UI control's current state)
---@param control table @The UI control
---@param targetTable table @The table which is bound to the control
---@return any @The value
function UIHelper.getAutoBoundValueFromTable(control, targetTable)
	if control.subTable == nil then
		return targetTable[control.propName or control.name]
	else
		return targetTable[control.subTable][control.propName or control.name]
	end
end

---Writes the current value for an auto bound control to the settings object
---@param control table @The UI control
---@param value any @The value
---@param targetTable table @The table which is bound to the control
function UIHelper.setAutoBoundValueInTable(control, value, targetTable)
	if control.subTable == nil then
		targetTable[control.propName or control.name or "ERROR"] = value
	else
		targetTable[control.subTable][control.propName or control.name] = value
	end
end

---Sets a range control to the given value. The method will find the appropriate index for the value automatically.
---@param control table @The UI control
---@param value number @The value which shall be displayed to the user
function UIHelper.setRangeValue(control, value)
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

---Retrieves the current value of a UI range control.
---@param control table @The UI control
---@param controlState number @The currently selected index
---@return number|nil @The value which was selected by the user (rather than the index)
function UIHelper.getRangeValue(control, controlState)
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

---Sets a choice control to the given value. The method will find the appropriate index for the value automatically.
---@param control table @The UI control
---@param value number @The value which shall be displayed to the user, except for enums, where this is the index
function UIHelper.setChoiceValue(control, value)
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

---Retrieves the current value of a UI choice control.
---@param control table @The UI control
---@param controlState number @The currently selected index
---@return number|nil @The value which was selected by the user (rather than the index, except for enums, where this will be the index)
function UIHelper.getChoiceValue(control, controlState)
	if control.hasStrings then
		return controlState
	else
		return control.values[controlState]
	end
end

---Sets the current value for a UI yes/no control.
---@param control table @The UI control
---@param value number @The value which shall be displayed to the user
function UIHelper.setBoolValue(control, value)
	control.elements[1]:setState(value and 2 or 1)
end

---Gets the current value of a UI yes/no control
---@param controlState number @The currently selected index of the control.
---@return boolean @The yes/no value as selected by the user
function UIHelper.getBoolValue(controlState)
	return controlState == 2
end

---Sets the given value for the given control. The function will automatically determine whether this is a yes/no, an enum or a number range value
---@param control table @The control
---@param value any @The value
function UIHelper.setControlValue(control, value)
	if control.min ~= nil then
		UIHelper.setRangeValue(control, value)
	elseif control.values ~= nil then
		UIHelper.setChoiceValue(control, value)
	else
		UIHelper.setBoolValue(control, value)
	end
end

---Retrieves the value from the given control based on the control state (which is obtained from the callback function)
---@param control table @The UI control
---@param controlState number @The current index of the selected value
---@return any @The value of the control. This could be a boolean, a number value, an enum value or nil dependent on the type of control
function UIHelper.getControlValue(control, controlState)
	if control.min ~= nil then
		return UIHelper.getRangeValue(control, controlState)
	elseif control.values ~= nil then
		return UIHelper.getChoiceValue(control, controlState)
	else
		return UIHelper.getBoolValue(controlState)
	end
end