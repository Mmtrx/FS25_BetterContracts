--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:		UI for all settings.
-- Author:		Mmtrx
-- Changelog:
--  v1.0.0.0    28.10.2024  1st port to FS25 (not yet used)
--  v1.1.0.0    03.01.2025  new UI settings page
--=======================================================================================================
-- Define the UI controls. For bool values, supply just the name, for ranges, supply min, max 
-- and step, and for choices, supply a values table
-- For every name, a <prefix>_<name>_tooltip and <prefix>_<name> text must exist in the l10n files
-- The short text will be the title of the setting, the _tooltip text will be its tool tip
-- For each control, a on_<name>_changed callback will be called on change
ControlProperties = {
	--{title = "bc_baseSettings"},
    { name = "rewardMultiplier", min = 0.1, max = 1.5, step = 0.1, unit= "%", autoBind = true },
    { name = "rewardMultiplierMow", min = 0.1, max = 1.5, step = 0.1, unit= "%", autoBind = true },
    { name = "leaseMultiplier", min = 0.8, max = 1.5, step = 0.1, unit= "%", autoBind = true },
    { name = "maxActive", min = 0, max = 10, step = 1, autoBind = true },
    -- basegame: AbstractMission.SUCCESS_FACTOR = 0.98
    { name = "fieldCompletion", min = 0.8, max = 0.98, step = 0.03, unit= "%", autoBind = true },
    -- basegame: HarvestMission.SUCCESS_FACTOR = 0.93
    { name = "toDeliver", min = 0.7, max = 0.94, step = 0.03, unit= "%", autoBind = true },
    { name = "refreshMP", values = {"ui_admin","ui_farmManager","ui_players"}, autoBind = true },
    { name = "ferment", autoBind = true },
    { name = "forcePlow", autoBind = true },
    { name = "debug", autoBind = true },
	{title = "bc_discountTitle"},
    { name = "discountMode", autoBind = true },
    { name = "discPerJob", min= .01, max= .14, step= .01, unit= "%", autoBind = true },  --
    { name = "discMaxJobs", min= 1, max= 20, step= 1, autoBind = true },
	{title = "bc_hardModeTitle"},
    { name = "hardMode", autoBind = true },
    { name = "hardPenalty", min= .0, max= .7, step= .1, unit= "%", autoBind = true },
    { name = "hardLease", min= 0, max= 7, step= 1, autoBind = true },
    { name = "hardExpire", values = {SC.OFF, SC.DAY, SC.MONTH}, autoBind = true },
    { name = "hardLimit", min= 0, max= 10, step= 1, nillable =true, autoBind = true },
	{title = "bc_lazyNPCTitle"},
    { name = "lazyNPC", autoBind = true },
    { name = "npcHarvest", ui="contract_field_harvest_title", autoBind = true },
    { name = "npcSow", ui="contract_field_sow_title", autoBind = true },
    { name = "npcPlowCultivate", autoBind = true },
    { name = "npcFertilize", ui="contract_field_fertilize_title", autoBind = true },
    { name = "npcWeed", ui="contract_field_hoe_title", autoBind = true },
}
-- control dependencies
ControlDep = {
	lazyNPC = {"npcHarvest","npcSow","npcPlowCultivate","npcFertilize","npcWeed"},
	discountMode = {"discPerJob","discMaxJobs"},
	hardMode = {"hardPenalty","hardLease","hardExpire", "hardLimit"},
}
ControlDevelop = {  -- not yet functional
	"ferment", "forcePlow", "lazyNPC", "bc_lazyNPCTitle", "bc_hardModeTitle", "hardMode" }

-- control settings class
BCcontrol = {}
local BCcontrol_mt = Class(BCcontrol)

function BCcontrol.new(name, customMt)
	--[[
	<Bitmap profile="fs25_multiTextOptionContainer">
		<MultiTextOption profile="fs25_settingsMultiTextOption" >
			<Text profile="fs25_multiTextOptionTooltip"/>
		</MultiTextOption>
		<Text profile="fs25_settingsMultiTextOptionTitle"/>
	</Bitmap>
	]]
    local self = setmetatable({}, BCcontrol_mt)
	self.name = name
	self.previous = 1  		-- holds previous MTO state
	self.current = nil  	-- current MTO state
	self.guiElement = nil
	return self
end
function BCcontrol:updateDisabled(disable)
	-- disable our gui elements
	self.guiElement.elements[1]:setDisabled(disable)  -- the MTO
	self.guiElement.elements[2]:setDisabled(disable)  -- the title
end
function BCcontrol:setIx(ix)   
-- update the BetterContracts.config value MP only, on Server
	-- set it to values[ix]
	local conf = BetterContracts.config
	if self.current ~= ix then 
		self.previous = self.current
		self.current = ix 
		local value = UIHelper.getControlValue(self.guiElement, ix)
		conf[self.name] = value
		debugPrint("** %s set to %s **", self.name,value)
	end
end
function BCcontrol:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.current)
end
function BCcontrol:readStream(streamId, connection)
	local ix = streamReadInt32(streamId)
	self:setIx(ix)
end
--[[ BC FS22 action functions, todo when needed
	-- hardLimit
	actionFunc = function(self,ix) 
		-- set stats.jobsLeft for all farms
		if ix == 1 then 		-- reset to no limit
			for _, farm in pairs(g_farmManager:getFarms()) do
				farm.stats.jobsLeft = -1
			end
		else BetterContracts:resetJobsLeft() end
		end,
]]

