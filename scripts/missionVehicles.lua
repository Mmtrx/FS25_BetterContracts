--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:     Enhance ingame contracts menu.
-- Author:      Royal-Modding / Mmtrx
-- Changelog:
--  v1.0.0.0    28.10.2024  1st port to FS25
--=======================================================================================================

---------------------- mission vehicle loading functions --------------------------------------------
function BetterContracts.loadMissionVehicles(missionManager, superFunc, xmlFilename, baseDir)
	-- overwrites MisionManager:loadVehicleGroups()
	-- this could be called multiple times: by mods, dlcs
	local self = BetterContracts
	debugPrint("%s loadMissionVehicles(%s, %s)", self.name, xmlFilename, baseDir)
	debugPrint("* loadedVehicles %s, overwrittenVehicles %s", self.loadedVehicles, self.overwrittenVehicles)
	-- do not add further vecs to a userdefined setup:
	if self.overwrittenVehicles then return true end 
	
	if superFunc(missionManager, xmlFilename, baseDir) then 
		if self.loadedVehicles then return true end -- we already loaded our extra missionVehicles

		if self.debug then
			self:checkExtraMissionVehicles(self.directory .. "missionVehicles/baseGame.xml",baseDir)
		end
		self:loadExtraMissionVehicles(self.directory.."missionVehicles/baseGame.xml", baseDir)
		self.loadedVehicles = true

		-- determine userdef location: modSettings/FS25_BetterContracts/<mapName>/ 
		local map = g_currentMission.missionInfo.map
		local mapDir = map.id
		if map.isModMap then 
			mapDir = map.customEnvironment
		end
		local path = self.myModSettings .. mapDir .."/"
		createFolder(path)

		local userdef = path.."userDefined.xml"
		local found = fileExists(userdef)
		if not found then 
			userdef = self.myModSettings .. "userDefined.xml"
			found = fileExists(userdef)
		end
		-- we found a userdef file:
		if found and self:checkExtraMissionVehicles(userdef,baseDir) then 
			-- check for other mod:
			if g_modIsLoaded.FS25_DynamicMissionVehicles then
				Logging.warning("[%s] Mod FS25_DynamicMissionVehicles detected. Make sure '%s' contains 'variant definitions'",self.name, userdef)
				local dmv = FS25_DynamicMissionVehicles.DynamicMissionVehicles
				dmv.variants = {}
				dmv:loadVariants(userdef)
			end
			debugPrint("[%s] loading user mission vehicles from '%s'.",self.name, userdef)
			self.overwrittenVehicles = self:loadExtraMissionVehicles(userdef, baseDir)
		end    
		return true
	end
	return false
end
function BetterContracts:checkExtraMissionVehicles(xmlFilename, baseDir)
	-- check if all vehicles specified can be loaded
	local ok = true 
	local xmlFile = XMLFile.load("loadExtraMissionVehicles", xmlFilename)
	if xmlFile == nil then return false end
	-- "requiredMods" section
	local modVehicles = {}
	for _, key in xmlFile:iterator("missionVehicles.requiredMods.mod") do
		local name = xmlFile:getString(key .. "#name")
		local id = xmlFile:getInt(key .. "#id")
		if name == nil then
			Logging.xmlError(xmlFile, "Property name must exist on each mod - \'%s\'", key)
			ok = false
		elseif id == nil then 
			Logging.xmlError(xmlFile, "Property id is missing for mod - \'%s\'", name)
			ok = false
		elseif modVehicles[id] ~= nil then 
			Logging.xmlError(xmlFile, "Duplicate id \'%s\' for mod - \'%s\'", id, name)
			ok = false
		elseif not g_modIsLoaded[name] then 
			Logging.xmlWarning(xmlFile, "Mod \'%s\' is not loaded", name)
			ok = false
		else
			modVehicles[id] = name
			debugPrint("%s: modVehicles[%d] set to %s", self.name,id,name)
		end
	end

	for _, key in xmlFile:iterator("missionVehicles.mission") do
		for _, groupKey in xmlFile:iterator(key .. ".group") do
			for _, vec in xmlFile:iterator(groupKey .. ".vehicle") do
				local ignore = false
				local filename = xmlFile:getString(vec .. "#filename")
				local index = xmlFile:getInt(vec.."#requiredMod")
				local dir = baseDir
				if index ~= nil then 
					if modVehicles[index] then
						dir = g_modNameToDirectory[modVehicles[index]]
					else
						Logging.warning("[%s] required Mod Index %s not found, ignoring mission vehicle %s",
						self.name, index, filename)
						ignore = true
						ok = false
					end
				end
				if not ignore then  
					local vecFilename = Utils.getFilename(filename, dir)
					if vecFilename == nil then
						Logging.xmlError(xmlFile, "Missing \'filename\' attribute forvehicle %q", vec)
						ok = false
					end
					-- try to load from store item
					if g_storeManager:getItemByXMLFilename(vecFilename) == nil then
						Logging.xmlError(xmlFile, "Unable to load store item for xmlfilename \'%q at %q", vecFilename, vec)
						ok = false
					end
				end
			end
		end
	end
	xmlFile:delete()
	if not ok then 
		Logging.warning("[%s] ignoring some groups in mission vehicles file '%s'",self.name,xmlFilename)
	end
	return ok
