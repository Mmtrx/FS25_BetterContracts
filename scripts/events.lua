--=======================================================================================================
-- BetterContracts EVENTS
--
-- Purpose:     Enhance ingame contracts menu.
-- Functions:   events for: New contracts, Clear contracts, Change a setting
-- Author:      Mmtrx
-- Changelog:
--  v1.0.0.0    28.10.2024  1st port to FS25
--  v1.2.0.0    12.05.2025  New: leased vehicle selection dialog
--=======================================================================================================

--------------------- ClearEvent ------------------------------------------------------------------------ 
BetterContractsClearEvent = {}
BetterContractsClearEvent_mt = Class(BetterContractsClearEvent, Event)
InitEventClass(BetterContractsClearEvent, "BetterContractsClearEvent")

function BetterContractsClearEvent.emptyNew()
	local o = Event.new(BetterContractsClearEvent_mt)
	o.className = "BetterContractsClearEvent"
	return o
end
function BetterContractsClearEvent.new()
	local o = BetterContractsClearEvent.emptyNew()
	return o
end
function BetterContractsClearEvent:writeStream(_, _)
end
function BetterContractsClearEvent:readStream(_, connection)
	self:run(connection)
end
function BetterContractsClearEvent:run(connection)
	if g_server ~= nil and connection:getIsServer() == false then
		-- if the event is coming from a client, server have only to broadcast
		BetterContractsClearEvent.sendEvent()
	else
		-- if the event is coming from the server, both clients and server have to delete old contracts
		-- remove only inactive (status == 0) missions
		local missionsToDelete = {}

		for i, mission in ipairs(g_missionManager.missions) do
			if mission.status == MissionStatus.CREATED then
				missionsToDelete[i] = mission
			end
		end

		debugPrint("BetterContracts deleting missions:" )
		for i, mission in pairs(missionsToDelete) do
			debugPrint(" %02d %14s %d", i, mission.title, mission:getReward())
			mission:delete()
		end

		if g_inGameMenu.isOpen and g_inGameMenu.pageContracts.visible then
			--g_inGameMenu.pageContracts:setButtonsForState()
			g_inGameMenu.pageContracts:updateList()
		end
	end
end
function BetterContractsClearEvent.sendEvent()
	local event = BetterContractsClearEvent.new()
	if g_server ~= nil then
		-- server have to broadcast to all clients and himself
		g_server:broadcastEvent(event, true)
	else
		-- clients have to send to server
		g_client:getServerConnection():sendEvent(event)
	end
end

--------------------- NewEvent ------------------------------------------------------------------------- 
BetterContractsNewEvent = {}
BetterContractsNewEvent_mt = Class(BetterContractsNewEvent, Event)
InitEventClass(BetterContractsNewEvent, "BetterContractsNewEvent")

function BetterContractsNewEvent.emptyNew()
	local o = Event.new(BetterContractsNewEvent_mt)
	o.className = "BetterContractsNewEvent"
	return o
end
function BetterContractsNewEvent.new()
	local o = BetterContractsNewEvent.emptyNew()
	return o
end
function BetterContractsNewEvent:writeStream(_, _)
end
function BetterContractsNewEvent:readStream(_, connection)
	self:run(connection)
end

function BetterContractsNewEvent:run(_)
	if g_server ~= nil then
		debugPrint("** run Missions NewEvent")
		g_missionManager:startMissionGeneration()
	end
end
function BetterContractsNewEvent.sendEvent()
	g_client:getServerConnection():sendEvent(BetterContractsNewEvent.new())
end

--------------------- SettingsEvent -------------------------------------------------------------------- 
SettingsEvent = {}
SettingsEvent_mt = Class(SettingsEvent, Event)
InitEventClass(SettingsEvent, "SettingsEvent")

function SettingsEvent.emptyNew()
	return Event.new(SettingsEvent_mt)
end
function SettingsEvent.new(setting)
	local o = SettingsEvent.emptyNew()
	o.setting = setting
	return o
end
function SettingsEvent:writeStream(streamId, connection)
	streamWriteString(streamId,self.setting.name)
	self.setting:writeStream(streamId, connection)
end
function SettingsEvent:readStream(streamId, connection)
	local name = streamReadString(streamId)
	local setting = BetterContracts.settingsMgr.settingsByName[name]
	setting:readStream(streamId, connection)
	self:run(connection, setting)
end
function SettingsEvent:run(connection, setting)
	--- If we received this from a client, forward to other clients
	if not connection:getIsServer() then
		-- ignore self (connection)
		g_server:broadcastEvent(SettingsEvent.new(setting), nil, connection, nil)
	end
end
function SettingsEvent.sendEvent(setting)
	if g_server ~= nil then
		-- send to all clients
		g_server:broadcastEvent(SettingsEvent.new(setting))
	else -- send to Server
		g_client:getServerConnection():sendEvent(SettingsEvent.new(setting))
	end
