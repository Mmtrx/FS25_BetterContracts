--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:     Enhance ingame contracts menu.
-- Functions:   options for lazyNPC, hardMode, fieldDiscount
-- Author:      Royal-Modding / Mmtrx
-- Changelog:
--  v1.0.0.0    28.10.2024  1st port to FS25
--  v1.1.0.0    08.01.2025  UI settings page, discount mode
--=======================================================================================================

--------------------- lazyNPC --------------------------------------------------------------------------- 
function NPCHarvest(self, superf, field, allowUpdates)
	if not BetterContracts.config.lazyNPC or not allowUpdates then 
		return superf(self, field, allowUpdates) 
	end
	if not BetterContracts.NPCAllowWork then 
		-- lazyNPC active, too early for NPC field work
		table.insert(self.fieldsToUpdate, field)
		return
	end
	-- lazyNPC active, NPC field upates allowed
	if BetterContracts.fieldToMission[field.fieldId] == nil then 
		return superf(self, field, allowUpdates)
	end

	-- there is a mission offered for this field, lazyNPC active, NPC field upates allowed
	local conf 		= BetterContracts.config
	local prob 		= BetterContracts.npcProb
	local limeMiss 	= BetterContracts.limeMission
	local fruitDesc, harvestReadyState, maxHarvestState, area, total, withered
	local x, z = FieldUtil.getMeasurementPositionOfField(field)
	if field.fruitType ~= nil then
		-- not an empty field
		fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(field.fruitType)

		local witheredState = fruitDesc.witheredState
		if witheredState ~= nil then
			area, total = FieldUtil.getFruitArea(x - 1, z - 1, x + 1, z - 1, x - 1, z + 1, FieldUtil.FILTER_EMPTY, FieldUtil.FILTER_EMPTY, field.fruitType, witheredState, witheredState, 0, 0, 0, false)
			withered = area > 0.5 * total 
		end
		if conf.npcHarvest then
			-- don't let NPCs harvest
			harvestReadyState = fruitDesc.maxHarvestingGrowthState
			if fruitDesc.maxPreparingGrowthState > -1 then
				harvestReadyState = fruitDesc.maxPreparingGrowthState
			end
			maxHarvestState = FieldUtil.getMaxHarvestState(field, field.fruitType)
			if maxHarvestState == harvestReadyState then return end
		end
		if conf.npcWeed and not withered then 
			-- leave field with weeds for weeding/ spraying
			local maxWeedState = FieldUtil.getMaxWeedState(field)
			if maxWeedState >= 3 and math.random() < prob.weed then return 
			end
		end
		if conf.npcPlowCultivate then
			-- leave a cut field for plow/ grubber/ lime mission
			area, total = FieldUtil.getFruitArea(x - 1, z - 1, x + 1, z - 1, x - 1, z + 1, FieldUtil.FILTER_EMPTY, FieldUtil.FILTER_EMPTY, field.fruitType, fruitDesc.cutState, fruitDesc.cutState, 0, 0, 0, false)
			if area > 0.5 * total and 
				g_currentMission.snowSystem.height < SnowSystem.MIN_LAYER_HEIGHT then
				local limeFactor = FieldUtil.getLimeFactor(field)
				if limeMiss and limeFactor == 0 and math.random() < prob.lime then return
				elseif math.random() < prob.plowCultivate then return 
				end 
			end
		end
		if conf.npcFertilize and not withered then 
			local sprayFactor = FieldUtil.getSprayFactor(field)
			if sprayFactor < 1 and math.random() < prob.fertilize then return
			end
		end
	elseif conf.npcSow then
		-- leave empty (plowed/grubbered) field for sow/ lime mission
		local limeFactor = FieldUtil.getLimeFactor(field)
		if limeMiss and limeFactor == 0 and math.random() < prob.lime then return
		elseif self:getFruitIndexForField(field) ~= nil and 
			math.random() < prob.sow then return 
		end
	end
	superf(self, field, allowUpdates)
end

