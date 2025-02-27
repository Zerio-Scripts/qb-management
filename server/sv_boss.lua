local QBCore = exports['qb-core']:GetCoreObject()

function ExploitBan(id, reason)
	MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
		GetPlayerName(id),
		QBCore.Functions.GetIdentifier(id, 'license'),
		QBCore.Functions.GetIdentifier(id, 'discord'),
		QBCore.Functions.GetIdentifier(id, 'ip'),
		reason,
		2147483647,
		'qb-management'
	})
	TriggerEvent('qb-log:server:CreateLog', 'bans', 'Player Banned', 'red', string.format('%s was banned by %s for %s', GetPlayerName(id), 'qb-management', reason), true)
	DropPlayer(id, 'You were permanently banned by the server for: Exploiting')
end

-- Get Employees
QBCore.Functions.CreateCallback('qb-bossmenu:server:GetEmployees', function(source, cb, jobname)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)

	if not Player.PlayerData.job.isboss then
		ExploitBan(src, 'GetEmployees Exploiting')
		return
	end

	local employees = {}
	local players = exports["zerio-multijobs"]:GetPlayersWithJob(jobname)

	for _, value in pairs(players) do
		local Target = QBCore.Functions.GetPlayerByCitizenId(value.identifier)

		if not Target then
			Target = QBCore.Functions.GetOfflinePlayerByCitizenId(value.identifier)
		end

		if Target then
			local isOnline = type(Target.PlayerData.source) == "number"
			local gradeData = nil

			if QBCore.Shared.Jobs[jobname] and QBCore.Shared.Jobs[jobname].grades[tostring(value.grade)] then
				gradeData = QBCore.Shared.Jobs[jobname].grades[tostring(value.grade)]
			end

			if gradeData then
				gradeData.level = value.grade
				employees[#employees + 1] = {
					empSource = Target.PlayerData.citizenid,
					grade = gradeData,
					isboss = Target.PlayerData.job.isboss,
					name = (isOnline and '🟢 ' or '❌ ') .. Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname
				}
			else
				warn("Player", value.identifier, "has an invalid job", jobname, value.grade)
			end
		end
	end
	table.sort(employees, function(a, b)
		return a.grade.level > b.grade.level
	end)
	cb(employees)
end)

RegisterNetEvent('qb-bossmenu:server:stash', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	local playerJob = Player.PlayerData.job
	if not playerJob.isboss then return end
	local playerPed = GetPlayerPed(src)
	local playerCoords = GetEntityCoords(playerPed)
	if not Config.BossMenus[playerJob.name] then return end
	local bossCoords = Config.BossMenus[playerJob.name]
	for i = 1, #bossCoords do
		local coords = bossCoords[i]
		if #(playerCoords - coords) < 2.5 then
			local stashName = 'boss_' .. playerJob.name
			exports['qb-inventory']:OpenInventory(src, stashName, {
				maxweight = 4000000,
				slots = 25,
			})
			return
		end
	end
end)

-- Grade Change
RegisterNetEvent('qb-bossmenu:server:GradeUpdate', function(data)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local Employee = QBCore.Functions.GetPlayerByCitizenId(data.cid) or QBCore.Functions.GetOfflinePlayerByCitizenId(data.cid)

	if not Player.PlayerData.job.isboss then
		ExploitBan(src, 'GradeUpdate Exploiting')
		return
	end
	if data.grade > Player.PlayerData.job.grade.level then
		TriggerClientEvent('QBCore:Notify', src, 'You cannot promote to this rank!', 'error')
		return
	end

	if Employee then
		if Employee.Functions.SetJob(Player.PlayerData.job.name, data.grade) then
			if exports["zerio-multijobs"]:DoesPlayerHaveJob(Employee.PlayerData.citizenid, Player.PlayerData.job.name) then
				exports["zerio-multijobs"]:UpdateJobRank(Employee.PlayerData.citizenid, Player.PlayerData.job.name, data.grade)
			else
				exports["zerio-multijobs"]:AddJob(Employee.PlayerData.citizenid, Player.PlayerData.job.name, data.grade)
			end

			TriggerClientEvent('QBCore:Notify', src, 'Sucessfully promoted!', 'success')
			Employee.Functions.Save()

			if Employee.PlayerData.source then -- Player is online
				TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source, 'You have been promoted to' .. data.gradename .. '.', 'success')
			end
		else
			TriggerClientEvent('QBCore:Notify', src, 'Promotion grade does not exist.', 'error')
		end
	end
	TriggerClientEvent('qb-bossmenu:client:OpenMenu', src)
