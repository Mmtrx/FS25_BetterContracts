--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:     Enhance ingame contracts menu.
-- Author:      Mmtrx
-- Changelog:
--  v1.0.0.0    28.10.2024  1st port to FS25
--  v1.2.0.0    12.05.2025  New: leased vehicle selection dialog
--  v1.2.0.2 	25.05.2025  added tag "fieldSize" in userDefined.xml
--  v1.2.0.4    17.08.2025  Leased Vehicle Selection: Esc doesn't start contract
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

		self:checkExtraMissionVehicles(self.directory .. "missionVehicles/baseGame.xml",baseDir)
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
		if found then
			if self:checkExtraMissionVehicles(userdef,baseDir) then 
			-- check for other mod:
				if g_modIsLoaded.FS25_DynamicMissionVehicles then
					Logging.warning("[%s] Mod FS25_DynamicMissionVehicles detected. Make sure '%s' contains 'variant definitions'",self.name, userdef)
					local dmv = FS25_DynamicMissionVehicles.DynamicMissionVehicles
					dmv.variants = {}
					dmv:loadVariants(userdef)
				end
				debugPrint("[%s] loading user mission vehicles from '%s'.",self.name, userdef)
				self.overwrittenVehicles = self:loadExtraMissionVehicles(userdef, baseDir, true)
			else
				Logging.warning(
				"[%s] userDefined.xml not loaded, please remove errors.",
				self.name)
			end
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
	local fnam = Utils.getFilenameFromPath(xmlFilename)

	-- check field sizes
	local fkey = "missionVehicles.fieldSize" 
	if xmlFile:hasProperty(fkey) then  
		local medium =xmlFile:getFloat(fkey.."#medium")
		local large = xmlFile:getFloat(fkey.."#large")
		if not (medium and large) then  
			Logging.error(
			"[check %s]: Both 'medium' and 'large' values mut be given for property 'fieldSize'",
				fnam)
			ok = false
		elseif medium > large then  
			Logging.error(
			"[check %s]: 'medium' value (%.1f) must be smaller than 'large' (%.1f)",
				fnam, medium, large)
			ok = false
		end
	end
	-- "requiredMods" section
	self.modVehicles = {}
	for _, key in xmlFile:iterator("missionVehicles.requiredMods.mod") do
		local name = xmlFile:getString(key .. "#name")
		local id = xmlFile:getInt(key .. "#id")
		if name == nil then
			Logging.error("[check %s]: Property name must exist on each mod - \'%s\'", fnam, key)
			ok = false
		elseif id == nil then 
			Logging.error("[check %s]: Property id is missing for mod - \'%s\'", fnam, name)
			ok = false
		elseif self.modVehicles[id] ~= nil then 
			Logging.error("[check %s]: Duplicate id \'%s\' for mod - \'%s\'", fnam, id, name)
			ok = false
		elseif not g_modIsLoaded[name] then 
			debugPrint("[check %s]: Mod %s \'%s\' is not loaded", fnam, id, name)
			ok = false
		else
			self.modVehicles[id] = name
			debugPrint("[check %s] modVehicles[%d] set to %s", fnam, id,name)
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
					if self.modVehicles[index] then
						dir = g_modNameToDirectory[self.modVehicles[index]]
					else
						debugPrint("[check %s] required Mod Index %s not found, ignoring mission vehicle %s",
						fnam, index, filename)
						ignore = true
						ok = false
					end
				end
				if not ignore then  
					local vecFilename = Utils.getFilename(filename, dir)
					if vecFilename == nil then
						Logging.error("[check %s] Missing \'filename\' attribute for vehicle %q", fnam, vec)
						ok = false
					end
					-- try to load from store item
					if g_storeManager:getItemByXMLFilename(vecFilename) == nil then
						Logging.xmlError(xmlFile, "Unable to load store item for xmlfilename \'%q at %q", vecFilename, vec)
						ok = false
					end
					if not ok and index ~= nil then  -- the mod could not be loaded
						self.modVehicles[index] = nil 
					end
				end
			end
		end
	end
	xmlFile:delete()
	if not ok then 
		debugPrint("[check %s]: ignoring some groups in mission vehicles file",fnam)
	end
	return ok