--------------------- completion / reward / lease cost --------------------------------------------------
function getCompletion(self,superf)
	-- overwrites AbstractFieldMission:getCompletion()
	local fieldCompletion = self:getFieldCompletion()
	return fieldCompletion / BetterContracts.config.fieldCompletion 
end
function harvestCompletion(self,superf)
	-- overwrites HarvestMission:getCompletion()
	local sellCompletion = 
	 math.min(self.depositedLiters / self.expectedLiters / HarvestMission.SUCCESS_FACTOR, 1)
	local harvestCompletion = math.min(getCompletion(self), 1)
	return math.min(1, 0.8 * harvestCompletion + 0.2 * sellCompletion)
end
function baleCompletion(self,superf)
	-- overwrites BaleMission:getCompletion()
	local sellCompletion = 
	 math.min(self.depositedLiters / self.expectedLiters / BaleMission.FILL_SUCCESS_FACTOR, 1)
	local harvestCompletion = math.min(getCompletion(self), 1)
	return math.min(1, 0.2 * harvestCompletion + 0.8 * sellCompletion)
end
function getReward(self,superf)
	-- overwrites AbstractFieldMission:getReward()
	if self.type.name == "mowMission" then
		return BetterContracts.config.rewardMultiplierMow * superf(self)
	end		
	return BetterContracts.config.rewardMultiplier * superf(self)
end
function calcLeaseCost(self,superf)
	-- overwrites AbstractMission:getVehicleCosts()
	return BetterContracts.config.leaseMultiplier * superf(self)
end

--------------------- manage npc jobs per farm ----------------------------------------------------------
function farmWrite(self, streamId)
	-- appended to Farm:writeStream()
	if self.isSpectator	then return end 

	-- write jobsLeft for current month
	self.stats.jobsLeft = self.stats.jobsLeft or BetterContracts.config.hardLimit 
	streamWriteUInt8(streamId, self.stats.jobsLeft) 	-- # of jobs left to accept this month

	-- write stats.npcJobs when MP syncing a farm
	local count = 0
	if self.stats.npcJobs == nil then 
		self.stats.npcJobs = {}
	else
		count = table.size(self.stats.npcJobs)		-- returns 0 if table is empty
	end
	streamWriteUInt8(streamId, count) 					-- # of job infos to follow
	debugPrint("* writing %d stats.npcJobs for farm %d", count, self.farmId)
	if count > 0 then
		for k,v in pairs(self.stats.npcJobs) do
			streamWriteUInt8(streamId, k) 				-- npcIndex
			streamWriteUInt8(streamId, v) 				-- jobs[npcIndex]
		end
	end
end
function farmRead(self, streamId)
	-- appended to Farm:readStream()
	if self.isSpectator	then return end

	-- read jobsLeft for current month
	self.stats.jobsLeft =  streamReadUInt8(streamId)

	-- read npcJobs[npcIndex] for a farm
	if self.stats.npcJobs == nil then 
		self.stats.npcJobs = {}
	end
	local jobs = self.stats.npcJobs
	local npcIndex
	for j = 1, streamReadUInt8(streamId) do
		npcIndex = streamReadUInt8(streamId)
		jobs[npcIndex] = streamReadUInt8(streamId)
		debugPrint("  jobs[%d] = %d (farm %d)", npcIndex, jobs[npcIndex],self.farmId)
	end
end
function finish(self, success )
	-- appended to AbstractFieldMission:finish(success)
	debugPrint("** finish() %s %s on field %s",success,self.type.name, self.field:getName())
	local farm =  g_farmManager:getFarmById(self.farmId)
	if farm.stats.npcJobs == nil then 
		farm.stats.npcJobs = {}
	end
	local jobs = farm.stats.npcJobs
	local npcIndex = self.field.farmland.npcIndex

	if success == MissionFinishState.SUCCESS then
		-- (always) count as valid job for this npc:
		if jobs[npcIndex] == nil then 
			jobs[npcIndex] = 1 
		else
			jobs[npcIndex] = jobs[npcIndex] +1
		end
		-- show notifications, if discount mode
		if BetterContracts.config.discountMode and g_client 
			and  g_currentMission:getFarmId() == self.farmId then
			local discPerJob = BetterContracts.config.discPerJob
			local disMax = math.min(BetterContracts.config.discMaxJobs,math.floor(0.5 / discPerJob))
			local disJobs = math.min(jobs[npcIndex], disMax)
			local disct = disJobs * 100 * discPerJob
			local npc = self:getNPC()
			g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, 
					string.format(g_i18n:getText("bc_discValue"), npc.title, disct))
			if jobs[npcIndex] >= disMax then
				g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, 
					string.format(g_i18n:getText("bc_maxJobs"), npc.title))
			end
		end
	elseif BetterContracts.config.hardMode then
		-- reduce # valid jobs for this npc:
		if jobs[npcIndex] == nil then 
			jobs[npcIndex] = 0 
		else
			jobs[npcIndex] = math.max(0, jobs[npcIndex] -1)
		end
	end
