--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:		Enhance ingame contracts menu.
-- Author:		Royal-Modding / Mmtrx
-- Changelog:
--  v1.0.0.0    28.10.2024  1st port to FS25 (not used yet)
--=======================================================================================================

-------------------- mission analysis functions ---------------------------------------------------
warnText = {
	"**[%s] - contract '%s field %s' has no vehicles",
	"**[%s] - could not get store item for '%s'",
	"**[%s]:getFromVehicle() - could not get workingWidth for '%s'",
	"**[%s]:getFromVehicle() could not find appropriate vehicle in mission %s on field %s",
	"[%s]:addMission(): problem with vehicles for contract '%s field %s'."
}
warnings = { {},{},{},{},{}, }
function BetterContracts:getDimensions(field, verbose)
	local numd = getNumOfChildren(field.fieldDimensions)
	local dim, x0, x1, x2, z0, z1, z2, widthX, widthZ, heightX, heightZ, widthLength, heightLength, area
	local xmin, xmax, zmin, zmax
	local dimensions = {
		minX = 999999,
		maxX = -999999,
		minZ = 999999,
		maxZ = -999999
	}
	for i = 1, numd do
		dim = getChildAt(field.fieldDimensions, i - 1)
		x1, _, z1 = getWorldTranslation(dim)
		x0, _, z0 = getWorldTranslation(getChildAt(dim, 0))
		x2, _, z2 = getWorldTranslation(getChildAt(dim, 1))

		xmin, xmax = math.min(x0, x1, x2), math.max(x0, x1, x2)
		zmin, zmax = math.min(z0, z1, z2), math.max(z0, z1, z2)
		if xmin < dimensions.minX then
			dimensions.minX = xmin
		end
		if xmax > dimensions.maxX then
			dimensions.maxX = xmax
		end
		if zmin < dimensions.minZ then
			dimensions.minZ = zmin
		end
		if zmax > dimensions.maxZ then
			dimensions.maxZ = zmax
		end

		_, _, widthX, widthZ, heightX, heightZ = MathUtil.getXZWidthAndHeight(x0, z0, x1, z1, x2, z2)
		widthLength = MathUtil.vector2Length(widthX, widthZ)
		heightLength = MathUtil.vector2Length(heightX, heightZ)
		_, area, _ = MathUtil.crossProduct(widthX, 0, widthZ, heightX, 0, heightZ)
		if verbose then
			print(string.format("(%.1f, %.1f) (%.1f, %.1f) (%.1f, %.1f) width: %.2f, height: %.2f, area: %.2f", x0, z0, x1, z1, x2, z2, widthLength, heightLength, math.abs(area)))
		end
	end
	dimensions.width = dimensions.maxX - dimensions.minX
	dimensions.height = dimensions.maxZ - dimensions.minZ
	return dimensions
end
function BetterContracts:isHarvester(vcat)
	-- check if vcat store category fits harvest missions
	local x, _ = string.find(self.catHarvest, string.upper(vcat))
	return x ~= nil
end
function BetterContracts:isMower(vcat)
	-- check if vcat store category fits grass missions
	local x, _ = string.find("MOWERS MOWERVEHICLES", string.upper(vcat))
	return x ~= nil
end
function BetterContracts:isSpreader(vcat)
	-- check if vcat store category fits fertilize/spray/seed missions
	local x, _ = string.find(self.catSpread, string.lower(vcat))
	return x ~= nil
end
function BetterContracts:isSimple(vcat)
	-- check if vcat store category fits simple missions
	local x, _ = string.find(self.catSimple, string.upper(vcat))
	return x ~= nil
end
function BetterContracts:isFruitPlanter(ft)
	-- check if ft is in fruittype categoy PLANTER
	local list = g_fruitTypeManager.categoryToFruitTypes[g_fruitTypeManager.categories.PLANTER]
	return TableUtility.contains(list, ft)
end
function BetterContracts:warning(id, p1, p2)
	-- display the same warning only once
	p2 = p2 or ""
	local count = warnings[id][p1..p2] or 0
	if count >= 1 then return end 
	Logging.warning(warnText[id],self.name,p1,p2)
	warnings[id][p1..p2] = count +1