end
function BetterContracts:loadExtraMissionVehicles(xmlFilename, baseDir)
	local xmlFile = XMLFile.load("loadExtraMissionVehicles", xmlFilename)
	if xmlFile == nil then return false end
	debugPrint("%s loadExtraVehicles(%s, %s)", self.name, xmlFilename, baseDir)
	local mgr = g_missionManager
	local overwriteStd = Utils.getNoNil(xmlFile:getBool("missionVehicles#overwrite"), false)
	if overwriteStd then 
	   g_missionManager.missionVehicles = {}
	end
	local modVehicles = {}

	-- "requiredMods" section
	for _, key in xmlFile:iterator("missionVehicles.requiredMods.mod") do
		local name = xmlFile:getString(key .. "#name")
		local id = xmlFile:getInt(key .. "#id")
		if name == nil then
			Logging.xmlError(xmlFile, "Property name must exist on each mod - \'%s\'", key)
		elseif id == nil then 
			Logging.xmlError(xmlFile, "Property id is missing for mod - \'%s\'", name)
		elseif modVehicles[id] ~= nil then 
			Logging.xmlError(xmlFile, "Duplicate id \'%s\' for mod - \'%s\'", id, name)
		elseif not g_modIsLoaded[name] then 
			Logging.xmlWarning(xmlFile, "Mod \'%s\' is not loaded", name)
		else
			modVehicles[id] = name
			debugPrint("%s: modVehicles[%d] set to %s", self.name,id,name)
		end
	end
	local hasRequiredMods = #modVehicles > 0 

	for _, key in xmlFile:iterator("missionVehicles.mission") do
		local type = xmlFile:getString(key .. "#type")
		if type == nil then
			Logging.xmlError(xmlFile, "Property type must exist on each mission - \'%s\'", key)
		elseif mgr:getMissionType(type) == nil then
			Logging.xmlError(xmlFile, "Mission type \'%s\' is not defined - \'%s\'", type, key)
		else
			if mgr.missionVehicles[type] == nil then
				mgr.missionVehicles[type] = {}
			end
			local typeVecs = mgr.missionVehicles[type]
			for _, groupKey in xmlFile:iterator(key .. ".group") do
				local size = xmlFile:getString(groupKey .. "#size", "medium")
				local vehicles = {}
				local group = {
					["rewardScale"] = xmlFile:getFloat(groupKey .. "#rewardScale", 1),
					["vehicles"] = vehicles,
					["variant"] = xmlFile:getString(groupKey .. "#variant")
				}
				local ok = true
				for _, vec in xmlFile:iterator(groupKey .. ".vehicle") do
					local filename = xmlFile:getString(vec.."#filename")
					local index = xmlFile:getInt(vec.."#requiredMod")
					local dir = baseDir
					local vecFilename
					if index ~= nil then 
						if modVehicles[index] then
							dir = g_modNameToDirectory[modVehicles[index]]
						else
							Logging.warning("[%s] required Mod Index %s not found, ignoring mission vehicle %s",
							self.name, index, filename)
							ok = false
							break
						end
					end
					vecFilename = Utils.getFilename(filename, dir)
					if vecFilename == nil then
						Logging.xmlError(xmlFile, "Missing \'filename\' attribute for vehicle %q", vec)
						ok = false
						break
					end
					if g_storeManager:getItemByXMLFilename(vecFilename) == nil then
						Logging.xmlError(xmlFile, "Unable to load store item for xml filename \'%q at %q",vecFilename, vec)
						ok = false
						break
					end
					local config = nil
					for _, confKey in xmlFile:iterator(vec .. ".configuration") do
							local name = xmlFile:getString(confKey .. "#name" )
							local id = xmlFile:getInt(confKey .. "#id")
							if name == nil then
								Logging.xmlError(xmlFile, "Missing \'name\' attribute for configuration at %q", confKey)
							elseif id == nil then
								Logging.xmlError(xmlFile, "Missing \'id\' attribute for configuration %q at %q", name, confKey)
							elseif g_vehicleConfigurationManager:getConfigurationDescByName(name) == nil then 
								Logging.warning("[%s] configuration %s not found, ignored",
								self.name, name)
							else
								config = config or {}
								config[name] = id
							end
					end
					table.insert(vehicles, {
						["filename"] = vecFilename,
						["configurations"] = config
					})
				end
				if ok then
					if typeVecs[size] == nil then
						typeVecs[size] = {}
					end
					table.insert(typeVecs[size], group)
					group.identifier = #typeVecs[size]
				end
			end
		end
	end
	xmlFile:delete()
	return overwriteStd
