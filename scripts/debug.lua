--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:		Enhance ingame contracts menu.
-- Author:		Royal-Modding / Mmtrx
-- Changelog:
--  v1.0.0.0	19.10.2020	initial by Royal-Modding
--	v1.1.0.0	12.04.2021	release candidate RC-2
--  v1.1.0.3    24.04.2021  (Mmtrx) gui enhancements: addtl details, sort buttons
--  v1.1.0.4    07.07.2021  (Mmtrx) add user-defined missionVehicles.xml, allow missions with no vehicles
--  v1.2.0.0    18.01.2022  (Mmtrx) adapt for FS22
--   		    13.04.2022  moved restartGame() to DebugCommands
--  v1.2.7.5	26.02.2023	display other farms active contracts (MP only)
--=======================================================================================================

-------------------- v1.2.7.5 functions for mTable --------------------------------------------------
function BetterContracts:bcMissions()
	-- print all active missions (only in debug mode)
	print(string.format("%10s %10s %5s %10s %5s", "Farm","Contract","Field","Fruit","Compl"))
	local data = self:getMData()
	for _,row in ipairs(data) do
		print(string.format("%10s %10s %5s %10s %5s", 
			row.c1, row.c2, row.c3, row.c4, row.c5))
	end
end
function BetterContracts:getMData(notMy)
	-- return data rows for other farms mission table
	-- {c1="MyFarm",c2="Düngen",c3=14,c4="Gerste", c5="22%"}
	local fmissions, data = {}, {}
	local myId = g_currentMission.player.farmId or 0
	for _, farm in ipairs(g_farmManager:getFarms()) do
		if not (notMy and farm.farmId == myId) then
			fmissions = table.ifilter(g_missionManager:getMissionsList(farm.farmId), function(m)
				return m.status == AbstractMission.STATUS_RUNNING or 
					m.status == AbstractMission.STATUS_FINISHED
				end)
			for _, m in ipairs(fmissions) do
				local jobName = self.jobText[m.type.name]
				if jobName==nil then jobName = g_i18n:getText("bc_other") end
				local progress = string.format("%d%%", MathUtil.round(m:getCompletion()*100))
				local fruitName = "n/a" 
				local fieldId = "n/a"
				if m.field then fieldId = m.field.fieldId end
				if table.hasElement({"harvest","mow_bale","supplyTransport"}, m.type.name) then 
					fruitName = self.ft[m.fillType].title
				elseif m.field and m.field.fruitType then 
					local ft = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(m.field.fruitType)
					fruitName = self.ft[ft].title
				end 
				local row = {
					c1 = farm.name,
					c2 = jobName,
					c3 = fieldId,
					c4 = fruitName,
					c5 = progress,
				}
				table.insert(data, row)
			end
		end
	end
	return data
end
function testData(self)
	return {
		{c1="MyFarm",c2="Düngen",c4="Gerste",	 c3=14,	c5=22},
		{c1="MyFarm",c2="Ernten",c4="Weizen",	 c3=18,	c5=11},
		{c1="Hof-2", c2="Düngen",c4="Bohnen",	 c3=5, 	c5=100},
		{c1="Hof 3", c2="Düngen",c4="Kartoffeln",c3=37,	c5=80},
		{c1="Hof 3", c2="Kalken",c4="n/a",		 c3=114,c5=0},
		{c1="Hof-2", c2="Düngen",c4="Bohnen",	 c3=5, 	c5=100},
		{c1="Hof 3", c2="Düngen",c4="Kartoffeln",c3=37,	c5=80},
		{c1="Hof 3", c2="Kalken",c4="n/a",		 c3=114,c5=0},
	}
end
function updateMTable(self)
	-- update missions table
	local bt = self.my.mTable
	bt:clearData()
	local mData = self:getMData(true)
	for i=1, #mData do
		self:buildRow(bt, bt.columnNames, mData[i])
	end
	bt:updateView(true)
end
function BetterContracts:buildRow(bt, cols, values)
	-- adds a row to table bt, inits col cells to values 
	-- bt.columnnames = {"c1","c2","c3","c4","c5"}
	-- local id = string.combine(values.c1:split(" "),"") -- id only optional for new row
	local row = TableElement.DataRow.new(nil, cols )
	bt:addRow(row) 		-- this makes bt.data[bt.numActiveRows] = row
	local ixRow = bt.numActiveRows
	for c, value in pairs(values) do 
		bt:setCellText(ixRow, cols[c], tostring(value))
	end
end
------------------------------------------------------------------------------------------
