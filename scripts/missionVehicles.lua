--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:     Enhance ingame contracts menu.
-- Author:      Royal-Modding / Mmtrx
-- Changelog:
--  v1.0.0.0    28.10.2024  1st port to FS25
--=======================================================================================================

---------------------- mission vehicle loading functions --------------------------------------------
function BetterContracts.loadMissionVehicles(missionManager, superFunc, xmlFilename, baseDirectory)
	-- this could be called multiple times: by mods, dlcs
	local self = BetterContracts
	debugPrint("* %s loadMissionVehicles(%s, %s)", self.name, xmlFilename, baseDirectory)
	debugPrint("* loadedVehicles %s, overwrittenVehicles %s", self.loadedVehicles, self.overwrittenVehicles)
	if self.overwrittenVehicles then return true end -- do not add further vecs to a userdefined setup
	
	if superFunc(missionManager, xmlFilename, baseDirectory) then 
		if self.loadedVehicles then return true end -- we already loaded our extra missionVehicles

		if self.debug then
			self:checkExtraMissionVehicles(self.directory .. "missionVehicles/baseGame.xml")
		end
		self:loadExtraMissionVehicles(self.directory .. "missionVehicles/baseGame.xml")
		self.loadedVehicles = true

		-- determine userdef location
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
		if found and self:checkExtraMissionVehicles(userdef) then 
			-- check for other mod:
			if g_modIsLoaded.FS22_DynamicMissionVehicles then
				Logging.warning("[%s] Mod FS22_DynamicMissionVehicles detected. Make sure '%s' contains 'variant definitions'",self.name, userdef)
				local dmv = FS22_DynamicMissionVehicles.DynamicMissionVehicles
				dmv.variants = {}
				dmv:loadVariants(userdef)
			end
			debugPrint("[%s] loading user mission vehicles from '%s'.",self.name, userdef)
			self.overwrittenVehicles = self:loadExtraMissionVehicles(userdef)
		end    
		return true
	end
	return false
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

function BetterContracts:printMissionVehicles()
	-- print vehicle groups for each missiontype/fieldsize 
	print("* MissionManager has loaded following vehicle groups *")
	local type 
	local sep = string.rep("-", 34)
	for _,mt in ipairs(g_missionManager.missionTypes) do
		if mt.category == MissionManager.CATEGORY_FIELD or 
		   mt.category == MissionManager.CATEGORY_GRASS_FIELD then
			type = mt.name
			for _,f in ipairs({"small","medium","large"}) do
				print(sep ..string.format(" %s %s: ", type, f) ..sep)
				if g_missionManager.missionVehicles[type] and 
				 	g_missionManager.missionVehicles[type][f] then 
				 	local lastVariant = nil
				 	local groups = table.copyIndex(g_missionManager.missionVehicles[type][f])
				 	if groups[1].variant ~= nil then 
				 		-- sort groups by variant
				 		table.sort(groups, function(a, b)
				 			return a.variant < b.variant
				 			end)
				 		lastVariant = "yes"
				 	end
					for i, group in ipairs(groups) do
						if lastVariant and lastVariant ~= group.variant then  
							lastVariant = group.variant
							print(string.format("variant %s:", lastVariant))
						end
						printGroup(group)
					end
				end
			end
		end
	end
end

function printGroup(group)
	-- print mission vehicles in group
	local vecs = group.vehicles 
	local vtext = ""
	local row = {}
	for _,vec in ipairs(vecs) do
		local item = g_storeManager:getItemByXMLFilename(vec.filename)
		vtext = string.format("%s %s", g_brandManager:getBrandByIndex(item.brandIndex).title, item.name )
		for configName, configValue in pairs(vec.configurations) do
			vtext = vtext .. string.format(" %s:%d", configName, configValue)
		end
		table.insert(row, vtext)
	end
	print(string.format("%2d: %s", group.identifier, table.concat(row, ", ")))
end