end
function BetterContracts:validateMissionVehicles()
	-- check if vehicle groups for each missiontype/fieldsize are defined
	debugPrint("* %s validating Mission Vehicles..", self.name)
	local ok = true
	local type 
	for _,mt in ipairs(g_missionManager.missionTypes) do
		if mt.category == MissionManager.CATEGORY_FIELD or 
		   mt.category == MissionManager.CATEGORY_GRASS_FIELD then
			type = mt.name
			for _,f in ipairs({"small","medium","large"}) do
				if g_missionManager.missionVehicles[type] == nil or 
				 	g_missionManager.missionVehicles[type][f] == nil or 
					#g_missionManager.missionVehicles[type][f] == 0 then
						if type ~= "deadwoodMission" and type ~= "destructibleRockMission" 
							and f ~= "small" then 
						Logging.warning("[%s] No missionVehicles for %s missions on %s fields",
						self.name, type, f)
						ok = false
					end
				end
			end
		end
	end
	return ok
end
function BetterContracts:printGroup(group, menu)
	-- format mission vehicles in group: for menu / for log if true
	menu = menu or false
	local vecs = group.vehicles 
	local vtext = ""
	local row = {}
	local first
	for i,vec in ipairs(vecs) do
		local item = g_storeManager:getItemByXMLFilename(vec.filename)
		local brand = g_brandManager:getBrandByIndex(item.brandIndex).title
		if brand == "None" then brand = "" end
		vtext = string.format("%s %s", brand, item.name)
		if menu then
			table.insert(row, vtext)
		else
			local config = vec.configurations
			if config ~= nil then
				for configName, configValue in pairs(vec.configurations) do
					vtext = vtext .. string.format(" %s:%d", configName, configValue)
				end
			end
			table.insert(row, vtext)
		end
	end
	if menu then 
		return table.remove(row,1), table.concat(row, ", ") 
	else
		return string.format("%4d: %s", group.identifier, table.concat(row, ", "))
	end
end
function BetterContracts:printMissionVehicles(type, size)
	-- print vehicle groups for each missiontype/fieldsize 
	function doGroups(groups)
		local lastVariant
		if groups[1].variant ~= nil then 
			-- sort groups by variant
			table.sort(groups, function(a, b)
				if a.variant == b.variant then 
					return a.identifier < b.identifier 
				end 
				return a.variant < b.variant
				end)
			lastVariant = "yes"
		end
		for i, group in ipairs(groups) do
			if lastVariant and lastVariant ~= group.variant then  
				lastVariant = group.variant
				print(string.format(" variant %s:", lastVariant))
			end
			print(self:printGroup(group))
		end
	end
	function doSizes(type)
		local sep = string.rep("-", 34)
		for _,f in ipairs({"small","medium","large"}) do
			print(sep ..string.format(" %s %s: ", type, f) ..sep)
			if g_missionManager.missionVehicles[type] and 
			 	g_missionManager.missionVehicles[type][f] then 
			 	doGroups(table.copyIndex(g_missionManager.missionVehicles[type][f]))
			end
		end
	end
	print("* MissionManager has loaded following vehicle groups *")
	if type ~= nil and g_missionManager:getMissionTypeDataByName(type) then 
		if size ~= nil and string.find("smallmediumlarge",size) then  
			doGroups(table.copyIndex(
				g_missionManager.missionVehicles[type][size]))
		else
			doSizes(type)
		end
	return
	end
	-- called with no parameters:
	for _,mt in ipairs(g_missionManager.missionTypes) do
		doSizes(mt.name)
	end