end
function BetterContracts:getFromVehicle(cat, m)
	-- return workwidth, speedLimit for the appropriate mission vehicle:
	-- cat 1: harvest - get data from harvest mission vehicle (Todo: grass mission)
	-- cat 2: spread  - get spread / spray data from fertilize/ sow/ spray mission vehicle
	-- cat 3: simple  - get data from plow / cultivator/ weeder vehicle
	--print(string.format("-- getFrom Vehicle(cat, m) started: %d, %s",cat, m))
	local vehicles = {}
	local vec, con, vtype, wwidth, speed
	local spr = "n/a" -- sprayer name

	if m.vehiclesToLoad == nil or #m.vehiclesToLoad == 0 then 
		self:warning(1, m.type.name, m.field.fieldId)
		return false 
	end
	if cat == SC.BALING then wwidth = 0 end -- init for search for biggest wwidth
	for _, v in ipairs(m.vehiclesToLoad) do	-- main loop over vehicles to load
		vec = g_storeManager.xmlFilenameToItem[string.lower(v.filename)]
		con = v.configurations
		if vec == nil then
			self:warning(2, v.filename)
			return false 
		end
		StoreItemUtil.loadSpecsFromXML(vec)
		vtype = vec.categoryName
		spr = string.sub(vec.xmlFilename, 15)

	--- if grass mission, scan for mower with largest workwidth
		if cat == SC.BALING then
			if self:isMower(vtype) and tonumber(vec.specs.workingWidth) > wwidth then
				wwidth = tonumber(vec.specs.workingWidth)
				speed = vec.specs.speedLimit
			end
		elseif cat == SC.SPREAD and vtype == "SLURRYTANKS" 
			and vec.functions[1] == g_i18n:getText("function_slurrySpreaderWithoutTool")
			then  -- skip this, it's a slurry barrel w/o spreader

		elseif cat == SC.HARVEST and vtype == "BEETVEHICLES" then  
			if string.find(vec.name, "Rexor 6300 Platinum") then 
				wwidth, speed = 2.8, 10.
				break 
			end
			-- else skip this, it's a beet harvester that needs a header

		elseif cat == SC.HARVEST and self:isHarvester(vtype) 
				or cat == SC.SPREAD and self:isSpreader(vtype) 
				or cat == SC.SIMPLE and self:isSimple(vtype) then
			speed = vec.specs.speedLimit
			wwidth = vec.specs.workingWidth
			if wwidth == nil then
				if vec.specs.workingWidthConfig ~= nil then 
					wwidth = Vehicle.getSpecValueWorkingWidthConfig(vec, nil, con, nil, true)
				end
				if wwidth == nil then
					if string.find(vec.name, "Ventor 4150") then wwidth = 3.3 end
				end
				if wwidth == nil then
					self:warning(3, spr)
					--DebugUtil.printTableRecursively(vec," ",0,0)
				end
			end
			break
		end
	end
	-- if no spreader / sprayer in a spreadmission (e.g. a manure vehicle offered)
	-- or custom (harvest) vehicle --> use default speed, wwidth
	if wwidth == nil then
		speed, wwidth = 0, 0
		if cat ~= SC.SPREAD and self.debug then
			self:warning(4, m.id, m.field.fieldId)
		end
	end
	--debugPrint("%s %s - speed %.1f, width %.1f", vtype, spr,speed,wwidth)
	return true, tonumber(wwidth), tonumber(speed), string.lower(vtype), spr