end
function saveToXML(self, xmlFile, key)
	-- appended to FarmStats:saveToXMLFile(), self is farm.stats
	local jobs = self.npcJobs
	if jobs ~= nil then
		xmlFile:setTable(key .. ".npcJobs.npc", jobs, 
			function (npcKey, npc, npcIndex)
			xmlFile:setInt(npcKey .. "#index", npcIndex)
			xmlFile:setInt(npcKey .. "#count", npc or 0)
		end)
	end
	local bc = BetterContracts
	if bc.config.hardMode and bc.config.hardLimit > -1 then
		xmlFile:setInt(key..".jobsLeft", self.jobsLeft, BetterContracts.config.hardLimit)
	end
end
function loadFromXML(self, xmlFile, key)
	-- appended to FarmStats:loadFromXMLFile()
	self.npcJobs = {}
	xmlFile:iterate(key .. ".npcJobs.npc", function (_, npcKey)
		local ix = xmlFile:getInt(npcKey.."#index")
		self.npcJobs[ix] = xmlFile:getInt(npcKey.."#count", 0)
	end)
	-- load avail monthly jobs contingent
	self.jobsLeft = xmlFile:getInt(key..".jobsLeft", BetterContracts.config.hardLimit)
end

--------------------- hard mode ------------------------------------------------------------------------- 
function AbstractFieldMission:calculateStealingCost()
	-- calc penalty for canceled field mission
	if BetterContracts.config.hardMode and not self.success and self.reward then
		return self:getReward() * BetterContracts.config.hardPenalty 
	end
	return 0
end
function harvestCalcStealing(self,superf)
	local steal = superf(self)
	local penal = 0
	if BetterContracts.config.hardMode then 
		penal = HarvestMission:superClass().calculateStealingCost(self)
		debugPrint("BC: harvest steal/ penalty is %.1f / %.1f", steal, penal)
	end
	return steal + penal
end
function updateDetails(self, section, index)
	-- appended to InGameMenuContractsFrame:updateDetailContents()
	local bc = BetterContracts
	local contract = nil
	local sectionContracts = self.sectionContracts[section]
	if sectionContracts ~= nil then
		contract = sectionContracts.contracts[index]
	end
	
	if contract == nil then return end
	local mission = contract.mission

	if contract.finished then
		bc.my.npcbox:setVisible(false)  	-- remove our npcbox
	end

	-- hard Mode: vehicle lease cost also for canceled mission
	if bc.config.hardMode and contract.finished and not mission.success then 
		local lease, penal = 0, 0
		if mission:hasLeasableVehicles() and mission.spawnedVehicles then
			lease = - MathUtil.round(mission.vehicleUseCost)
		end
		-- stealing contains our penalty value
		if mission.stealingCost ~= nil then
			penal = - MathUtil.round(mission.stealingCost)
			self.tallyBox:getDescendantByName("stealingText"):setText(g_i18n:getText("bc_penalty"))
		end
		local total = lease + penal 
		self.tallyBox:getDescendantByName("leaseCost"):setText(g_i18n:formatMoney(lease, 0, true, true))
		self.tallyBox:getDescendantByName("stealing"):setText(g_i18n:formatMoney(penal, 0, true, true))
		self.tallyBox:getDescendantByName("total"):setText(g_i18n:formatMoney(total, 0, true, true))
	end
	local noActive = not contract.active or not bc.isOn

	-- toggle standard / enhanced progress bars
	bc:showProgressBars(contract, not noActive and 
		table.hasElement({"harvestMission","mow_baleMission", "chaffMission"}, mission.type.name))
	if noActive then return end 

	-- update display for active contracts
	if mission:hasLeasableVehicles() and mission.spawnedVehicles then
		-- show leased vecs for active contract
		local totalWidth = 0 
		-- smaller vehiclesBox to not interfere with 2nd progress bar
		self.vehicleTemplate:applyProfile("myVehiclesItem")
		self.vehiclesBox:applyProfile("myVehiclesBox")
		for _, v in ipairs(mission.vehiclesToLoad) do
			local storeItem = g_storeManager:getItemByXMLFilename(v.filename)
			local element = self.vehicleTemplate:clone(self.vehiclesBox)
			element:setImageFilename(storeItem.imageFilename)
			element:setImageColor(nil,nil,nil,nil, 1)
			totalWidth = totalWidth + element.absSize[1] + element.margin[1] + element.margin[3]
			table.insert(self.vehicleElements, element)
		end
		self.vehiclesBox:setVisible(true)
		self.vehiclesBox:setPosition(0)
		self.vehiclesBox:setSize(totalWidth)
		self.vehiclesBox:invalidateLayout()
	end