end
function BetterContracts:loadExtraMissionVehicles(xmlFilename, baseDir)
	-- modVehicles[] has been ckecked, contains only valid mods
	local xmlFile = XMLFile.load("loadExtraMissionVehicles", xmlFilename)
	if xmlFile == nil then return false end
	local fname = Utils.getFilenameFromPath(xmlFilename)
	debugPrint("%s loadExtraVehicles(%s)", self.name, xmlFilename)
	local mgr = g_missionManager
	local overwriteStd = Utils.getNoNil(xmlFile:getBool("missionVehicles#overwrite"), false)
	if overwriteStd then 
	   g_missionManager.missionVehicles = {}
	end
	-- load field sizes (userDefined.xml)
	local fkey = "missionVehicles.fieldSize" 
	if xmlFile:hasProperty(fkey) then  
		AbstractFieldMission.FIELD_SIZE_MEDIUM =
		 xmlFile:getFloat(fkey.."#medium")
		AbstractFieldMission.FIELD_SIZE_LARGE = 
		 xmlFile:getFloat(fkey.."#large")
	end

	local hasRequiredMods = #self.modVehicles > 0 

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
						if self.modVehicles[index] then
							dir = g_modNameToDirectory[self.modVehicles[index]]
						else
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
		type = mt.name
		if type == "supplyTransportMission" then continue end
		local smallOnly = type == "deadwoodMission" or type == "destructibleRockMission"
		for _,f in ipairs({"small","medium","large"}) do
			if smallOnly and f ~= "small" then continue end
			if g_missionManager.missionVehicles[type] == nil or 
			 	g_missionManager.missionVehicles[type][f] == nil or 
				#g_missionManager.missionVehicles[type][f] == 0 then
					Logging.warning("[%s] No missionVehicles for %s missions on %s fields",
					self.name, type, f)
					ok = false
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
	-- Server only
	if loadState ~= VehicleLoadingState.OK then return end 

    for _, vehicle in ipairs(vehicles) do
        -- if we spawned "leased" materials:
        if vehicle.typeName == "pallet" or vehicle.typeName == "bigBag" then
            vehicle.addWearAmount = function() end
            vehicle.setOperatingTime = function() end
        end
    end
end
function finishedPreparing(self)
	-- appended to AbstractMission:finishedPreparing() / Server only

	if self.isServer and self.spawnedVehicles then
	-- inform client about spawned leasing vehicles
		LeasedVecsEvent.sendEvent(self, self.vehicles)
	end
end
function BetterContracts:getVehicles(m)
	-- tag all spawned vecs for mission m. Called on update
	--debugPrint("**getVehicles, m: %s %s", m, m.getTitle and m:getTitle() or "nil")

	if self.vehicleTags[m] == nil or self.vehicleTags[m].vecIds == nil then
		return false  -- cannot yet resolve vehicles
	end
	local spGame = type(self.vehicleTags[m].vecIds[1]) == "table" 
	-- in single player, vecIds[] already contain the vehicle objects

	local txt = self.vehicleTags[m].txt
	for _, id in ipairs(self.vehicleTags[m].vecIds) do
		local vec = spGame and id or NetworkUtil.getObject(id)
		if vec ~= nil then  
			if self.missionVecs[vec] == nil then
				vec.activeMissionId = m.activeMissionId
				self.missionVecs[vec] = txt
				local item = g_storeManager:getItemByXMLFilename(vec.configFileName)
				debugPrint("** vehicle tagged: %s",vec:getFullName())
			end
		else 
			return false -- there is still 1 vehicle not yet synced from server
		end
	end
	return true
end
function BetterContracts:vehicleTag(m, vehicleIds)
	-- save mission txt to append to leased vehicle names. Client only
	local fieldNo = m.field and  m.field:getName() or ""
	local txt =  string.format(" (%.8s %s)", m:getTitle(), fieldNo)

	self.vehicleTags[m] = {
		txt = txt,
		vecIds = vehicleIds,
		tagged = false
		} 
	table.insert(self.tagMissions, m) -- we need to tag vecs for this mission
end
function missionManagerLoadFromXMLFile(self,xmlFilename)
	-- appended to MissionManager:loadFromXMLFile()
	-- MP only: 
	assert(g_currentMission:getIsServer(),
		"BetterContracts.missionManagerLoadFromXMLFile should run on Server only")
	local isMP = g_currentMission.missionDynamicInfo.isMultiplayer
	debugPrint("* missionManagerLoadFromXMLFile, MP %s", isMP)

	for _, m in ipairs(self.missions) do
		-- append possible vehicle groups to mission
		m.groups = getGroups(m)

		-- we inform clients about active missions with leased vecs
		if m.activeMissionId ~= nil and m.spawnedVehicles then 
		debugPrint("** %s %s activeId %s",m:getTitle(), m.field and m:getField():getName(), m.activeMissionId or "")
			m.sendLeasedVecs = true
			if not isMP then checkMissionVecs(m)		
			end
		end
	end
	return xmlFilename ~= nil
end
function checkMissionVecs(m, connection)
	-- if mission vecs loaded, send to client, otherwise delay
	if #m.vehicles > 0 then  
		LeasedVecsEvent.sendEvent(m, m.vehicles, connection)
		m.sendLeasedVecs = nil
	else
		table.insert(BetterContracts.activeMissions, m)
		BetterContracts.frameCounter = 0
	end
end