end
function BetterContracts:spreadMission(m, wid, hei, vWorkwidth, vSpeed)
	-- analyze and estimate time/ usage for a fertilize / spray / sow mission
	local nlanes, workL, vtype, vname
	local fer, liq = self.ft[FillType.FERTILIZER].title, self.ft[FillType.LIQUIDFERTILIZER].title
	local u = {SPEEDLIMS = {}, WORKWIDTH = {}}
	local mtyp = m.type.typeId
	local workT, dura, usage, cost, price, ftext = {}, {}, {}, {}, {}, {}
	local maxj = 2 -- if mission vehicle found, use its specs as 3rd option
	local typ = 1 -- index to self.SPEEDLIMS / WORKWIDTH

	-- assume fertilize mission:
	ftext[1], ftext[2] = fer, liq
	for j = 1, 2 do
		usage[j], price[j] = self.sprUse[j], self.prices[j]
		u.SPEEDLIMS[j] = self.SPEEDLIMS[j]
		u.WORKWIDTH[j] = self.WORKWIDTH[j]
	end
	if mtyp == self.mtype.SOW then
		ftext[1] = self.ft[FillType.SEEDS].title
		price[1] = self.prices[SC.SEEDS]
		usage[1] = g_fruitTypeManager:getFruitTypeByIndex(m.fruitType).seedUsagePerSqm
		maxj = 1
		typ = 3
		price[2], usage[2], ftext[2] = price[1], usage[1], ftext[1]
	elseif mtyp == self.mtype.SPRAY then
		ftext[1] = self.ft[FillType.HERBICIDE].title
		price[1] = self.prices[SC.HERBICIDE]
		usage[1] = self.sprUse[SC.HERBICIDE]
		maxj = 1
		typ = 2 -- default sprayer (Hardi Mega1200)
		price[2], usage[2], ftext[2] = price[1], usage[1], ftext[1]
	elseif self.limeMission and mtyp == self.mtype.LIME then
		ftext[1] = self.ft[FillType.LIME].title
		price[1] = self.prices[SC.LIME]
		usage[1] = self.sprUse[SC.LIME]
		maxj = 1
		typ = 10 -- default lime sprayer (Bredal K165)
		price[2], usage[2], ftext[2] = price[1], usage[1], ftext[1]
	end
	-- set specs from mission vehicle
	if vWorkwidth ~= nil and vWorkwidth > 0 then
		maxj = maxj + 1
		u.WORKWIDTH[maxj], u.SPEEDLIMS[maxj] = vWorkwidth, vSpeed
	end
	u.SPEEDLIMS[1] = self.SPEEDLIMS[typ]
	u.WORKWIDTH[1] = self.WORKWIDTH[typ]
	--[[
	calculate worktime and usage (fertilizer, seeds, herbicide) cost for 2 or 3 diff vehicles:
	- fertilize mission
		1: default spreader, 2: default sprayer, 3: mission vehicle (if exists)
	- spray/ lime mission 
		1: default sprayer, 2: mission vehicle (if exists)
	- sow mission 
		1: default sower, 2: mission vehicle (if exists). 
		   dura may differ / usage independent from speed/workwidth
	]]
	for j = 1, maxj do
		workT[j], dura[j] = self:estWorktime(wid, hei, u.WORKWIDTH[j], u.SPEEDLIMS[j])
		if j == 3 then -- values from mission vehicle
			if vtype == "fertilizerspreaders" then
				usage[j], price[j] = self.sprUse[1], self.prices[1]
				 -- fertilizer
				ftext[3] = fer
			else
				usage[j], price[j] = self.sprUse[2], self.prices[2]
				 -- liquid fertilizer
				ftext[3] = liq
			end
		end
		if mtyp == self.mtype.SOW then
			-- literPerSqm * ha * 10.000
			usage[j] = usage[j] * m.field.fieldArea * 10000
		else
			-- literPerSec * sec
			usage[j] = usage[j] * u.WORKWIDTH[j] * u.SPEEDLIMS[j] * workT[j]
		end
		cost[j] = -usage[j] * price[j] / 1000
		--[[print(string.format("wid/hei %.1f/%.1f, nlanes %d, workL %.1f, workT %.1f",
			wid,hei,math.ceil(wid / u.WORKWIDTH[j]), math.ceil(wid / u.WORKWIDTH[j])*hei +wid,  
			workT[j]))
		]]
	end
	local jbest = 1
	for j = 1, maxj do
		if cost[j] > cost[jbest] then
			jbest = j
		end
	end
	local rew = m:getReward()
	return {
		miss = m,
		ftype = ftext,
		maxj = maxj,
		bestj = jbest,
		width = wid,
		height = hei,
		worktime = dura,
		usage = usage,
		price = price,
		cost = cost,
		profit = rew + cost[jbest],
		permin = (rew + cost[jbest]) / dura[jbest] * 60,
        reward = rew
	}
end
function BetterContracts:estWorktime(wid, hei, wwid, speed)
	-- estimate time to work a rectangle field (wid x hei) with a tool
	-- of working width wwid at given speed
	if wwid == nil or wwid == 0 or speed == nil or speed == 0 then 
		Logging.warning("[%s] estWorktime invalid parms: %.1f, %.1f, %s, %s",
			self.name, wid, hei, wwid, speed)
		printCallstack()
		return nil, 36000
	end 
	local nlanes = math.ceil(wid / wwid) -- how many passes
	local workL = nlanes * hei + wid -- length of working path
	local netT = workL / speed * 3.6 -- net working time in sec
	return netT, netT + nlanes * self.turnTime -- assume 5 sec per u-turn
end


-------------------- improved mission worktime estimate -------------------------------------------
-- Estimate field work from actual mission vehicle working width/speed where possible.
-- Falls back to conservative defaults if a mission vehicle does not expose usable specs.

