--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:     Enhance ingame contracts menu.
-- Author:      Mmtrx
-- Copyright:	Mmtrx
-- License:		GNU GPL v3.0
-- Changelog:
--  v1.0.0.0    28.10.2024  1st port to FS25
--  v1.0.1.0    10.12.2024  some details, sort list
--  v1.0.1.1    20.12.2024  fix details button, enlarge contract details list
--  v1.1.0.0    08.01.2025  UI settings page, discount mode
--  v1.1.1.0    03.02.2025  fix npc jobs for cancelled mission (#17), compat lime, boost
--							stay on NEW contracts list when accepting a contract
--							only show on hud active cntr with completion > 0
--  v1.1.1.1    04.02.2025  fix white UI page (#19, #24, #29), fix ContractBoost compat #28
--  v1.1.1.2    05.02.2025  fix server save/load #22, #27, #30.
-- 							compatible with FS25_additionalGameSettings #31, #33, #35
--  v1.1.1.3    14.02.2025  fix generation non-field contracts #47, fix #38 
--							new settings switches: hideMission #44, stayNew, finishField #48
--							Prevent FS25_RefreshContracts
--  v1.1.1.4    22.02.2025  MP fixes: generation non-field contracts #47,
-- 							no progress in fieldwork / deposited liters #40 
--  v1.1.2.0    28.02.2025  extra mission vehicles. Update l10n_pl _cz _fr
--							compat FS25_RefreshContracts #72
--  v1.2.0.0    12.05.2025  repair FS25_Financing #78. Fix click on settings/controls #76.
-- 							add time left for active contracts on hud #63
-- 							add mission info to leased vehicle name #65
--							New: leased vehicle selection dialog
--  v1.2.0.1    18.05.2025  disable warnings for missing mods in missionVehicles\baseGame.xml
--  v1.2.0.2    23.05.2025  count non-field jobs for discount #80
--							adjustable small/med/large field size thresholds #45
--							increase reward/ha for earth fruit types #71
--							remove surplus "progress" text from list #92
--							fix MP vehicle select for vegetable harvest #94
--							remove vehicle warn for supplyTransportMission #98
--  v1.2.0.3    30.05.2025  remove fertilize level on finished harvest missions
--							read NPC field owners from savegame #96
--							compatible patch for KommunalServices
--							details for bale, balewrap missions
--  v1.2.0.4    10.09.2025  farmlandManagerLoadFromXMLFile: don't set npc to nil when 
--							reading farmlands w/o npcIndex #96
--							adjust backgd box for farmland info. Allow max 2 wood transp missions
--							Leased Vehicle Selection: Esc doesn't start contract #107, #113
--							userDefined.xml: fix vehicles for large fertilizing #91, 
--							medium sowing #105
--	v1.3.0.0 	28.09.2025	FIX: leasing when BC is off #129, compat supplyTransport #126,
--								sort menu at 16x10 resolution #128
--							NEW: double progress bars, leased vecs in active contract display
--							details for chaff mission. fruit name for sow/harvest in contr list
--							enable hardMode
--	v1.3.0.1 	18.11.2025	getGroups(): don't repeat vec groups debug print
--							fix penalty bug: was applied even for succcessful missions #142
--							fix hud progress bar, clash with FS25_extendedMissionInfo #136
--							awareness for FS25_AdditionalContracts (possibly fix #146)
--	v1.3.0.2 	29.11.2025	fix mowBaleMIssion #154
--=======================================================================================================
SC = {
	FERTILIZER = 1, -- prices index
	LIQUIDFERT = 2,
	HERBICIDE = 3,
	SEEDS = 4,
	LIME = 5,
	-- my mission cats:
	HARVEST = 1,
	SPREAD = 2,
	SIMPLE = 3,
	BALING = 4,
	TRANSP = 5,
	SUPPLY = 6,
	OTHER = 7,
	-- refresh MP:
	ADMIN = 1,
	FARMMANAGER = 2,
	PLAYER = 3,
	-- hardMode expire:
	OFF = 0,
	DAY = 1,
	MONTH = 2,
	-- Gui farmerBox controls:
	CONTROLS = {
		container = "container",
		mTable = "mTable",
		mToggle = "mToggle",
	},
	-- Gui contractBox controls:
	CONTBOX = {
		"detailsList", "rewardText"
	},
	-- Gui progressBox controls:
	PROGBOX = {
		"bcProgressBars", "prog1", "prog2",
		"progressBarBg", "progressBar1", "progressBar2",
		"bcVehicleTemplate", "vehiclesBox"
	},
	DELIVERMISSION = {
		"harvestMission","mowbaleMission","chaffMission","fruitCollectMission",
		"baleCollectMission",
	},
}
function debugPrint(text, ...)
	if BetterContracts.config and BetterContracts.config.debug then
		Logging.info(text,...)
	end
end
source(Utils.getFilename("RoyalMod.lua", g_currentModDirectory.."scripts/")) 	-- RoyalMod support functions
source(Utils.getFilename("Utility.lua", g_currentModDirectory.."scripts/")) 	-- RoyalMod utility functions
---@class BetterContracts : RoyalMod
BetterContracts = RoyalMod.new(true, true)     --params bool debug, bool sync

gEnv = getmetatable(_G).__index
function addTexts()
	for name, value in pairs(g_i18n.texts) do
		if string.startsWith(name, "global_") then
			gEnv.g_i18n:setText(name:sub(8), value)
		end
	end
end
function checkOtherMods(self)
	local mods = {	
		FS25_ContractBoost = "contractBoost",
		FS25_LimeMission = "limeMission",
		FS25_MowBaleMission = "mowbaleMission",
		FS25_RefreshContracts = "refreshContracts",
		FS25_Financing = "financing",
		--FS25_MaizePlus = "maizePlus",
		FS25_KommunalServices = "kommunal",
		FS25_SupplyTransportContracts = "supply",
		FS25_extendedMissionInfo = "extendedInfo",
		FS25_AdditionalContracts = "additional",
		}
	for mod, switch in pairs(mods) do
		if g_modIsLoaded[mod] then
			debugPrint("[BC] registered %s", mod)
			self[switch] = true
		end
	end
end
function registerXML(self)
	self.baseXmlKey = "BetterContracts"
	self.xmlSchema = XMLSchema.new(self.baseXmlKey)
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#debug")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#ferment")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#forcePlow")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#hideMission")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#stayNew")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#finishField")

	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#lazyNPC")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#discount")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#hard")

	self.xmlSchema:register(XMLValueType.INT, self.baseXmlKey.."#maxActive")
	self.xmlSchema:register(XMLValueType.INT, self.baseXmlKey.."#refreshMP")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#reward")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#rewardMow")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#lease")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#deliver")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#deliverBale")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#fieldCompletion")

	local key = self.baseXmlKey..".lazyNPC"
	self.xmlSchema:register(XMLValueType.BOOL, key.."#harvest")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#plowCultivate")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#sow")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#weed")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#fertilize")

	local key = self.baseXmlKey..".discount"
	self.xmlSchema:register(XMLValueType.FLOAT, key.."#perJob")
	self.xmlSchema:register(XMLValueType.INT,   key.."#maxJobs")

	local key = self.baseXmlKey..".hard"
	self.xmlSchema:register(XMLValueType.FLOAT, key.."#penalty")
	self.xmlSchema:register(XMLValueType.INT,   key.."#leaseJobs")
	self.xmlSchema:register(XMLValueType.INT,   key.."#expire")
	self.xmlSchema:register(XMLValueType.INT,   key.."#hardLimit")

	local key = self.baseXmlKey..".generation"
	self.xmlSchema:register(XMLValueType.INT, 	key.."#interval")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#genGrain")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#genGreen")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#genVegetable")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#genRoot")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#genTree")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#genDead")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#genRock")
end
function readconfig(self)
	if g_currentMission.missionInfo.savegameDirectory == nil then return end
	-- check for config file in current savegame dir
	self.savegameDir = g_currentMission.missionInfo.savegameDirectory .."/"
	self.configFile = self.savegameDir .. self.name..'.xml'
	local xmlFile = XMLFile.loadIfExists("BCconf", self.configFile, self.xmlSchema)
	if xmlFile then
		-- read config parms:
		local key = self.baseXmlKey

		self.config.debug =		xmlFile:getValue(key.."#debug", false)			
		self.config.ferment =	xmlFile:getValue(key.."#ferment", false)			
		self.config.forcePlow =	xmlFile:getValue(key.."#forcePlow", false)			
		self.config.hideMission = xmlFile:getValue(key.."#hideMission", false)	
		self.config.stayNew = xmlFile:getValue(key.."#stayNew", true)	
		self.config.finishField = xmlFile:getValue(key.."#finishField", true)	

		self.config.maxActive = xmlFile:getValue(key.."#maxActive", 3)
		self.config.rewardMultiplier = xmlFile:getValue(key.."#reward", 1.)
		self.config.rewardMultiplierMow = xmlFile:getValue(key.."#rewardMow", 1.)
		self.config.leaseMultiplier = xmlFile:getValue(key.."#lease", 1.)
		self.config.toDeliver = xmlFile:getValue(key.."#deliver", 0.94)
		self.config.toDeliverBale = xmlFile:getValue(key.."#deliverBale", 0.90)
		self.config.fieldCompletion = xmlFile:getValue(key.."#fieldCompletion", 0.95)
		self.config.refreshMP =	xmlFile:getValue(key.."#refreshMP", 2)		
		self.config.lazyNPC = 	xmlFile:getValue(key.."#lazyNPC", false)
		self.config.hardMode = 	xmlFile:getValue(key.."#hard", false)
		self.config.discountMode = xmlFile:getValue(key.."#discount", false)
		if self.config.lazyNPC then
			key = self.baseXmlKey..".lazyNPC"
			self.config.npcHarvest = 	xmlFile:getValue(key.."#harvest", false)			
			self.config.npcPlowCultivate =xmlFile:getValue(key.."#plowCultivate", false)		
			self.config.npcSow = 		xmlFile:getValue(key.."#sow", false)		
			self.config.npcFertilize = 	xmlFile:getValue(key.."#fertilize", false)
			self.config.npcWeed = 		xmlFile:getValue(key.."#weed", false)
		end
		if self.config.discountMode then
			key = self.baseXmlKey..".discount"
			self.config.discPerJob = MathUtil.round(xmlFile:getValue(key.."#perJob", 0.05),2)			
			self.config.discMaxJobs =	xmlFile:getValue(key.."#maxJobs", 5)		
		end
		if self.config.hardMode then
			key = self.baseXmlKey..".hard"
			self.config.hardPenalty = MathUtil.round(xmlFile:getValue(key.."#penalty", 0.1),2)			
			self.config.hardLease =		xmlFile:getValue(key.."#leaseJobs", 2)		
			self.config.hardExpire =	xmlFile:getValue(key.."#expire", SC.MONTH)		
			self.config.hardLimit =		xmlFile:getValue(key.."#hardLimit", -1)		
		end
		key = self.baseXmlKey..".generation"
		self.config.generationInterval = xmlFile:getValue(key.."#interval", 1)
		self.config.genGrain = xmlFile:getValue(key.."#genGrain", true)
		self.config.genRoot = xmlFile:getValue(key.."#genRoot", true)
		self.config.genVegetable = xmlFile:getValue(key.."#genVegetable", true)
		self.config.genGreen = xmlFile:getValue(key.."#genGreen", true)
		self.config.genTree = xmlFile:getValue(key.."#genTree", true)
		self.config.genDead = xmlFile:getValue(key.."#genDead", true)
		self.config.genRock = xmlFile:getValue(key.."#genRock", true)
		xmlFile:delete()
	else
		debugPrint("[%s] config file %s not found, using default settings",self.name,self.configFile)
	end
end
function loadPrices(self)
	local prices = {}
	-- store prices per 1000 l
	local items = {
		{"data/objects/bigbagpallet/fertilizer/bigbagpallet_fertilizer.xml", 1, 1920, "FERTILIZER"},
		{"data/objects/pallets/liquidtank/fertilizertank.xml", 0.5, 1600, "LIQUIDFERTILIZER"},
		{"data/objects/pallets/liquidtank/herbicidetank.xml", 0.5, 1200, "HERBICIDE"},
		{"data/objects/bigbagpallet/seeds/bigbagpallet_seeds.xml", 1, 900,""},
		{"data/objects/bigbagpallet/lime/bigbagpallet_lime.xml", 0.5, 225, "LIME"}
	}
	for _, item in ipairs(items) do
		local storeItem = g_storeManager.xmlFilenameToItem[item[1]]
		local price = item[3]
		if storeItem ~= nil then 
			price = storeItem.price * item[2]
		end
		table.insert(prices, price)
	end
	return prices
end
function hookFunctions(self)
 --[[
	-- adjust NPC activity for missions: 
	Utility.overwrittenFunction(FieldManager, "updateNPCField", NPCHarvest)

	-- tag mission fields in map: 
	Utility.appendedFunction(FieldHotspot, "render", renderIcon)

	Utility.appendedFunction(TransportMission, "writeStream", BetterContracts.writeTransport)
	Utility.appendedFunction(TransportMission, "readStream", BetterContracts.readTransport)
 ]]
 	-- start contract from npc conversation
	Utility.overwrittenFunction(ConversationActionStartSelectedMission,"run",startFromConversation)

	-- hard mode: 
	Utility.overwrittenFunction(AbstractMission,"getFinishedDetails",getFinishedDetails)
	Utility.overwrittenFunction(AbstractMission,"getTotalReward",getTotalReward)
	Utility.overwrittenFunction(InGameMenuContractsFrame, "onButtonCancel", onButtonCancel)
	--g_messageCenter:subscribe(MessageType.DAY_CHANGED, self.onDayChanged, self)
	--g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onHourChanged, self)

	-- to check for max monthly missions
	g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, self.onPeriodChanged, self)

	-- save our settings: 
	Utility.prependedFunction(ItemSystem, "save", saveSavegame)
	-- to allow MOWER / SWATHER on harvest missions:
	Utility.overwrittenFunction(HarvestMission, "new", harvestMissionNew)

	-- to count and save/load # of jobs per farm per NPC
	Utility.appendedFunction(AbstractMission,"finish",finish)
	Utility.appendedFunction(FarmStats,"saveToXMLFile",saveToXML)
	Utility.appendedFunction(FarmStats,"loadFromXMLFile",loadFromXML)
	Utility.appendedFunction(Farm,"writeStream",farmWrite)
	Utility.appendedFunction(Farm,"readStream",farmRead)
	Utility.overwrittenFunction(FarmlandManager, "saveToXMLFile", farmlandManagerSaveToXMLFile)
	Utility.appendedFunction(FarmlandManager, "loadFromXMLFile", farmlandManagerLoadFromXMLFile)
	-- to display discount if farmland selected / on buy dialog
	Utility.appendedFunction(InGameMenuMapUtil, "showContextBox", showContextBox)

	-- to handle disct price on farmland buy
	g_messageCenter:subscribe(MessageType.FARMLAND_OWNER_CHANGED, self.onFarmlandStateChanged, self)

	-- to adjust contracts field compl / reward / vehicle lease values:
	Utility.overwrittenFunction(AbstractFieldMission,"getCompletion",getCompletion)
	Utility.overwrittenFunction(HarvestMission,"getCompletion",harvestCompletion)
	--Utility.overwrittenFunction(BaleMission,"getCompletion",baleCompletion)
	Utility.overwrittenFunction(AbstractFieldMission,"getReward",getReward)
	Utility.overwrittenFunction(AbstractMission,"getVehicleCosts",calcLeaseCost)
	Utility.overwrittenFunction(AbstractMission,"init",abstractInit)

	-- get addtnl mission values from server:
	Utility.appendedFunction(AbstractMission, "writeStream", missionWriteStream)
	Utility.appendedFunction(AbstractMission, "readStream", missionReadStream)
	Utility.appendedFunction(AbstractMission, "writeUpdateStream", missionWriteUpdateStream)
	Utility.appendedFunction(AbstractMission, "readUpdateStream", missionReadUpdateStream)
	Utility.prependedFunction(HarvestMission, "writeStream", harvestWriteStream)
	Utility.prependedFunction(HarvestMission, "readStream", harvestReadStream)
	Utility.appendedFunction(HarvestMission, "onSavegameLoaded", onSavegameLoaded)
	if self.additional then  
		local chaffClass = g_missionManager:getMissionType("chaffMission").classObject
		Utility.prependedFunction(chaffClass, "writeStream", harvestWriteStream)
		Utility.prependedFunction(chaffClass, "readStream", harvestReadStream)
		Utility.appendedFunction(chaffClass, "onSavegameLoaded", onSavegameLoaded)
		Utility.overwrittenFunction(chaffClass,"getDetails",harvestGetDetails)
		local fruitClass = g_missionManager:getMissionType("fruitCollectMission").classObject
		Utility.prependedFunction(fruitClass, "writeStream", harvestWriteStream)
		Utility.prependedFunction(fruitClass, "readStream", harvestReadStream)
		Utility.appendedFunction(fruitClass, "onSavegameLoaded", onSavegameLoaded)
		Utility.overwrittenFunction(fruitClass,"getDetails",harvestGetDetails)
		local baleClass = g_missionManager:getMissionType("baleCollectMission").classObject
		Utility.prependedFunction(baleClass, "writeStream", harvestWriteStream)
		Utility.prependedFunction(baleClass, "readStream", harvestReadStream)
		Utility.appendedFunction(baleClass, "onSavegameLoaded", onSavegameLoaded)
		Utility.overwrittenFunction(baleClass,"getDetails",harvestGetDetails)
		self.chaffClass = chaffClass
		self.fruitClass = fruitClass
		self.baleClass = baleClass

		if g_missionManager:getMissionType("universalMission") ~= nil then
			-- only for AddtionalContracts version from 1.0.0.4 and later
			local acTypes = gEnv.FS25_AdditionalContracts.g_additionalContractTypes
			local bulkClass = acTypes:getTyp("supplyDeliveryBulkMission")
			local fieldClass = acTypes:getTyp("supplyFieldGoodsMission")
			for _,cl in ipairs({bulkClass, fieldClass}) do
				Utility.prependedFunction(cl, "writeStream", harvestWriteStream)
				Utility.prependedFunction(cl, "readStream", harvestReadStream)
				Utility.appendedFunction(cl, "onSavegameLoaded", onSavegameLoaded)
				Utility.overwrittenFunction(cl,"getDetails",univGetDetails)
			end
		end
	end
	-- flexible mission limit: 
	Utility.overwrittenFunction(MissionManager, "hasFarmReachedMissionLimit", hasFarmReachedMissionLimit)
	-- possibly generate more than 1 mission : 
	Utility.overwrittenFunction(MissionManager, "generateMission", generateMission)
	-- set estimated work time for Field Mission: 
	Utility.appendedFunction(MissionManager, "addMission", addMission)
	-- set more details:
	Utility.overwrittenFunction(AbstractFieldMission,"getLocation",getLocation)
	Utility.overwrittenFunction(AbstractFieldMission,"getDetails",fieldGetDetails)
	Utility.overwrittenFunction(HarvestMission,"getDetails",harvestGetDetails)
	Utility.overwrittenFunction(BaleWrapMission,"getDetails",wrapGetDetails)
	Utility.overwrittenFunction(BaleMission,"getDetails",baleGetDetails)

	-- reset spray level when finished, force plowing after root crop harvest mission:
	Utility.overwrittenFunction(HarvestMission, "getFieldFinishTask", getFieldFinishTask)

	-- functions for ingame menu contracts frame:
	Utility.appendedFunction(InGameMenuContractsFrame, "onFrameOpen", onFrameOpen)
	Utility.prependedFunction(InGameMenuContractsFrame, "onFrameClose", onFrameClose)
	Utility.appendedFunction(InGameMenuContractsFrame, "setButtonsForState", setButtonsForState)
	Utility.appendedFunction(InGameMenuContractsFrame, "populateCellForItemInSection", populateCell)
	Utility.overwrittenFunction(InGameMenuContractsFrame, "sortList", sortList)
	Utility.overwrittenFunction(InGameMenuContractsFrame, "startContract", startContract)
	Utility.appendedFunction(InGameMenuContractsFrame, "updateFarmersBox", updateFarmersBox)
	Utility.appendedFunction(InGameMenuContractsFrame, "updateDetailContents", updateDetailContents)
	-- to stay on NEW contr list when mission accepted:
	Utility.overwrittenFunction(InGameMenuContractsFrame, "onMissionStarted", onMissionStarted)
	
	-- who can clear / generate contracts
	Utility.appendedFunction(InGameMenu, "updateButtonsPanel", updateButtonsPanel)

	-- to hide 0% missions from hud
	Utility.overwrittenFunction(AbstractMission,"update",missionUpdate)
	-- allow mission work to continue, after mission finished
	Utility.overwrittenFunction(AbstractFieldMission,"getIsWorkAllowed",getIsWorkAllowed)

	-- to load own mission vehicles:
	Utility.overwrittenFunction(MissionManager, "loadVehicleGroups", BetterContracts.loadMissionVehicles)
	-- allow pallets to spawn as mission vehicle:
	Utility.prependedFunction(AbstractMission, "onSpawnedVehicle", onSpawnedVehicle)
	-- save name tags for mission vehicle:
	Utility.appendedFunction(AbstractMission, "finishedPreparing", finishedPreparing)
	Utility.appendedFunction(MissionManager, "loadFromXMLFile", missionManagerLoadFromXMLFile)

	-- to display mission vehicle names:
	Utility.prependedFunction(AbstractFieldMission, "removeAccess", removeAccess)
	Utility.appendedFunction(AbstractMission, "onVehicleReset", onVehicleReset)
	for name, typeDef in pairs(g_vehicleTypeManager.types) do
		-- rename mission vehicle: 
		if typeDef ~= nil and not TableUtility.contains({"horse","pallet","bigBag","locomotive"}, name) then
			SpecializationUtil.registerOverwrittenFunction(typeDef, "getName", vehicleGetName)
		end
	end
end
function BetterContracts:initialize()
	debugPrint("[%s] initialize(): %s", self.name,self.initialized)
	if self.initialized ~= nil then return end -- run only once
	self.initialized = false
	self.config = {
		debug = true, 				-- debug mode
		ferment = false, 			-- allow insta-fermenting wrapped bales by player
		forcePlow = false, 			-- force plow after root crop harvest
		hideMission = false, 		-- hide missions not begun from hud
		stayNew = true, 			-- don't switch to ACTIVE list when contr accepted
		finishField = true, 		-- allow 100% field completion after contr finish
		maxActive = 3, 				-- max active contracts
		rewardMultiplier = 1., 		-- general reward multiplier
		rewardMultiplierMow = 1.,  	-- mow reward multiplier
		leaseMultiplier = 1.,		-- general lease cost multiplier
		toDeliver = 0.94,			-- HarvestMission.SUCCESS_FACTOR
		toDeliverBale = 0.90,		-- BaleMission.FILL_SUCCESS_FACTOR
		fieldCompletion = 0.95,		-- AbstractMission.SUCCESS_FACTOR
		fieldSize = 0.5,			-- threshold from "small" to "med" size field
		generationInterval = 1, 	-- MissionManager.MISSION_GENERATION_INTERVAL
			genGrain = true,  		-- grain harvest missions allowed
			genRoot = true,  		-- 
			genVegetable = true,  	-- 
			genGreen = true,  		-- 
			genTree = true,  		-- 
			genDead = true,  		-- 
			genRock = true,  		-- 
		refreshMP = SC.ADMIN, 		-- necessary permission to refresh contract list (MP)
		lazyNPC = false, 			-- adjust NPC field work activity
			npcHarvest = false,
			npcPlowCultivate = false,
			npcSow = false,	
			npcFertilize = false,
			npcWeed = false,
		discountMode = false, 		-- get field price discount for successfull missions
			discPerJob = 0.05,
			discMaxJobs = 5,
		hardMode = false, 			-- penalty for canceled missions
			hardPenalty = 0.1, 		-- % of total reward for missin cancel
			hardLease =	2, 			-- # of jobs to allow borrowing equipment
			hardExpire = SC.MONTH, 	-- or "day"
			hardLimit = -1, 		-- max jobs to accept per farm and month
	}
	self.NPCAllowWork = false 		-- npc should not work before noon of last 2 days in month
	self.missionVecs = {} 			-- holds names of active mission vehicles
	self.vehicleTags = {} 			-- connects newly started mission with vehicle ids
	self.activeMissions = {} 		-- active missions loaded from savegame, for server only
	self.tagMissions = {} 			-- active missions to be tagged, for client only

	g_missionManager.missionMapNumChannels = 6
	self.missionUpdTimeout = 15000
	self.missionUpdTimer = 0 	-- will also update on frame open of contracts page
	self.turnTime = 5.0 		-- estimated seconds per turn at end of each lane
	self.events = {}
	--  Amazon ZA-TS3200,   Hardi Mega, TerraC6F, Lemken Az9,  mission,grain potat Titan18       
	--  default:spreader,   sprayer,    sower,    planter,     empty,  harv, harv, plow, mow,lime
	self.SPEEDLIMS = {15,   12,         15,        15,         0,      10,   10,   12,   20, 18}
	self.WORKWIDTH = {42,   24,          6,         6,         0,       9,   3.3,  4.9,   9, 18} 
	self.catHarvest = "BEETHARVESTING BEETVEHICLES CORNHEADERS COTTONVEHICLES CUTTERS POTATOHARVESTING POTATOVEHICLES SUGARCANEHARVESTING SUGARCANEVEHICLES"
	self.catSpread = "fertilizerspreaders seeders planters sprayers sprayervehicles slurrytanks manurespreaders"
	self.catSimple = "CULTIVATORS DISCHARROWS PLOWS POWERHARROWS SUBSOILERS WEEDERS ROLLERS"
	self.isOn = true  	-- start with our add-ons
	self.numCont = 0 	-- # of contracts in our tables
	self.numHidden = 0 	-- # of hidden (filtered) contracts 
	self.my = {} 		-- will hold my gui element adresses
	self.sort = 0 		-- sorted status: 1 cat, 2 prof, 3 permin
	self.lastSort = 0 	-- last sorted status
	self.buttons = {
		{"sortcat", g_i18n:getText("SC_sortCat")}, -- {button id, help text}
		{"sortrev", g_i18n:getText("SC_sortRev")},
		{"sortnpc", g_i18n:getText("SC_sortNpc")},
		{"sortprof", g_i18n:getText("SC_sortProf")},
		{"sortpmin", g_i18n:getText("SC_sortpMin")}
	}
	self.npcProb = {
		harvest = 1.0,
		plowCultivate = 0.5,
		sow = 0.5,
		fertilize = 0.9,
		weed = 0.9,
		lime = 0.9
	}
	self.genContracts = {}  	-- avoid generation if genContracts[type] is false
	local types = g_missionManager.missionTypes
	for i = 1, #types do
		self.genContracts[g_missionManager:getMissionTypeById(i).name] = true
	end
	self.canHarvest = {			-- allow generation if canHarvest[variant] is true
		GRAIN = true,
		ROOTCROP = true,
		VEGETABLES = true,
		GREEN = true,
	}  		
	checkOtherMods(self)
	registerXML(self) 			-- register xml: self.xmlSchema
	hookFunctions(self) 		-- appends / overwrites to basegame functions
	addTexts()  				-- raise i18n texts to global
end
function BetterContracts:allowHarvest()
	-- check if fruit on current field is exluded from harvest contracts
	local variantToType = {
		MAIZE = "GRAIN",
		SUGARBEET = "ROOTCROP",
		POTATO = "ROOTCROP",
		COTTON = "GRAIN",
		SUGARCANE = "GRAIN",
		PEA = "GREEN",
		SPINACH = "GREEN",
		GREENBEAN = "GREEN",
		VEGETABLES ="VEGETABLES",
		GRAIN = "GRAIN"
	}
	local field = g_fieldManager:getFieldForMission()
	if field == nil then 
		debugPrint("* getFieldForMission() returns nil *") 
		return false
	end
	local fruitTypeIndex = field:getFieldState().fruitTypeIndex
	local variant = HarvestMission.getVehicleVariant({fruitTypeIndex= fruitTypeIndex})
	local type = variantToType[variant]
	return self.canHarvest[type]  or false
end
function generateMission(self, superf)
	-- overwritten, to not finish after 1st mission generated
	local bc = BetterContracts
	local missionType = self.missionTypes[self.currentMissionTypeIndex]
	local increment = true 
	--debugPrint("* try %s", missionType.name)
	if missionType == nil then
	  self:finishMissionGeneration()
	  return
	end
	if bc.genContracts[missionType.name] and
			(missionType.name ~= "harvestMission" or bc:allowHarvest()) and
			missionType.classObject.tryGenerateMission ~= nil then
		mission = missionType.classObject.tryGenerateMission()
		if mission ~= nil then
		 self:registerMission(mission, missionType)
		 increment = false
		end 
   end
   if increment then 
	 self.currentMissionTypeIndex = self.currentMissionTypeIndex +1
	 if self.currentMissionTypeIndex > #self.missionTypes then
		self.currentMissionTypeIndex = 1
	 end
	 if self.currentMissionTypeIndex == self.startMissionTypeIndex then
		self:finishMissionGeneration()
	 end
   end
end
function onSavegameLoaded(self)
	-- appended to HarvestMission:onSavegameLoaded()
	-- add selling station fruit price to harvest mission. Really needed?
	self.info.price = BetterContracts:getFilltypePrice(self)
end
function BetterContracts:getFilltypePrice(m)
	-- get price for harvest/ mow-bale missions
	if  m.sellingStation == nil and m.tryToResolveSellingStation then
		m:tryToResolveSellingStation()
	end
	if m.sellingStation == nil then
		-- can happen when mission loaded from savegame xml. Selling stations are 
		-- only added after "savegameLoaded"
		-- or: called for a universalMission w/o sellingStation
		--Logging.warning("[%s]:addMission(): contract '%s %s on field %s' has no sellingStation.", 
		--	self.name, m.title, self.ft[m.fillTypeIndex].title, m.field:getName())
		return 0
	end
	-- check for Maize+ (or other unknown) filltype
	local fillType = m.fillTypeIndex
	if m.sellingStation.fillTypePrices[fillType] ~= nil then
		return m.sellingStation:getEffectiveFillTypePrice(fillType)
	end
	if m.sellingStation.fillTypePrices[FillType.SILAGE] then
		return m.sellingStation:getEffectiveFillTypePrice(FillType.SILAGE)
	end
	Logging.warning("[%s]:addMission(): sellingStation %s has no price for fillType %s.", 
		self.name, m.sellingStation:getName(), self.ft[m.fillType].title)
	return 0
end
function BetterContracts:calcProfit(m, successFactor)
	-- calculate addtl income as value of kept harvest
	local keep = math.floor(m.expectedLiters *(1 - successFactor))
	local price = self:getFilltypePrice(m)
	return keep, price, keep * price
end
function addMission(self, mission)
	-- appended to MissionManager:addMission(mission)
	local bc = BetterContracts
	local info =  mission.info 					-- store our additional info
	info.profit = 0
	info.usage = 0
	info.worktime = 0
	info.perMin = 0
	local typeName = mission.type.name
	if mission.field ~= nil then
		--debugPrint("** add %s on field %s", mission.type.name, mission.field:getName())
		local size = mission.field.getAreaHa and mission.field:getAreaHa() or 1
		info.worktime = size * 600  	-- (sec) 10 min/ha, TODO: make better estimate

		-- consumables cost estimate enableFieldworkToolFillItems
		if not (g_currentMission.contractBoostSettings and 
		 g_currentMission.contractBoostSettings.enableFieldworkToolFillItems) then
			if mission.type.name == "fertilizeMission" then
				info.usage = size * bc.sprUse[SC.FERTILIZER] *36000
				info.profit = -info.usage * bc.prices[SC.FERTILIZER] /1000 
			elseif mission.type.name == "herbicideMission" then
				info.usage = size * bc.sprUse[SC.HERBICIDE] *36000
				info.profit = -info.usage * bc.prices[SC.HERBICIDE] /1000
			elseif mission.type.name == "limeMission" then
				info.usage = size * bc.sprUse[SC.LIME] *36000
				info.profit = -info.usage * bc.prices[SC.LIME] /1000
			elseif mission.type.name == "sowMission" then
				info.usage = size *g_fruitTypeManager:getFruitTypeByIndex(mission.fruitTypeIndex).seedUsagePerSqm *10000
				info.profit = -info.usage * bc.prices[SC.SEEDS] /1000
			end
		end
		if table.hasElement(SC.DELIVERMISSION, typeName) then
			if mission.expectedLiters == nil then
				Logging.warning("[%s]:addMission(): contract '%s %s on field %s' has no expectedLiters.", 
					bc.name, mission.type.name, bc.ft[mission.fillType].title, mission.field:getName())
				mission.expectedLiters = 0 
			end 
			if mission.expectedLiters == 0 then  
				mission.expectedLiters = mission:getMaxCutLiters()
			end
			local factor = HarvestMission.SUCCESS_FACTOR
			if typeName=="chaffMission" then 
				factor = bc.chaffClass.data.ownTable.SUCCESS_FACTOR
			elseif typeName=="fruitCollectMission" then
				factor = bc.fruitClass.data.ownTable.SUCCESS_FACTOR
			elseif typeName=="baleCollectMission" then
				factor = bc.baleClass.data.ownTable.SUCCESS_FACTOR
			end
			info.keep, info.price, info.profit = bc:calcProfit(mission, factor)
			info.deliver = math.ceil(mission.expectedLiters - info.keep) 	--must be delivered
		end  	
		info.perMin = (mission:getReward() + info.profit) /info.worktime *60

	elseif typeName == "universalMission" then  -- mission w/o a field
		if mission.expectedLiters ~= nil then 
			-- supplyDeliveryBulkMission: add deliver. keep, profit are 0
			info.keep, info.price, info.profit = bc:calcProfit(mission, 1)
			info.deliver = math.ceil(mission.expectedLiters)

		elseif mission.numFinished ~= nil then 
			-- SupplyFieldGoodsMission: add num pallets

		end
	end
end
function getLocation(self, superf)
	--overwrites AbstractFieldMission:getLocation()
	local bc = BetterContracts
	if not bc.isOn then return superf(self) end

	if self.field ~= nil then
		local fieldId = self.field:getName()
		-- overwrite "contract" with fruittype to harvest
		local txt = self.title
		if self.type.name == "harvestMission" then
			txt = string.format(g_i18n:getText("bc_harvest"), bc.ft[self.fillTypeIndex].title)
		--if m.type.name == "chaffMission" then 
		--	txt = string.format(g_i18n:getText("bc_chaff"), bc.ft[m.orgFillType].title)
		elseif self.type.name == "sowMission" then
			local ft = g_fruitTypeManager.fruitTypeIndexToFillType[self.fruitTypeIndex]
			txt = string.format(g_i18n:getText("bc_sow"), ft.title)
		end
		return string.format("F. %s - %s",fieldId, txt)
	else
		
	end
end
function AbstractMission:getLocation()
	-- to put some text in non-field missions
	local bc = BetterContracts
	if not bc.isOn then return "" end

	if self.type.name == "universalMission" then 
		return string.format("%s %s", self.fillTypeIndex and bc.ft[self.fillTypeIndex].title
			or "", self.data.jobTypName)
	end
	return ""
end
function fieldGetDetails(self, superf)
	--overwrites AbstractFieldMission:getDetails()
	local list = superf(self)
	-- add our values to show in contract details list
	if not BetterContracts.isOn then  
		return list
	end
	-- insert following for both new and active missions
	table.insert(list, {
		title = g_i18n:getText("SC_worktim"),
		value = g_i18n:formatMinutes(self.info.worktime /60)
	})
	table.insert(list, {
		title = g_i18n:getText("SC_profpmin"),
		value = g_i18n:formatMoney(self.info.perMin)
	})
	if self.info.usage > 0 then
		table.insert(list, {
			title = g_i18n:getText("SC_usage"),
			value = g_i18n:formatVolume(self.info.usage)
		})
		table.insert(list, {
			title = g_i18n:getText("SC_cost"),
			value = g_i18n:formatMoney(self.info.profit)
		})
	end
	-- field percentage only for active missions
	if self.status == MissionStatus.RUNNING and 
		self:getMissionTypeName() ~= BaleWrapMission.NAME then
		table.insert(list, {
			["title"] = g_i18n:getText("SC_worked"),
			["value"] = string.format("%.1f%%", self.fieldPercentageDone * 100)
		})
	end
	return list
end
function harvestGetDetails(self, superf)
	--overwrites HarvestMission:getDetails(), also chaffMission, fruitCollectMission

	local list = superf(self)
	if not BetterContracts.isOn then  
		return list
	end
	-- add our values to show in contract details list
	local price = BetterContracts:getFilltypePrice(self)
	local deliver = self.expectedLiters - self.info.keep
	local eta = {}

	if self.status == MissionStatus.RUNNING then
		local depo = 0 		-- just as protection
		if self.depositedLiters then depo = self.depositedLiters end
		depo = MathUtil.round(depo / 100) * 100
		-- don't show negative togos:
		local togo = math.max(MathUtil.round((self.expectedLiters -self.info.keep -depo)/100)*100, 0)
		eta = {
			["title"] = g_i18n:getText("SC_delivered"),
			["value"] = g_i18n:formatVolume(depo)
		}
		table.insert(list, eta)
		eta = {
			["title"] = g_i18n:getText("SC_togo"),
			["value"] = g_i18n:formatVolume(togo)
		}
		table.insert(list, eta)
	else  -- status NEW ----------------------------------------
		local eta = {
			["title"] = g_i18n:getText("SC_deliver"),
			["value"] = g_i18n:formatVolume(MathUtil.round(deliver/100) *100)
		}
		table.insert(list, eta)
		eta = {
			["title"] = g_i18n:getText("SC_keep"),
			["value"] = g_i18n:formatVolume(MathUtil.round(self.info.keep/100) *100)
		}
		table.insert(list, eta)
		eta = {
			["title"] = g_i18n:getText("SC_price"),
			["value"] = g_i18n:formatMoney(price*1000)
		}
		table.insert(list, eta)
	end

	eta = {
		["title"] = g_i18n:getText("SC_profit"),
		["value"] = g_i18n:formatMoney(price*self.info.keep)
	}
	table.insert(list, eta)

	return list
end
function univGetDetails(self, superf)
	--overwrites SupplyFieldGoodsMission:getDetails,SupplyDeliveryBulkMission:getDetails 
	local list = superf(self)
	if not BetterContracts.isOn then  
		return list
	end
	local isBulk = self.jobTypName == "*"..g_i18n:getText("ai_jobTitleDeliver")
	local price = BetterContracts:getFilltypePrice(self)
	local deliver = self.expectedLiters
	local eta = {}

	if self.status == MissionStatus.RUNNING then
	 if isBulk then
	 	-- add delivered / togo
		local depo = 0 		-- just as protection
		if self.depositedLiters then depo = self.depositedLiters end
		depo = MathUtil.round(depo / 100) * 100
		-- don't show negative togos:
		local togo = math.max(MathUtil.round((self.expectedLiters - depo)/100)*100, 0)
		eta = {
			["title"] = g_i18n:getText("SC_delivered"),
			["value"] = g_i18n:formatVolume(depo)
		}
		table.insert(list, eta)
		eta = {
			["title"] = g_i18n:getText("SC_togo"),
			["value"] = g_i18n:formatVolume(togo)
		}
		table.insert(list, eta)
	 else
	 	-- add number items delivered / togo
	 	table.insert(list, {
	 		title = g_i18n:getText("SC_delivered"), 
	 		value = self.numFinished
	 	})
	 	table.insert(list, {
	 		title = g_i18n:getText("SC_togo"), 
	 		value = self.numObjects - self.numFinished
	 	})
	 end
	end
	--[[ maybe calc profit if goods to deliver are bought
	eta = {
		["title"] = g_i18n:getText("SC_profit"),
		["value"] = g_i18n:formatMoney(price*self.info.keep)
	}
	table.insert(list, eta)
	]]
	return list
end
function wrapGetDetails(self, superf)
	--overwrites BaleWrapMission:getDetails()
	local list = superf(self)
	if not BetterContracts.isOn then  
		return list
	end
	-- add our values to show in contract details list
	if self.status == MissionStatus.RUNNING then
		local numWrapped = 0
		for _, bale in ipairs(self.bales) do
			numWrapped = numWrapped + bale.wrappingState
		end
		table.insert(list, {
			["title"] = g_i18n:getText("ui_loading_finished"):sub(1,-2),
			["value"] = g_i18n:formatNumber(numWrapped)
		})
		table.insert(list, {
			["title"] = g_i18n:getText("SC_togo"),
			["value"] = g_i18n:formatNumber(self.numOfBales - numWrapped)
		})
	end
	return list
end
function baleGetDetails(self, superf)
	--overwrites BaleWrapMission:getDetails()
	local list = superf(self)
	if not BetterContracts.isOn or
	 #self.bales <= 0 then  
		return list
	end
	-- add our values to show in contract details list
	if self.status == MissionStatus.RUNNING then
		if self.expectedBales == nil then  
			self.expectedBales = self.spawnedLiters/ self.bales[1]:getFillLevel()
		end
		local numBaled = #self.bales
		table.insert(list, {
			["title"] = g_i18n:getText("bc_balesTotal"),
			["value"] = g_i18n:formatNumber(self.expectedBales,1)
		})
		table.insert(list, {
			["title"] = g_i18n:getText("bc_balesDone"),
			["value"] = g_i18n:formatNumber(numBaled)
		})
		table.insert(list, {
			["title"] = g_i18n:getText("SC_togo"),
			["value"] = g_i18n:formatNumber(self.expectedBales - numBaled)
		})
	end
	return list
end

function BetterContracts:onSetMissionInfo(missionInfo, missionDynamicInfo)
	PlowMission.REWARD_PER_HA = 2900 	-- tweak plow reward (#137)

	self:updateGeneration()
end
function BetterContracts:onPostLoadMap(mapNode, mapFile)
	-- handle our config and optional settings
	if g_server ~= nil then
		readconfig(self)
		local txt = string.format("%s read config: maxActive %d",self.name, self.config.maxActive)
		if self.config.lazyNPC then txt = txt..", lazyNPC" end
		if self.config.hardMode then txt = txt..", hardMode" end
		if self.config.discountMode then txt = txt..", discountMode" end
		debugPrint(txt)
	end
	--addConsoleCommand("bcPrint","Print detail stats for all available missions.","consoleCommandPrint",self)
	addConsoleCommand("bcMissions","Print stats for other clients active missions.","bcMissions",self)
	addConsoleCommand("bcPrintVehicles","Print all available vehicle groups for mission types.",
		"printMissionVehicles",self,"missionType; size")
	addConsoleCommand("bcMission", "Force generating a new mission for given field", 
			"consoleGenerateMission", g_missionManager,"farmlandId; missionType")
	addConsoleCommand("bcLoadVehicles", "Load a mission vehicle group", "consoleLoadVehicleSet", 
			g_missionManager, "missionType; size; groupIndex")
	-- init Harvest SUCCESS_FACTORs (std is harv = .93, bale = .9, abstract = .95)
	HarvestMission.SUCCESS_FACTOR = self.config.toDeliver
	BaleMission.FILL_SUCCESS_FACTOR = self.config.toDeliverBale 

	-- init mission generation settings
	BetterContracts:updateGenerationSettings()

	-- initialize constants depending on game manager instances
	self.isMultiplayer = g_currentMission.missionDynamicInfo.isMultiplayer
	self.ft = g_fillTypeManager.fillTypes
	self.prices = loadPrices()
	self.sprUse = {
		g_sprayTypeManager.sprayTypes[SprayType.FERTILIZER].litersPerSecond,
		g_sprayTypeManager.sprayTypes[SprayType.LIQUIDFERTILIZER].litersPerSecond,
		g_sprayTypeManager.sprayTypes[SprayType.HERBICIDE].litersPerSecond,
		0, -- seeds are measured per sqm, not per second
		g_sprayTypeManager.sprayTypes[SprayType.LIME].litersPerSecond
	}
	self.mtype = {
		FERTILIZE = g_missionManager:getMissionType("fertilizeMission").typeId,
		SOW = g_missionManager:getMissionType("sowMission").typeId,
		SPRAY = g_missionManager:getMissionType("HERBICIDEMISSION").typeId,
	}
	if self.limeMission then 
		self.mtype.LIME = g_missionManager:getMissionType("limeMission").typeId
	end
	self.gameMenu = g_inGameMenu
	self.frCon = self.gameMenu.pageContracts
	self.frMap = self.gameMenu.pageMapOverview
	self.frSet = self.gameMenu.pageSettings
	--self.frMap.ingameMap.onClickMapCallback = self.frMap.onClickMap
	--self.frMap.buttonBuyFarmland.onClickCallback = onClickBuyFarmland

	initGui(self) 			-- setup my gui additions
	self.initialized = true
end
function BetterContracts:onStartMission()
	-- set up fruit specific rewards/ha for harvest:
	local data = g_missionManager:getMissionTypeDataByName(HarvestMission.NAME)
	data.rewardPerFruitHa = {
		[FruitType.POTATO] = 		3200,
		[FruitType.SUGARBEET] = 	3200,
		[FruitType.RICE] = 			3600,
		[FruitType.RICELONGGRAIN] = 3600,

		[FruitType.BEETROOT] = 		3400,
		[FruitType.CARROT] = 		3400,
		[FruitType.PARSNIP] = 		3400,
		[FruitType.GREENBEAN] = 	3400,
		[FruitType.PEA] = 			3400,
		[FruitType.SPINACH] = 		3400,
	}
	-- check mission vehicles
	self:validateMissionVehicles()

	-- Reduce # of active supplyTransport missions:
	if self.supply then  
		local data = g_missionManager:getMissionTypeDataByName("supplyTransportMission")
		debugPrint("[BC] reducing maxNumInstances for SupplyTransport contracts from %s to 2", 
			data and data.maxNumInstances or "data nil")
		if data then data.maxNumInstances = 2 end
	end
	-- patch for bug in KommunalServices:
	if self.kommunal then  
		self.genContracts.kommunalMission = true
		local data = g_missionManager:getMissionTypeDataByName("kommunalMission")
		data.maxNumInstances = 2
	end
	-- reduce maxNum for non-field missions, ExtendedMissionInfo sets all to 8:
	if self.extendedInfo then  
		for _,name in ipairs({"treeTransportMission","deadwoodMission","destructibleRockMission"}) do
			local data = g_missionManager:getMissionTypeDataByName(name)
			debugPrint("** %s num Instances is %d, max set to 2", name, data.numInstances)
			data.maxNumInstances = 2
		end
	end
end
function BetterContracts:onWriteStream(streamId)
	-- write settings to a client when it joins
	for _, setting in ipairs(self.settingsMgr.settings) do 
		setting:writeStream(streamId)
	end
end
function BetterContracts:onReadStream(streamId)
	-- client reads our config settings when it joins
	for _, setting in ipairs(self.settingsMgr.settings) do 
		setting:readStream(streamId)
	end
end
function BetterContracts:onUpdate(dt)
	if self.transportMission and g_server == nil then 
		updateTransportTimes(dt)
	end 
	if self.frameCounter then self.frameCounter = self.frameCounter +1 end

	-- on Server: wait for vehicles loaded for active missions
	if g_currentMission:getIsServer() and #self.activeMissions > 0 then  
		if self.frameCounter and self.frameCounter > 60 then 
			for i = #self.activeMissions,1,-1 do 
				local m = self.activeMissions[i]
				if #m.vehicles > 0 then 
					LeasedVecsEvent.sendEvent(m, m.vehicles, connection)
					m.sendLeasedVecs = nil
					table.remove(self.activeMissions, i)
				end
			end
			if #self.activeMissions == 0 then 
				-- we have sent all active mission vecs
				self.frameCounter = nil
			else
				-- try again in about 1 sec
				self.frameCounter = 0
			end
		end
	end
	-- try to resolve leased vehicle object ids
	if g_currentMission:getIsClient() and #self.tagMissions > 0 then  
		for i = #self.tagMissions,1,-1 do 
			if self:getVehicles(self.tagMissions[i]) then
				-- could successfully retrieve and tag all vecs of this mission
				table.remove(self.tagMissions, i)
			end
		end 
	end
end

function BetterContracts:updateGeneration()
	-- set Mission generation rate (std is 6 min)
	MissionManager.MISSION_GENERATION_INTERVAL = self.config.generationInterval * 360000
	-- update excluded contracts
	self.genContracts.treeTransportMission = self.config.genTree 
	self.genContracts.deadwoodMission = self.config.genDead 
	self.genContracts.destructibleRockMission = self.config.genRock
	-- update excluded harvest contracts
	self.canHarvest.GRAIN = self.config.genGrain
	self.canHarvest.GREEN = self.config.genGreen
	self.canHarvest.VEGETABLES = self.config.genVegetable
	self.canHarvest.ROOT = self.config.genRoot
end
function BetterContracts:updateGenerationSettings()
	self:updateGeneration()

	-- adjust max missions
	local fieldsAmount = table.size(g_fieldManager.fields)
	local adjustedFieldsAmount = math.max(fieldsAmount, 45)
	MissionManager.MAX_MISSIONS = math.min(80, math.ceil(adjustedFieldsAmount * 0.60)) -- max missions = 60% of fields amount (minimum 45 fields) max 120
	debugPrint("[%s] Fields amount %s (%s)", self.name, fieldsAmount, adjustedFieldsAmount)
	debugPrint("[%s] MAX_MISSIONS set to %s", self.name, MissionManager.MAX_MISSIONS)
end
function saveSavegame()
	-- save our settings
	self = BetterContracts
	if self.saveFile == nil then
		if g_currentMission and g_currentMission.missionInfo then
			local savegameDir = g_currentMission.missionInfo.savegameDirectory
			if savegameDir ~= nil then
				self.saveFile = ("%s/%s.xml"):format(savegameDir, self.name)
				self.savegameIx = g_currentMission.missionInfo.savegameIndex
			-- else: Save game directory is nil if this is a brand new save
			end
		else
			Logging.warning("[%s] saveSavegame() could not get path to savegame directory",
				self.name)
			return
		end
	end
	debugPrint("[%s] saving settings to %s (savegame%d)", 
		self.name, self.saveFile, self.savegameIx)
	local xmlFile = XMLFile.create("BCconf", self.saveFile, self.baseXmlKey, self.xmlSchema)
	if xmlFile == nil then 
		Logging.warning("[%s] saveSavegame() could not create xmlFile %s",
				self.name, self.saveFile)
		return 
	end 
	local conf = self.config
	local key = self.baseXmlKey 
	xmlFile:setBool ( key.."#debug", 		  conf.debug)
	xmlFile:setBool ( key.."#ferment", 		  conf.ferment)
	xmlFile:setBool ( key.."#forcePlow", 	  conf.forcePlow)
	xmlFile:setBool ( key.."#hideMission", 	  conf.hideMission)
	xmlFile:setBool ( key.."#stayNew", 	  	  conf.stayNew)
	xmlFile:setBool ( key.."#finishField", 	  conf.finishField)
	xmlFile:setInt  ( key.."#maxActive",	  conf.maxActive)

	xmlFile:setFloat( key.."#reward", 		  conf.rewardMultiplier)
	xmlFile:setFloat( key.."#rewardMow", 	  conf.rewardMultiplierMow)
	xmlFile:setFloat( key.."#lease", 		  conf.leaseMultiplier)
	xmlFile:setFloat( key.."#deliver", 		  conf.toDeliver)
	xmlFile:setFloat( key.."#deliverBale", 	  conf.toDeliverBale)
	xmlFile:setFloat( key.."#fieldCompletion",conf.fieldCompletion)
	xmlFile:setInt  ( key.."#refreshMP",	  conf.refreshMP)
	xmlFile:setBool ( key.."#lazyNPC", 		  conf.lazyNPC)
	xmlFile:setBool ( key.."#discount", 	  conf.discountMode)
	xmlFile:setBool ( key.."#hard", 		  conf.hardMode)
	if conf.lazyNPC then
		key = self.baseXmlKey .. ".lazyNPC"
		xmlFile:setBool (key.."#harvest", 	conf.npcHarvest)
		xmlFile:setBool (key.."#plowCultivate",conf.npcPlowCultivate)
		xmlFile:setBool (key.."#sow", 		conf.npcSow)
		xmlFile:setBool (key.."#weed", 		conf.npcWeed)
		xmlFile:setBool (key.."#fertilize", conf.npcFertilize)
	end
	if conf.discountMode then
		key = self.baseXmlKey .. ".discount"
		xmlFile:setFloat(key.."#perJob", 	conf.discPerJob)
		xmlFile:setInt  (key.."#maxJobs",	conf.discMaxJobs)
	end
	if conf.hardMode then
		key = self.baseXmlKey .. ".hard"
		xmlFile:setFloat(key.."#penalty", 	conf.hardPenalty)
		xmlFile:setInt  (key.."#leaseJobs",	conf.hardLease)
		xmlFile:setInt  (key.."#expire",	conf.hardExpire)
		xmlFile:setInt  (key.."#hardLimit",	conf.hardLimit)
	end
	key = self.baseXmlKey .. ".generation"
	xmlFile:setInt	( key.."#interval",   conf.generationInterval)
		xmlFile:setBool (key.."#genGrain", 		conf.genGrain)
		xmlFile:setBool (key.."#genRoot", 		conf.genRoot)
		xmlFile:setBool (key.."#genGreen", 		conf.genGreen)
		xmlFile:setBool (key.."#genVegetable", 	conf.genVegetable)
		xmlFile:setBool (key.."#genTree", 		conf.genTree)
		xmlFile:setBool (key.."#genDead", 		conf.genDead)
		xmlFile:setBool (key.."#genRock", 		conf.genRock)
	xmlFile:save()
	xmlFile:delete()
end
function missionWriteStream(self, streamId, connection)
	-- appended to AbstractMission.writeStream
	if self.field ~= nil then
		local info = self.info
		streamWriteFloat32(streamId, info.worktime or 0)
		streamWriteFloat32(streamId, info.profit or 0)
		streamWriteFloat32(streamId, info.usage or 0)
		streamWriteFloat32(streamId, info.perMin or 0)

		streamWriteUInt8(streamId, self.fruitTypeIndex or 0)
	end
end
function missionReadStream(self, streamId, connection)
	debugPrint("* read %s from stream. VehicleGroup %s",self.type.name,
		self.vehicleGroupIdentifier )
	if self.field ~= nil then
		local info = self.info
		info.worktime = streamReadFloat32(streamId)
		info.profit = streamReadFloat32(streamId)
		info.usage = streamReadFloat32(streamId)
		info.perMin = streamReadFloat32(streamId)
		--debugPrint("*  Worktime %d, profit %d ,usage %d, perMin %d",
		--	info.worktime,info.profit,info.usage,info.perMin)
		local index = streamReadUInt8(streamId)
		self.fruitTypeIndex = index >0 and index or nil
	end
end
function harvestWriteStream(self, streamId, connection)
	streamWriteFloat32(streamId, self.expectedLiters or 0)
	streamWriteFloat32(streamId, self.depositedLiters or 0)
	streamWriteFloat32(streamId, self.info.keep or 0)
end
function harvestReadStream(self, streamId, connection)
	self.expectedLiters = streamReadFloat32(streamId)
	self.depositedLiters = streamReadFloat32(streamId)
	self.info.keep = streamReadFloat32(streamId)
	--debugPrint("* read expected %d, deposit %d ,keep %d",self.expectedLiters, 
	--	self.depositedLiters, self.info.keep)
end
function missionWriteUpdateStream(self, streamId, connection, dirtyMask)
	-- appended to AbstractMission.writeUpdateStream
	if self.status == MissionStatus.RUNNING then
		streamWriteBool(streamId, self.spawnedVehicles or false)
		streamWriteFloat32(streamId, self.fieldPercentageDone or 0.)
		streamWriteFloat32(streamId, self.depositedLiters or 0.)
	end
end
function missionReadUpdateStream(self, streamId, timestamp, connection)
	-- appended to AbstractMission.readUpdateStream
	if self.status == MissionStatus.RUNNING then
		self.spawnedVehicles = streamReadBool(streamId)
		self.fieldPercentageDone = streamReadFloat32(streamId)
		self.depositedLiters = streamReadFloat32(streamId)
	end
end
function hasFarmReachedMissionLimit(self,superf,farmId)
	-- overwritten from MissionManager
	local maxActive = BetterContracts.config.maxActive
	if maxActive == 0 then return false end 

	MissionManager.MAX_MISSIONS_PER_FARM = maxActive
	return superf(self, farmId)
end
function harvestMissionNew(isServer, superf, isClient, customMt )
	-- allow mower/ swather to harvest swaths
	local self = superf(isServer, isClient, customMt)
	self.workAreaTypes[WorkAreaType.MOWER] = true 
	self.workAreaTypes[WorkAreaType.FORAGEWAGON] = true 
	return self
end
function getFieldFinishTask(self, superf)
	-- overwrites HarvestMission:getFieldFinishTask
	local state = self.field:getFieldState()
	local ft = g_fruitTypeManager:getFruitTypeByIndex(self.fruitTypeIndex)

	if BetterContracts.config.forcePlow and
	 string.find("MAIZE POTATO SUGARBEET", ft.name) then 
	 	debugPrint("**set plowLevel to 0 **")
		state.plowLevel = 0 -- force plowing after root crop harvest
	end
	state.sprayLevel = 0  -- remove fertilizer level
	return superf(self)
end