end

---------------------- mission vehicle enhancement functions ------------------------
function onSpawnedVehicle(self, vehicles, loadState)
	-- prepended to AbstractMission:onSpawnedVehicle(vehicles, loadState, loadInfo)
	if loadState ~= VehicleLoadingState.OK then return end 

    for _, vehicle in ipairs(vehicles) do
        --local configNameClean = vehicle.configFileNameCl
        if vehicle.typeName == "pallet" or vehicle.typeName == "bigBag" then
            vehicle.addWearAmount = function() end
            vehicle.setOperatingTime = function() end
        else
			vehicle.activeMissionId = self.activeMissionId
			-- save mission type / field for vehicle name
			BetterContracts:vehicleTag(self, vehicle)
        end
    end
end
function BetterContracts:vehicleTag(m, vehicle)
	-- save txt to append to vehicle name
	local fieldNo = m.field and  m.field:getName() or ""
	local txt =  string.format(" (%.8s %s)", m:getTitle(), fieldNo)
	self.missionVecs[vehicle] = txt 
end
function removeAccess(self)
	-- prepend to AbstractFieldMission:removeAccess()
	if not self.isServer then return end 

	local toDelete = {}
	for _, vehicle in ipairs(self.vehicles) do
		BetterContracts.missionVecs[vehicle] = nil 
		-- remove "zombie" pallets/ bigbags from list of leased vehicles:
		if vehicle.isDeleted then 
			table.insert(toDelete, vehicle)
		end
	end
	for _, vehicle in ipairs(toDelete) do
		table.removeElement(self.vehicles, vehicle)
	end
end
function onVehicleReset(self, oldv, newv)
	-- appended to AbstractMission:onVehicleReset
	if oldv.activeMissionId ~= self.activeMissionId then return end

	BetterContracts:vehicleTag(self, newv)
	BetterContracts.missionVecs[oldv] = nil  
end
function vehicleGetName(self, super)
	-- overwrites Vehicle:getName()
	local name = super(self)
	local info = BetterContracts.missionVecs[self] or ""
	if BetterContracts.isOn then 
		name = name..info
	end
	return name
end
---------------------- mission start with select lease vehicles ------------------------
function missionStart(self,superf,spawnVehicles)
	-- overwrites AbstractMission:start()
	local bc = BetterContracts
	if self.isServer and bc.isOn and spawnVehicles then  
		-- a client has opened the lease vehicle selection dialog. Make mission 
		-- unavail for all other clients 
		g_server:broadcastEvent(MissionStartedEvent.new(self))
	
		self:setStatus(MissionStatus.PREPARING)
		bc.waitVecSelect = true
		return true
	end
		return superf(self, spawnVehicles)
end

-- delay mission start event sent from server to client accepting the mission
MissionStartEvent.run = Utils.overwrittenFunction(MissionStartEvent.run, 
function(self, superf, connection)
	if connection:getIsServer() or not self.spawnVehicles then
		return superf(self, connection)
	end
	local bc = BetterContracts
	local user = g_currentMission.userManager:getUserIdByConnection(connection)
	if g_currentMission:getHasPlayerPermission("manageContracts", connection, g_farmManager:getFarmByUserId(user).farmId) then
		local startState = g_missionManager:startMission(self.mission, self.farmId, self.spawnVehicles)
		if (startState == MissionStartState.OK) and bc.waitVecSelect then 
			-- wait for ChangeVecEvent ..
		else
			connection:sendEvent(MissionStartEvent.newServerToClient(startState, self.spawnVehicles))
		end
	else
		connection:sendEvent(MissionStartEvent.newServerToClient(MissionStartState.NO_PERMISSION, self.spawnVehicles))
	end

end)
---------------------- mission vehicle selection Gui --------------------------------

VehicleSelect = {}
local VehicleSelect_mt = Class(VehicleSelect, YesNoDialog)

function VehicleSelect.new(target, custom_mt)
	local self = YesNoDialog.new(target, custom_mt or VehicleSelect_mt)
	self.bc = BetterContracts
	self.groups = {}  	-- mission vehicle groups for current mission
	self.vehicleElements = {}
	return self