local BC_WORKTIME_DEFAULTS = {
    fertilizeMission = {width=42.0, speed=15.0, factor=1.15, cat=SC.SPREAD},
    herbicideMission = {width=24.0, speed=12.0, factor=1.15, cat=SC.SPREAD},
    limeMission      = {width=18.0, speed=18.0, factor=1.15, cat=SC.SPREAD},
    sowMission       = {width= 6.0, speed=15.0, factor=1.20, cat=SC.SPREAD},
    plowMission      = {width= 4.9, speed=12.0, factor=1.25, cat=SC.SIMPLE},
    cultivateMission = {width= 6.0, speed=15.0, factor=1.20, cat=SC.SIMPLE},
    weedMission      = {width=12.0, speed=15.0, factor=1.20, cat=SC.SIMPLE},
    mowbaleMission   = {width= 9.0, speed=20.0, factor=1.30, cat=SC.BALING},
    harvestMission   = {width= 9.0, speed=10.0, factor=1.30, cat=SC.HARVEST},
    chaffMission     = {width= 9.0, speed=10.0, factor=1.35, cat=SC.HARVEST},
    fruitCollectMission = {width=3.5, speed=10.0, factor=1.35, cat=SC.HARVEST},
}

function BetterContracts:getMissionFillTypeName(m)
    if m == nil or self.ft == nil then return nil end

    local ix = m.fillTypeIndex or m.fillType
    if ix ~= nil and self.ft[ix] ~= nil then
        return string.upper(self.ft[ix].name or "")
    end
    return nil
end

function BetterContracts:getGenericVehicleWorkData(m)
    -- Generic fallback for newer/special FS25 machines whose store category is not
    -- covered by getFromVehicle() yet (e.g. some vegetable harvesters).
    if m == nil or m.vehiclesToLoad == nil then return nil, nil, nil end

    local bestWidth, bestSpeed, bestName = nil, nil, nil

    for _, v in ipairs(m.vehiclesToLoad) do
        if v ~= nil and v.filename ~= nil then
            local item = g_storeManager.xmlFilenameToItem[string.lower(v.filename)]
            if item ~= nil then
                StoreItemUtil.loadSpecsFromXML(item)

                local width = item.specs and tonumber(item.specs.workingWidth) or nil
                if width == nil and item.specs and item.specs.workingWidthConfig ~= nil then
                    width = Vehicle.getSpecValueWorkingWidthConfig(item, nil, v.configurations, nil, true)
                    width = tonumber(width)
                end

                local speed = item.specs and tonumber(item.specs.speedLimit) or nil

                if width ~= nil and width > 0 and (bestWidth == nil or width > bestWidth) then
                    bestWidth = width
                    bestSpeed = speed
                    bestName = item.name or v.filename
                end
            end
        end
    end

    return bestWidth, bestSpeed, bestName
end

function BetterContracts:getMissionWorkDefaults(m, typeName)
    local d = BC_WORKTIME_DEFAULTS[typeName]
    if d == nil then return nil end

    local result = {
        width = d.width,
        speed = d.speed,
        factor = d.factor,
        cat = d.cat,
    }

    if typeName == "harvestMission" or typeName == "fruitCollectMission" then
        local fruitName = self:getMissionFillTypeName(m)

        if fruitName == "SPINACH" then
            -- OXBO MKB-4TR fallback. Actual mission vehicle specs still take precedence.
            result.width = 3.5
            result.speed = 10.0
            result.factor = 1.35
        elseif fruitName == "GREENBEAN" or fruitName == "GREEN_BEAN" then
            result.width = 3.3
            result.speed = 10.0
            result.factor = 1.35
        elseif fruitName == "PEA" then
            result.width = 3.8
            result.speed = 10.0
            result.factor = 1.35
        elseif fruitName == "POTATO" then
            result.width = 3.3
            result.speed = 10.0
            result.factor = 1.40
        elseif fruitName == "SUGARBEET" or fruitName == "SUGAR_BEET" then
            result.width = 3.0
            result.speed = 10.0
            result.factor = 1.40
        end
    end

    return result
end