end
function BetterContracts:showProgressBars(contract, on)
	-- hide standard progress bar
	local off = not on 
	local cbox = self.frCon
	cbox.progressText:setVisible(off and contract.active)
	cbox.progressTitleText:setVisible(off and contract.active)
	cbox.extraProgressText:setVisible(off and contract.active)
	cbox.progressBarBg:setVisible(off and contract.active)

	-- show my progress bars
	self.my.box1:setVisible(on)
	self.my.box2:setVisible(on)
	if off then return end 

	local fullWidth = self.my.progressBarBg.size[1] - self.my.progressBar1.margin[1] * 2
	local fieldPercent = math.min(self.fieldPercent, 1)
	local deliverPercent = math.min(self.deliverPercent, 1)
	self.my.prog1:setText(string.format("  %.0f%%", fieldPercent * 100))
	self.my.progressBar1:setSize(fullWidth * fieldPercent, nil)
	self.my.prog2:setText(string.format("  %.0f%%", deliverPercent * 100))
	self.my.progressBar2:setSize(fullWidth * deliverPercent, nil)
end
function dismiss(self)
	-- appended to AbstractMission:dismiss()
	if not BetterContracts.config.hardMode or not self.isServer then return end

	-- deduct lease cost for a canceled mission
	if self:hasLeasableVehicles() and self.spawnedVehicles then
		self.mission:addMoney(-self.vehicleUseCost,self.farmId,	MoneyType.MISSIONS, true, true)
	end
end
function startContract(frCon, superf, wantsLease)
	self = BetterContracts
	local farmId = g_currentMission:getFarmId()

	-- overwrite dialog info box
	if g_missionManager:hasFarmReachedMissionLimit(farmId) 
		and BetterContracts.config.maxActive ~= 3 then
		InfoDialog.show(g_i18n:getText("bc_enoughMissions"))
		return
	end
	-- (hardMode) --
	if self.config.hardMode then 
		local farm = g_farmManager:getFarmById(farmId)
		if wantsLease then 
		-- check if enough jobs complete to allow lease
			local contract = frCon:getSelectedContract()
			local npc = contract.mission:getNPC()
			local jobs = 0
			if farm.stats.npcJobs ~= nil and farm.stats.npcJobs[npc.index] ~= nil then 
				jobs = farm.stats.npcJobs[npc.index]
			end
			if jobs < self.config.hardLease then
				InfoDialog.show(string.format(g_i18n:getText("bc_leaseNotEnough"),
						self.config.hardLease - jobs, npc.title))
				return
			end
		end
		if self.config.hardLimit > -1 then
		-- check available monthly jobs limit
			if farm.stats.jobsLeft == -1 then  	-- hardLimit was set during this game
				farm.stats.jobsLeft = self.config.hardLimit
			end
			if farm.stats.jobsLeft == 0 then 
				InfoDialog.show(g_i18n:getText("bc_monthlyLimit"))
				return
			else
				farm.stats.jobsLeft = farm.stats.jobsLeft -1
			end
		end
	end
	superf(frCon, wantsLease)