end
function VehicleSelect:init(m)
	-- body
	self.marqueeTime = 0
	self.mission = m
	self:getGroups(m)
	self.vehiclesList:reloadData()
	for i= 1,#self.groups do
		if self.groups[i].identifier == m.vehicleGroupIdentifier then 
			self.vehiclesList:setSelectedItem(1, i)
			self.originalGroup = i
			break
		end
	end
	self.vehicleTemplate:unlinkElement()
	--self:onGuiSetupFinished()
end
function VehicleSelect:getGroups(m)
	-- get all possible vehicle groups for mission m
	local typeName = m.type.name
	local size = m:getVehicleSize()
	local variant = m:getVehicleVariant()
	local typeGroups = g_missionManager.missionVehicles[typeName]
	self.groups = {}
	if typeGroups ~= nil then
		local sizeGroups = typeGroups[size]
		if sizeGroups ~= nil then 
			self.groups = table.ifilter(sizeGroups, function(e)
			return variant == nil and true or e.variant == variant
			end)
		end
	end
end
function VehicleSelect:getNumberOfSections(list)
	return 1
end
function VehicleSelect:getNumberOfItemsInSection(list)
	return #self.groups
end
function VehicleSelect:populateCellForItemInSection(list, section, index, cell)
	local bc = BetterContracts
	local first, group = bc:printGroup(self.groups[index], true)
	cell:getAttribute("vFirst"):setText(first)
	cell:getAttribute("vGroup"):setText(group)
end
function VehicleSelect:onListSelectionChanged(list, sec, index)
	debugPrint("**onListSelectionChanged: index %d", index)
	local grp = self.groups[index]
	if grp ~= nil then
		self:updateVehicleBox(grp.vehicles)
	end
end
function VehicleSelect:updateVehicleBox(vecs)
	local frCon = BetterContracts.frCon
	--local m = frCon.lastStartedMission
	--m.vehiclesToLoad = vecs -- VehicleSelect:setVehicles()
	for _, image in pairs(self.vehicleElements) do
		image:delete()
	end
	self.vehicleElements = {}
	self.marqueeTime = 0
	local size = 0
	for _, vec in ipairs(vecs) do
		local item = g_storeManager:getItemByXMLFilename(vec.filename)
		if item == nil then
			Logging.error("Mission uses non-existent vehicle at \'%s\'", vec.filename)
		end
		local imageFile = item.imageFilename
		if vec.configurations ~= nil and item.configurations ~= nil then
			for name, _ in pairs(item.configurations) do
				local id = vec.configurations[name]
				local config = item.configurations[name][id]
				if config ~= nil and (config.vehicleIcon ~= nil and config.vehicleIcon ~= "") then
					imageFile = config.vehicleIcon
					break
				end
			end
		end
		local image = self.vehicleTemplate:clone(self.vehiclesBox)
		image:setImageFilename(imageFile)
		image:setImageColor(nil, nil, nil, nil, 1)
		size = size + image.absSize[1] + image.margin[1] + image.margin[3]
		table.insert(self.vehicleElements, image)
	end
	self.vehiclesBox:setSize(size)
	self.vehiclesBox:invalidateLayout()
	if self.vehiclesBox.maxFlowSize > self.vehiclesBox.parent.absSize[1] and self.vehiclesBox.pivot[1] ~= 0 then
		self.vehiclesBox:setPivot(0, 0.5)
	elseif self.vehiclesBox.maxFlowSize <= self.vehiclesBox.parent.absSize[1] and self.vehiclesBox.pivot[1] ~= 0.5 then
		self.vehiclesBox:setPivot(0.5, 0.5)
	end
	self.vehiclesBox:setPosition(0)
end
function VehicleSelect:onOpen()
	debugPrint("** VehicleSelect:onOpen()")
end
function VehicleSelect:onClickButton(button)
	-- callback from our Vec selection dialog. Esc doesn't change the vec group
	debugPrint("** VehicleSelect: Click %s", button.id)
	local ix = self.originalGroup
	if button.id == "yesButton" then
		_, ix = self.vehiclesList:getSelectedPath()
	end
	ChangeVecEvent.sendEvent(self.mission, ix)
	self:close()
end
function VehicleSelect:update(dt)
	-- update vehicle marquee
	InGameMenuContractsFrame.updateMarqueeAnimation(self,dt)
end