function BetterContracts:checkExtraMissionVehicles(xmlFilename)
	-- check if all vehicles specified can be loaded
	local modName, modDirectory, filename, ignore 
	local check = true 
	local xmlFile = loadXMLFile("loadExtraMissionVehicles", xmlFilename)
	local i = 0
	while true do
		local baseKey = string.format("missionVehicles.mission(%d)", i)
		if hasXMLProperty(xmlFile, baseKey) then
			local missionType = getXMLString(xmlFile, baseKey .. "#type") or ""
			--self:loadExtraMissionVehicles_groups(xmlFile, baseKey, missionType, modDirectory)
			local j = 0
			while true do
				local groupKey = string.format("%s.group(%d)", baseKey, j)
				if hasXMLProperty(xmlFile, groupKey) then
					--self:loadExtraMissionVehicles_vehicles(xmlFile, groupKey, modDirectory)
					local k = 0 
					while true do
						local vehicleKey = string.format("%s.vehicle(%d)", groupKey, k)
						if hasXMLProperty(xmlFile, vehicleKey) then
							local baseDirectory = nil
							local vfile = getXMLString(xmlFile, vehicleKey .. "#filename") or "missingFilename"
							ignore = false
							modName = getXMLString(xmlFile, vehicleKey .. "#requiredMod")
							if getXMLBool(xmlFile, vehicleKey .. "#isMod") then
								baseDirectory = modDirectory
							elseif modName~= nil then 
								if g_modIsLoaded[modName]then
									baseDirectory = g_modNameToDirectory[modName]
								else
									Logging.warning("[%s] required Mod %s not found, ignoring mission vehicle %s",
										self.name, modName, vfile)
									ignore = true
									check = false
								end 
							end
							if not ignore then
								filename = Utils.getFilename(vfile, baseDirectory)
								-- try to load from store item
								if g_storeManager.xmlFilenameToItem[string.lower(filename)] == nil then
									Logging.warning("**[%s] - could not get store item for '%s'",self.name,filename)
									check = false 
								end 
							end
						else
							break
						end
						k = k +1
					end    
				else
					break
				end
				j = j +1
			end
		else
			break
		end
		i = i + 1
	end
	delete(xmlFile)
	if not check then 
		Logging.warning("[%s] ignoring mission vehicles file '%s'",self.name,xmlFilename)
	end
	return check
end

function BetterContracts:loadExtraMissionVehicles(xmlFilename)
	local xmlFile = loadXMLFile("loadExtraMissionVehicles", xmlFilename)
	local modDirectory = nil
	local requiredMod = getXMLString(xmlFile, "missionVehicles#requiredMod")
	local hasRequiredMod = false
	if requiredMod ~= nil and g_modIsLoaded[requiredMod] then
		modDirectory = g_modNameToDirectory[requiredMod]
		hasRequiredMod = true
	end
	local overwriteStd = Utils.getNoNil(getXMLBool(xmlFile, "missionVehicles#overwrite"), false)
	if overwriteStd then 
	   g_missionManager.missionVehicles = {}
	end
	if hasRequiredMod or requiredMod == nil then
		local index = 0
		while true do
			local baseKey = string.format("missionVehicles.mission(%d)", index)
			if hasXMLProperty(xmlFile, baseKey) then
				local missionType = getXMLString(xmlFile, baseKey .. "#type") or ""
				if missionType ~= "" then
					if g_missionManager.missionVehicles[missionType] == nil then
						g_missionManager.missionVehicles[missionType] = {}
						g_missionManager.missionVehicles[missionType].small = {}
						g_missionManager.missionVehicles[missionType].medium = {}
						g_missionManager.missionVehicles[missionType].large = {}
					end
					self:loadExtraMissionVehicles_groups(xmlFile, baseKey, missionType, modDirectory)
				end
			else
				break
			end
			index = index + 1
		end
	end
	delete(xmlFile)
	return overwriteStd
end

function BetterContracts:loadExtraMissionVehicles_groups(xmlFile, baseKey, missionType, modDirectory)
	local index = 0
	while true do
		local groupKey = string.format("%s.group(%d)", baseKey, index)
		if hasXMLProperty(xmlFile, groupKey) then
			local group = {}
			local fieldSize = getXMLString(xmlFile, groupKey .. "#fieldSize") or "missingFieldSize"
			group.variant = getXMLString(xmlFile, groupKey .. "#variant")
			group.rewardScale = getXMLFloat(xmlFile, groupKey .. "#rewardScale") or 1
			if g_missionManager.missionVehicles[missionType][fieldSize] == nil then 
				g_missionManager.missionVehicles[missionType][fieldSize] = {}
			end 
			group.identifier = #g_missionManager.missionVehicles[missionType][fieldSize] + 1
			group.vehicles = self:loadExtraMissionVehicles_vehicles(xmlFile, groupKey, modDirectory)
			table.insert(g_missionManager.missionVehicles[missionType][fieldSize], group)
		else
			break
		end
		index = index + 1
	end