end

--------------------- Change Vehicles Event ------------------------------------------------------------- 
ChangeVecEvent = {}
ChangeVecEvent_mt = Class(ChangeVecEvent, Event)
InitEventClass(ChangeVecEvent, "ChangeVecEvent")

function ChangeVecEvent.emptyNew()
	return Event.new(ChangeVecEvent_mt)
end
function ChangeVecEvent.new(mission, groupId)
	local o = ChangeVecEvent.emptyNew()
	o.mission = mission
	o.groupId = groupId
	return o
end
function ChangeVecEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.mission)
	streamWriteUInt8(streamId, self.groupId)
end
function ChangeVecEvent:readStream(streamId, connection)
	self.mission = NetworkUtil.readNodeObject(streamId)
	self.groupId = streamReadUInt8(streamId)
	self:run(connection)
end
function ChangeVecEvent:run(connection)
	-- will update mission vecs on server, event came from client
	local isServer = g_currentMission:getIsServer()
	assert(isServer, "BetterContracts: ChangeVecEvent:run() is a server-only function")
	assert(not connection:getIsServer(), "BetterContracts: ChangeVecEvent should only come from clients")
	-- set the missions vehicles
	local m = self.mission
	local ix = self.groupId
	local vecSelect = BetterContracts.vehicleSelect 
	vecSelect:getGroups(m)
	m.vehiclesToLoad = vecSelect.groups[ix].vehicles
	m.vehicleGroupIdentifier = vecSelect.groups[ix].identifier
	m:prepare(true)  	-- spawns mission vehicles
	debugPrint("** ChangeVecEvent.run() spawned new mission vecs **")

	m:raiseActive()
	-- inform client about mission start ok. No need to inform other clients, since this mission was just taken
	connection:sendEvent(MissionStartEvent.newServerToClient(MissionStartState.OK,true))
end
function ChangeVecEvent.sendEvent(m, groupId)
	--debugPrint("** send event: %s %s", m.getTitle and m:getTitle(), groupId)
	local event = ChangeVecEvent.new(m, groupId)
	if g_client ~= nil then
		-- only clients send to server
		g_client:getServerConnection():sendEvent(event)
	end
end

--------------------- LeasedVecsEvent ------------------------------------------------------------------------- 
-- MP only: inform client about leased mission vehicles, when a new mission starts,
-- or an active mission with spawned vehicles was loaded from savegame
LeasedVecsEvent = {}
LeasedVecsEvent_mt = Class(LeasedVecsEvent, Event)
InitEventClass(LeasedVecsEvent, "LeasedVecsEvent")

function LeasedVecsEvent.emptyNew()
	local o = Event.new(LeasedVecsEvent_mt)
	o.className = "LeasedVecsEvent"
	return o
end
function LeasedVecsEvent.new(mission, vehicles)
	local o = LeasedVecsEvent.emptyNew()
	o.mission = mission
	o.vehicles = vehicles
	return o
end
function LeasedVecsEvent:writeStream(streamId, connection)
	debugPrint("* write %s, %d vehicles:", self.mission:getTitle(), #self.vehicles)
	NetworkUtil.writeNodeObject(streamId, self.mission)
	streamWriteUInt8(streamId, #self.vehicles)
	for _, vec in ipairs(self.vehicles) do
		debugPrint("** %s",vec:getFullName())
		NetworkUtil.writeNodeObject(streamId, vec)
	end
end
function LeasedVecsEvent:readStream(streamId, connection)
	self.mission = NetworkUtil.readNodeObject(streamId)
	local count = streamReadUInt8(streamId)
	--debugPrint("* read %s with %d vehicles",self.mission:getTitle(), count)
	self.vehicles = {}
	for _ = 1, count do
		local vecId = NetworkUtil.readNodeObjectId(streamId)
		table.insert(self.vehicles, vecId)
	end
	self:run(connection)
end

function LeasedVecsEvent:run(connection)
	if g_client ~= nil and connection:getIsServer() then
		local m = self.mission
		debugPrint("** received mission %s with %d vehicle Ids", 
			m.getTitle and m:getTitle() or "nil", #self.vehicles)
		-- save mission type / field for vehicle name
		BetterContracts:vehicleTag(m, self.vehicles)
	end
end
function LeasedVecsEvent.sendEvent(mission, vehicles, connection)
	if g_server ~= nil then
		if connection ~= nil then 
			connection:sendEvent(LeasedVecsEvent.new(mission, vehicles))
		else
	-- send to all clients. Send to self only if single player
			g_server:broadcastEvent(LeasedVecsEvent.new(mission, vehicles),
				not g_currentMission.missionDynamicInfo.isMultiplayer)
		end
	end
end