end
function BetterContracts:resetJobsLeft()
	-- recalc jobs left per farm
	for _,farm in pairs(g_farmManager:getFarms()) do
		if farm.farmId ~= FarmManager.SPECTATOR_FARM_ID then
			local mlist = table.ifilter(g_missionManager:getMissionsList(farm.farmId), function(m)
				return m.status ~= AbstractMission.STATUS_STOPPED
				end)
			local count = table.size(mlist)
			farm.stats.jobsLeft =  math.max(self.config.hardLimit - count, 0)
			debugPrint("*BC: farm %s has %d jobs. Limit set to %d", farm.name, count, farm.stats.jobsLeft)
		end
	end
end
function BetterContracts:onPeriodChanged()
	-- reset monthly limit for all farms:
	if self.config.hardLimit > -1 then 
		self:resetJobsLeft()
	end

	if g_server == nil then return end 
	
	self.NPCAllowWork = false  	-- prevent any NPC field work at start of month

	-- hard mode: cancel any active field missions
	if self.config.hardMode and self.config.hardExpire == SC.MONTH then  
		for _, m in ipairs(g_missionManager:getActiveMissions()) do 
			if m:hasField() then
				g_missionManager:cancelMission(m)
			end
		end
	end
end
function BetterContracts:onDayChanged()
	-- hard mode: cancel any active field missions
	if g_server == nil or not self.config.hardMode 
		or self.config.hardExpire ~= SC.DAY then return end
	for _, m in ipairs(g_missionManager:getActiveMissions()) do 
		if m:hasField() then
			g_missionManager:cancelMission(m)
		end
	end
end
function BetterContracts:onHourChanged()
	local env = g_currentMission.environment

	-- check if NPCs can work
	if self.config.lazyNPC and g_server ~= nil and 
		env.currentDayInPeriod == 1 and env.currentHour == 12 then 
		self.NPCAllowWork = true 
	end

	-- hard mode: issue warnings 6,3,1 h before active missions cancel
	if not self.config.hardMode or self.config.hardExpire == SC.OFF or g_client == nil 
		then return end
	if self.config.hardExpire == SC.MONTH and 
		env.currentDayInPeriod ~= env.daysPerPeriod then return end
	if not table.hasElement({18,21,23}, env.currentHour) then return end 

	local farmId = g_currentMission:getFarmId()
	local count = 0 
	for _, m in ipairs(g_missionManager:getActiveMissions()) do 
		if m.getField and m.farmId == farmId then 
			count = count +1
		end
	end
	if count > 0 then
		g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, 
			string.format(g_i18n:getText("bc_warnTimeout"), count))
	end
end
function onButtonCancel(self, superf)
	local bc = BetterContracts
	if not bc.config.hardMode or bc.config.hardPenalty == 0.0
		then return superf(self) end
	local contract = self:getSelectedContract()
	local m = contract.mission 
	--local difficulty = 0.7 + 0.3 * g_currentMission.missionInfo.economicDifficulty
	local text = g_i18n:getText("contract_end")
	local reward = m:getReward()
	if reward then  
		local penalty = MathUtil.round(reward * bc.config.hardPenalty) 
		text = text.. g_i18n:getText("bc_warnCancel") ..
		 g_i18n:formatMoney(penalty, 0, true, true)
	end
	YesNoDialog.show(self.onCancelDialog, self, text)
end

--------------------- discount mode --------------------------------------------------------------------- 
function AbstractFieldMission:getNPC()
		local npcIndex = self.field.farmland.npcIndex
		return g_npcManager:getNPCByIndex(npcIndex)