function BetterContracts:estimateMissionWorktime(m, size)
    local fallback = (tonumber(size) or 1) * 600
    if m == nil or size == nil or size <= 0 or m.type == nil then return fallback end

    local typeName = m.type.name
    local d = self:getMissionWorkDefaults(m, typeName)
    if d == nil then return fallback end

    local width, speed = d.width, d.speed
    local source = "default"

    -- Prefer a generic scan of the actual selected mission vehicles. This also
    -- catches newer/special FS25 machines whose store category BC does not know yet.
    local genericWidth, genericSpeed, genericName = self:getGenericVehicleWorkData(m)
    if genericWidth ~= nil and genericWidth > 0 then
        width = genericWidth
        if genericSpeed ~= nil and genericSpeed > 0 then speed = genericSpeed end
        source = genericName or "missionVehicleGeneric"
    else
        -- Fall back to BC's existing category-aware lookup, which contains a few
        -- special cases for base-game machines.
        local ok, vehicleWidth, vehicleSpeed, _, vehicleName = self:getFromVehicle(d.cat, m)
        if ok and vehicleWidth ~= nil and vehicleWidth > 0 then
            width = vehicleWidth
            if vehicleSpeed ~= nil and vehicleSpeed > 0 then speed = vehicleSpeed end
            source = vehicleName or "missionVehicle"
        end
    end

    width = tonumber(width)
    speed = tonumber(speed)
    if width == nil or speed == nil or width <= 0 or speed <= 0 then return fallback end

    -- ha/h = working width [m] * speed [km/h] / 10
    local hectaresPerHour = width * speed / 10
    if hectaresPerHour <= 0 then return fallback end

    local seconds = size / hectaresPerHour * 3600 * d.factor

    -- Avoid pathological values from malformed mod vehicle specs.
    if seconds ~= seconds or seconds <= 0 or seconds > 86400 then return fallback end

    debugPrint("[%s] worktime %s field %s: %.2f ha, %.2f m, %.1f km/h, factor %.2f => %.1f min (%s)",
        self.name,
        typeName,
        m.field and m.field.fieldId or "?",
        size,
        width,
        speed,
        d.factor,
        seconds / 60,
        tostring(source))

    return seconds
end

-------------------- bale fermenting functions ---------------------------------------------------
BC_Action = {
	BC_CUT = 1,
	BC_FERMENT = 2,
}
function BaleActivatable:getIsActivatable()
	if self.bale:getCanInteract() then 
		if self.bale:getCanBeOpened() then 
			self.activateText = g_i18n:getText("action_cutBale")
			self.action = BC_Action.BC_CUT
			return true
		end
		if BetterContracts.config.ferment and self.bale:getIsFermenting() then
			self.activateText = g_i18n:getText("bc_actionFerment")
			self.action = BC_Action.BC_FERMENT
			return true
		end
	end
	return false
end
function BaleActivatable:run()
	-- called by ActivatableObjectsSystem:onActivateObjectInput()
	if self.action == BC_Action.BC_FERMENT then
		-- ferment bale immediately
		if g_server ~= nil then
			self.bale:onFermentationEnd()
		else
			g_client:getServerConnection():sendEvent(BaleFermentEvent.new(self.bale))
		end
		return
	end
	if g_server ~= nil then
		self.bale:open()
	else
		g_client:getServerConnection():sendEvent(BaleOpenEvent.new(self.bale))
	end
end

BaleFermentEvent = {}
local BaleFermentEvent_mt = Class(BaleFermentEvent, Event)
InitEventClass(BaleFermentEvent, "BaleFermentEvent")

function BaleFermentEvent.emptyNew()
	local self = Event.new(BaleFermentEvent_mt)
	return self
end
function BaleFermentEvent.new(bale)
	local self = BaleFermentEvent.emptyNew()
	self.bale = bale
	return self
end
function BaleFermentEvent:readStream(streamId, connection)
	if not connection:getIsServer() then
		self.bale = NetworkUtil.readNodeObject(streamId)
	end
	self:run(connection)
end
function BaleFermentEvent:writeStream(streamId, connection)
	if connection:getIsServer() then
		NetworkUtil.writeNodeObject(streamId, self.bale)
	end
end
function BaleFermentEvent:run(connection)
	if not connection:getIsServer() then
		self.bale:onFermentationEnd()
	end
end

-------------------- allow packed bale as mission bale --------------------------------------------
function loadBaleAttributes(self, superf, xmlFile)
	-- overwrites Bale:loadBaleAttributesFromXML(xmlFile)
	if self:isa(PackedBale) then 
		debugPrint("** setting mission bale for object %d", self.nodeId)
		local x,_,z = getWorldTranslation(self.nodeId)
		if g_missionManager:getMissionAtWorldPosition(x,z) ~= nil then
			self:setIsMissionBale(true)
		end
	end
	return superf(self, xmlFile)
end

-------------------- let Göweil create mission bale -----------------------------------------------
function BetterContracts:createBale(superFunc, baleFillType, fillLevel, ...)
	-- overwrites createBale() in "balerStationary" spec
	local ret = superFunc(self, baleFillType, fillLevel, ...)
	if ret then 
    	local spec = self.spec_baler
		local bale = spec.bales[#spec.bales]
		if bale.baleObject ~= nil then 
			local x,_,z = getWorldTranslation(self.rootNode)
			local m = g_missionManager:getMissionAtWorldPosition(x,z)
			if m ~= nil and m.type.name == "mow_bale" then
				bale.baleObject:setIsMissionBale(true)
			end
		end
	end
	return ret
end