end

function BetterContracts:loadExtraMissionVehicles_vehicles(xmlFile, groupKey, modDirectory)
	local index = 0
	local vehicles = {}
	local modName, ignore 
	while true do
		local vehicleKey = string.format("%s.vehicle(%d)", groupKey, index)
		if hasXMLProperty(xmlFile, vehicleKey) then
			local vehicle = {}
			local baseDirectory = nil
			local vfile = getXMLString(xmlFile, vehicleKey .. "#filename") or "missingFilename"
			ignore = false
			modName = getXMLString(xmlFile, vehicleKey .. "#requiredMod")
			if getXMLBool(xmlFile, vehicleKey .. "#isMod") then
				baseDirectory = modDirectory
			elseif modName~= nil then 
				if g_modIsLoaded[modName]then
					baseDirectory = g_modNameToDirectory[modName]
				else
					Logging.warning("[%s] required Mod %s not found, ignoring mission vehicle %s",
						self.name, modName, vfile)
					ignore = true
				end 
			end
			if not ignore then
				vehicle.filename = Utils.getFilename(vfile, baseDirectory)
				vehicle.configurations = self:loadExtraMissionVehicles_configurations(xmlFile, vehicleKey)
				table.insert(vehicles, vehicle)
			end
		else
			break
		end
		index = index + 1
	end
	return vehicles
end

function BetterContracts:loadExtraMissionVehicles_configurations(xmlFile, vehicleKey)
	local index = 0
	local configurations = {}
	while true do
		local configurationKey = string.format("%s.configuration(%d)", vehicleKey, index)
		if hasXMLProperty(xmlFile, configurationKey) then
			local ignore = false
			local name = getXMLString(xmlFile, configurationKey .. "#name") or "missingName"
			local id = getXMLInt(xmlFile, configurationKey .. "#id") or 1
			local modName = getXMLString(xmlFile, configurationKey .. "#requiredMod")
			if not g_configurationManager:getConfigurationDescByName(name) then 
				Logging.warning("[%s] configuration %s not found, ignored",
						self.name, name)
			elseif modName~= nil and not g_modIsLoaded[modName] then
				Logging.warning("[%s] required Mod %s not found, ignoring '%s' configuration",
						self.name, modName, name)
			else
				configurations[name] = id
			end
		else
			break
		end
		index = index + 1
	end
	return configurations
end

---------------------- mission vehicle enhancement functions --------------------------------------------
function BetterContracts:vehicleTag(m, vehicle)
	-- save txt to append to vehicle name
	local txt =  string.format(" (%.6s %s)", self.jobText[m.type.name], m.field.fieldId)
	self.missionVecs[vehicle] = txt 
end
function loadNextVehicle(self, super, vehicle, vehicleLoadState, arguments)
	-- overwritten AbstractFieldMission:loadNextVehicleCallback() to allow spawning pallets
	if vehicle == nil then return end 

	self.lastVehicleIndexToLoad = arguments[1]
	self.vehicleLoadWaitFrameCounter = 2
	vehicle.activeMissionId = self.activeMissionId
	if vehicle.addWearAmount ~= nil then 
		vehicle:addWearAmount(math.random() * 0.3 + 0.1)
	end
	vehicle:setOperatingTime(3600000 * (math.random() * 40 + 30))
	table.insert(self.vehicles, vehicle)

	-- save mission type / field for vehicle name
	BetterContracts:vehicleTag(self, vehicle)
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
	-- appended to AbstractFieldMission:onVehicleReset
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
function missionManagerLoadFromXMLFile(self,xmlFilename)
	-- appended to MissionManager:loadFromXMLFile()
	local bc = BetterContracts
	if #self.missions > 0 then
		for _, vehicle in pairs(g_currentMission.vehicles) do
			if vehicle.activeMissionId ~= nil then
				local mission = self:getMissionForActiveMissionId(vehicle.activeMissionId)
				if mission ~= nil and mission.vehicles ~= nil then
					bc:vehicleTag(mission, vehicle)
				end
			end
		end
	end
	return xmlFilename ~= nil
end