end
function getDiscountPrice(farmland)
	-- returns discount as delta and percent-text
	local discPerJob = BetterContracts.config.discPerJob
	local delta = 0
	local noFarm = g_i18n:getText("ui_noFarm")  	-- pas de ferme
	local words = noFarm:split(" ")					
	local k = noFarm:find(words[#words])			--        ^ 
	local disct = noFarm:sub(1,k-1) 				-- pas de

	local farm =  g_farmManager:getFarmById(g_localPlayer.farmId)
	local jobs = farm.stats.npcJobs or {}
	local count = jobs[farmland.npcIndex] or 0
	local disJobs = math.min(count, BetterContracts.config.discMaxJobs,
		math.floor(0.5 / discPerJob))

	if disJobs > 0 then
		delta = farmland.price * disJobs * discPerJob		
		disct = string.format("%d%%", 100 *disJobs *discPerJob)
	end
	return delta, disct
end
function showContextBox(box, hotspot, description, image, uvs, farmId, farmText, p27, p28, isFarmBox)
	-- appended to InGameMenuMapUtil.showContextBox()
	if box == nil then return end 

  -- add text to farmland context box
	local bc = BetterContracts
	local frame = bc.frMap
	bc:discountVisible(false)

	if not bc.config.discountMode or not isFarmBox or 
		not frame.contextActions[InGameMenuMapFrame.ACTIONS.BUY].isActive
		then return end 

	local farmland = frame.selectedFarmland

	-- show npc owner:
	local npc = g_npcManager:getNPCByIndex(farmland.npcIndex)
	local delta, disct = getDiscountPrice(farmland)

	local text = string.format("%s: %s %s", npc.title, disct, g_i18n:getText("bc_discount"))
	bc.my.title.owner:setText(text)

	text = ""
	if delta > 0 then 
		text = g_i18n:formatMoney(delta, 0, true)
	end 
	bc.my.text.owner:setText(text)
	bc:discountVisible(true)

	-- Todo: if price-delta < player balance < price, we don't get called here. 
	-- But Buy Button is displayed anyhow

  -- to change color of vehicle text, if mission vehicle
	if description and description:sub(-1) == ")" then 
		text:applyProfile("missionVehicleText")
	--else text:applyProfile("ingameMenuMapContextText")		
	end
end
function onClickBuyFarmland(self)
	--overwrites InGameMenuMapFrame:onClickBuy()
	-- adjust price if player buys farmland
	local bc = BetterContracts
	if self.selectedFarmland == nil or  
		g_missionManager:getIsMissionRunningOnFarmland(self.selectedFarmland)
		then return self:onClickBuy() end

	local discMode = BetterContracts.config.discountMode
	local price, disct = self.selectedFarmland.price, ""
	local delta = 0

	if discMode then
		delta, disct = getDiscountPrice(self.selectedFarmland)
	end
	if disct ~= "" then 
		disct = string.format(" (%s %s)", disct, g_i18n:getText("bc_discount")) 
	end

	if price - delta <= self.playerFarm:getBalance() then
		local priceText = g_i18n:formatMoney(price-delta, 0, true,true)..disct 
		local text = string.format(g_i18n:getText(InGameMenuMapFrame.L10N_SYMBOL.DIALOG_BUY_FARMLAND), priceText)
		local callback, target, args = self.onYesNoBuyFarmland, self, nil

		if discMode then  
			callback = BetterContracts.onYesNoBuyFarmland
			target = BetterContracts
			args = {self.selectedFarmland.id, g_currentMission:getFarmId(), price-delta}
		end

		YesNoDialog.show(callback, target, text, 
			g_i18n:getText(InGameMenuMapFrame.L10N_SYMBOL.DIALOG_BUY_FARMLAND_TITLE),
			nil,nil,nil,nil,nil, args)
	else
		InfoDialog.show(g_i18n:getText(InGameMenuMapFrame.L10N_SYMBOL.DIALOG_BUY_FARMLAND_NOT_ENOUGH_MONEY))
	end
end
function BetterContracts:onYesNoBuyFarmland(yes, args)
	local mapFrame = self.frMap
	if yes then 
		-- remove owner info:
		--self.my.text.owner:setVisible(false)
		--self.my.title.owner:setVisible(false)
		g_client:getServerConnection():sendEvent(FarmlandStateEvent.new(unpack(args)))
		mapFrame:setMapSelectionItem()
		InGameMenuMapUtil.hideContextBox(mapFrame.contextBox)
		InGameMenuMapUtil.hideContextBox(mapFrame.contextBoxPlayer)
		InGameMenuMapUtil.hideContextBox(mapFrame.contextBoxFarmland)
	else
		mapFrame.elementToFocus = mapFrame.contextButtonListFarmland
	end
end
function BetterContracts:onFarmlandStateChanged(landId, farmId)
	-- if client buys/sells farmland, FarmlandStateEvent is sent to server, then broadcast to all clients
	-- so we only change npcJobs on server and on the client who bought the farmland
	if farmId == FarmlandManager.NO_OWNER_FARM_ID 
		or not self.config.discountMode or not g_currentMission.isMissionStarted
		then return end 
	if not (g_server or g_currentMission:getFarmId() == farmId)
		then return end 

	-- decrease npcJobs to 0, or by discMaxJobs for npc seller of farmland
	local farm =  g_farmManager:getFarmById(farmId)
	local npcIndex = g_farmlandManager:getFarmlandById(landId).npcIndex
	if farm == nil or npcIndex == nil then return end 
	
	if farm.stats.npcJobs == nil then 
		farm.stats.npcJobs = {}
	elseif farm.stats.npcJobs[npcIndex] ~= nil then  
		farm.stats.npcJobs[npcIndex] = 
		math.max(farm.stats.npcJobs[npcIndex] - self.config.discMaxJobs, 0)
	else
		farm.stats.npcJobs[npcIndex] = 0 
	end
end
function farmlandManagerSaveToXMLFile(self, superf, xmlFilename)
	if superf(self, xmlFilename) then
		local xmlFile = XMLFile.load("farmlandsXML", xmlFilename, "farmlands")
		if xmlFile == nil then return false end 

		xmlFile:iterate("farmlands.farmland", function(index,  key)
			local id = xmlFile:getInt(key.."#id")
			local farmland = self.farmlands[id]
			if farmland ~= nil then 
				xmlFile:setInt(key.."#npcIndex", farmland.npcIndex)
			end
		end)

		xmlFile:save()
		xmlFile:delete()
		return true
	end
	return false
end
----------------------------------------
function renderIcon(self, x, y, rot)
	-- appended to FieldHotspot:render()
	if self.field == nil or self.name == "" then return end 

	local bc = BetterContracts
	local mission = bc.fieldToMission[self.field.fieldId]
	if mission ~= nil then 
		local typeName = mission.type.name 
		-- only show if Details on and mission type not filtered off
		if not bc.isOn or not bc.filterState[typeName] then return end 

		-- select icon:
		local icon = bc.missionIcons[typeName]
		local other 
		if icon == nil then 
			if typeName == "cultivate"  or typeName=="roll" then other = "plow" 
			elseif typeName=="spray" or typeName=="lime" then other = "fertilize"
			elseif typeName=="chaff" then other = "harvest"
			elseif typeName=="mow_bale" then 
				other = "hay"
				if mission.fillType == FillType.SILAGE then other = "silage"
				end
			end
			assert(other~=nil, "*Error: no icon found for mission type "..typeName)
			icon = bc.missionIcons[other]
		end
		local r, g, b, a = unpack(self.color)
		local alpha = 1
		if self.isBlinking then
			alpha = IngameMap.alpha
		end
		local offx = 11 / g_screenWidth * self.scale
		local offy = 11 / g_screenHeight* self.scale
		icon:setPosition(x + offx, y + offy)
		--icon:setColor(r, g, b, a * alpha)
		icon:setScale(self.scale, self.scale)
		icon:render()
	end
end

function harvestCompleteField(self)
	-- prepended to HarvestMission:completeField()
	if not BetterContracts.config.forcePlow then return end
	
	local ft = g_fruitTypeManager:getFruitTypeByIndex(self.field.fruitType)
	if string.find("MAIZE POTATO SUGARBEET", ft.name) then 
		self.fieldPlowFactor = 0 -- force plowing after root crop harvest
	end
end