end)

-- Fire Employee
RegisterNetEvent('qb-bossmenu:server:FireEmployee', function(target)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local Employee = QBCore.Functions.GetPlayerByCitizenId(target) or QBCore.Functions.GetOfflinePlayerByCitizenId(target)

	if not Player.PlayerData.job.isboss then
		ExploitBan(src, 'FireEmployee Exploiting')
		return
	end

	if Employee then
		if target == Player.PlayerData.citizenid then
			TriggerClientEvent('QBCore:Notify', src, 'You can\'t fire yourself', 'error')
			return
		elseif Employee.PlayerData.job.grade.level > Player.PlayerData.job.grade.level then
			TriggerClientEvent('QBCore:Notify', src, 'You cannot fire this citizen!', 'error')
			return
		end
		local jobName = Player.PlayerData.job.name -- cache, incase of firing themself
		if Employee.Functions.SetJob('unemployed', '0') then
			exports["zerio-multijobs"]:RemoveJob(Employee.PlayerData.citizenid, jobName)
			Employee.Functions.Save()
			TriggerClientEvent('QBCore:Notify', src, 'Employee fired!', 'success')
			TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Job Fire', 'red', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' successfully fired ' .. Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.job.name .. ')', false)

			if Employee.PlayerData.source then -- Player is online
				TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source, 'You have been fired! Good luck.', 'error')
			end
		else
			TriggerClientEvent('QBCore:Notify', src, 'Error..', 'error')
		end
	end
	TriggerClientEvent('qb-bossmenu:client:OpenMenu', src)
end)

-- Recruit Player
RegisterNetEvent('qb-bossmenu:server:HireEmployee', function(recruit)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local Target = QBCore.Functions.GetPlayer(recruit)

	if not Player.PlayerData.job.isboss then
		ExploitBan(src, 'HireEmployee Exploiting')
		return
	end

	if Target and Target.Functions.SetJob(Player.PlayerData.job.name, 0) then
		exports["zerio-multijobs"]:AddJob(Target.PlayerData.citizenid, Player.PlayerData.job.name, 0)
		TriggerClientEvent('QBCore:Notify', src, 'You hired ' .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. ' come ' .. Player.PlayerData.job.label .. '', 'success')
		TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, 'You were hired as ' .. Player.PlayerData.job.label .. '', 'success')
		TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Recruit', 'lightgreen', (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) .. ' successfully recruited ' .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. ' (' .. Player.PlayerData.job.name .. ')', false)
	end
	TriggerClientEvent('qb-bossmenu:client:OpenMenu', src)
end)

-- Get closest player sv
QBCore.Functions.CreateCallback('qb-bossmenu:getplayers', function(source, cb)
	local src = source
	local players = {}
	local PlayerPed = GetPlayerPed(src)
	local pCoords = GetEntityCoords(PlayerPed)
	for _, v in pairs(QBCore.Functions.GetPlayers()) do
		local targetped = GetPlayerPed(v)
		local tCoords = GetEntityCoords(targetped)
		local dist = #(pCoords - tCoords)
		if PlayerPed ~= targetped and dist < 10 then
			local ped = QBCore.Functions.GetPlayer(v)
			players[#players + 1] = {
				id = v,
				coords = GetEntityCoords(targetped),
				name = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname,
				citizenid = ped.PlayerData.citizenid,
				sources = GetPlayerPed(ped.PlayerData.source),
				sourceplayer = ped.PlayerData.source
			}
		end
	end
	table.sort(players, function(a, b)
		return a.name < b.name
	end)
	cb(players)
end)