FSBaseMission.onConnectionFinishedLoading = Utils.appendedFunction(
	FSBaseMission.onConnectionFinishedLoading, 
function(self, connection)
	-- a new client connected. Inform them about active mission vehicles
	for _, m in ipairs(g_missionManager.missions) do
		if m.sendLeasedVecs then 
			debugPrint("* onConnectionFinishedLoading %s %s, vehicles: %d", m:getTitle(), 
				m.field:getName(), #m.vehicles)
			checkMissionVecs(m, connection)		
		end
	end
	-- debug for server mission groups:
	--if BetterContracts.config.debug then BetterContracts:printMissionVehicles()
	--end
end)

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
	BetterContracts.vehicleTags[self] = nil
end
function onVehicleReset(self, oldv, newv)
	-- appended to AbstractMission:onVehicleReset
	if oldv.activeMissionId ~= self.activeMissionId then return end

	debugPrint("* onVehicleReset %s %s", oldv:getFullName(), newv:getFullName())
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
MissionStartEvent.writeStream = Utils.prependedFunction(MissionStartEvent.writeStream, 
function(self, streamId, connection)
	if connection:getIsServer() then
		streamWriteUInt8(streamId, self.vehicleGroup or 0)
	end	
end)

MissionStartEvent.readStream = Utils.prependedFunction(MissionStartEvent.readStream, 
function(self, streamId, connection)
	if not connection:getIsServer() then
		self.vehicleGroup = streamReadUInt8(streamId)
	end	
end)

-- augment mission start event sent from server to client accepting the mission
MissionStartEvent.run = Utils.prependedFunction(MissionStartEvent.run, 
function(self, connection)
	local bc = BetterContracts
	local fromServer = connection:getIsServer()
	if bc.config.debug then
		if fromServer then
			print(string.format("[BC] MissionStartEvent.run on client, startState %s", 
				self.startState))
		else
			print(string.format("[BC] MissionStartEvent.run on server%s %s", 
			self.spawnVehicles and ", leased group" or "", self.vehicleGroup or "" ))
		end
	end
	if self.spawnVehicles and not fromServer then 
		-- set the mission vehicles on the server
		local m = self.mission
		local ix = self.vehicleGroup
		m.vehiclesToLoad = m.groups[ix].vehicles
		m.vehicleGroupIdentifier = m.groups[ix].identifier
	end
end)

function getGroups(m)
	-- get all possible vehicle groups for mission m
	local typeName = m:getMissionTypeName()
	local size = m:getVehicleSize()
	local variant = m:getVehicleVariant()
	local typeGroups = g_missionManager.missionVehicles[typeName]
	debugPrint("* getGroups: %s %s %s",typeName,size,variant)
	local groups = {}
	if typeGroups ~= nil then
		local sizeGroups = typeGroups[size]
		if sizeGroups ~= nil then 
			groups = table.ifilter(sizeGroups, function(e)
			return variant == nil and true or e.variant == variant
			end)
		end
	end
	for i=1,#groups do
		debugPrint("%2d %s ..",groups[i].identifier, groups[i].vehicles[1].filename)
	end
	return groups
end
function abstractInit(self)
	-- overwrites AbstractMission:init() to save all possible vec groups
	self.groups = getGroups(self)
	local g = table.getRandomElement(self.groups)
	Assert.isNotNil(g, "** Error: no vehicle group found for %s",self.title)
	self.vehiclesToLoad = g.vehicles
	self.vehicleGroupIdentifier = g.identifier
	return true
end

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
	self.groups = getGroups(m)
	self.vehiclesList:reloadData()
	self.originalGroup = 0
	for i= 1,#self.groups do
		debugPrint("** id %s", self.groups[i].identifier)
		if self.groups[i].identifier == m.vehicleGroupIdentifier then 
			self.vehiclesList:setSelectedItem(1, i)
			self.originalGroup = i
		end
	end
	assert(self.originalGroup > 0,
		"BetterContracts: Non-matching vehicle groups.")
	self.vehicleTemplate:unlinkElement()
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
	--debugPrint("**onListSelectionChanged: index %d", index)
	local grp = self.groups[index]
	if grp ~= nil then
		self:updateVehicleBox(grp.vehicles)
	end
end
function VehicleSelect:updateVehicleBox(vecs)
	local frCon = BetterContracts.frCon
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
--[[
function VehicleSelect:onOpen()
	debugPrint("** VehicleSelect:onOpen()")
end]]
function VehicleSelect:vehicleClickButton(button)
	-- callback from our Vec selection dialog. Esc doesn't start mission
	debugPrint("** VehicleSelect: Click %s", button.id)
	local ix = self.originalGroup
	if button.id == "yesButton" then
		_, ix = self.vehiclesList:getSelectedPath()
		-- start leasing mission:
		startLeasing(BetterContracts.frCon, self.mission, ix)
	end
	self:close()
end
function VehicleSelect:update(dt)
	-- update vehicle marquee
	InGameMenuContractsFrame.updateMarqueeAnimation(self,dt)
end