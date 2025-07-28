RegisterServerEvent("ot-mdt:Open")
AddEventHandler("ot-mdt:Open", function(type)
	local usource = source
	local user = exports["ot-base"]:getModule("Player"):GetUser(usource)
    local characterId = user:getVar("character").id
	if type == "police" then
		exports.ghmattimysql:execute("SELECT * FROM jobs_whitelist WHERE cid = @cid", {['cid'] = characterId}, function(result)
			if result[1].job == 'police' then
				MySQL.Async.fetchAll("SELECT * FROM (SELECT * FROM `mdt_reports` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(reports)
					for r = 1, #reports do
						reports[r].charges = json.decode(reports[r].charges)
					end
					MySQL.Async.fetchAll("SELECT * FROM (SELECT * FROM `mdt_warrants` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(warrants)
						for w = 1, #warrants do
							warrants[w].charges = json.decode(warrants[w].charges)
						end

						local officer = GetCharacterName(usource)
						TriggerClientEvent('ot-mdt:toggleVisibilty', usource, reports, warrants, officer, "Police")
					end)
				end)
			end
		end)
	elseif type == "DOJ" then
		exports.ghmattimysql:execute("SELECT * FROM character_passes WHERE cid = @cid", {['cid'] = characterId}, function(result2)
			if result2[1].pass_type == 'DOJ' and result2[1].rank >= 0 then
				MySQL.Async.fetchAll("SELECT * FROM (SELECT * FROM `mdt_reports` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(reports)
					for r = 1, #reports do
						reports[r].charges = json.decode(reports[r].charges)
					end
					MySQL.Async.fetchAll("SELECT * FROM (SELECT * FROM `mdt_warrants` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(warrants)
						for w = 1, #warrants do
							warrants[w].charges = json.decode(warrants[w].charges)
						end

						local officer = GetCharacterName(usource)
						TriggerClientEvent('ot-mdt:toggleVisibilty', usource, reports, warrants, officer, "Police")
					end)
				end)
			end
		end)
	end
end)

RegisterServerEvent("ot-mdt:getOffensesAndOfficer")
AddEventHandler("ot-mdt:getOffensesAndOfficer", function()
	local usource = source
	local charges = {}
	MySQL.Async.fetchAll('SELECT * FROM fine_types', {
	}, function(fines)
		for j = 1, #fines do
			if fines[j].category == 0 or fines[j].category == 1 or fines[j].category == 2 or fines[j].category == 3 then
				table.insert(charges, fines[j])
			end
		end

		local officer = GetCharacterName(usource)

		TriggerClientEvent("ot-mdt:returnOffensesAndOfficer", usource, charges, officer)
	end)
end)

RegisterServerEvent("ot-mdt:performOffenderSearch")
AddEventHandler("ot-mdt:performOffenderSearch", function(query)
	local usource = source
	local matches = {}
	MySQL.Async.fetchAll("SELECT * FROM `characters` WHERE LOWER(`first_name`) LIKE @query OR LOWER(`last_name`) LIKE @query OR CONCAT(LOWER(`first_name`), ' ', LOWER(`last_name`)) LIKE @query", {
		['@query'] = string.lower('%'..query..'%') -- % wildcard, needed to search for all alike results
	}, function(result)

		for index, data in ipairs(result) do
			table.insert(matches, data)
		end

		TriggerClientEvent("ot-mdt:returnOffenderSearchResults", usource, matches)
	end)
end)

RegisterServerEvent("ot-mdt:getOffenderDetails")
AddEventHandler("ot-mdt:getOffenderDetails", function(offender)
	local usource = source
	local result = MySQL.Sync.fetchAll('SELECT * FROM `user_mdt` WHERE `char_id` = @id', {
		['@id'] = offender.id
	})
	offender.notes = ""
	offender.mugshot_url = ""
	offender.bail = false
	if result[1] then
		offender.notes = result[1].notes
		offender.mugshot_url = result[1].mugshot_url
		offender.bail = result[1].bail
	end

	local convictions = MySQL.Sync.fetchAll('SELECT * FROM `user_convictions` WHERE `char_id` = @id', {
		['@id'] = offender.id
	})
	if convictions[1] then
		offender.convictions = {}
		for i = 1, #convictions do
			local conviction = convictions[i]
			offender.convictions[conviction.offense] = conviction.count
		end
	end

	local warrants = MySQL.Sync.fetchAll('SELECT * FROM `mdt_warrants` WHERE `char_id` = @id', {
		['@id'] = offender.id
	})
	if warrants[1] then
		offender.haswarrant = true
	end

	local phone_number = MySQL.Sync.fetchAll('SELECT `phone_number` FROM `characters` WHERE `id` = @id', {
		['@id'] = offender.id
	})
	offender.phone_number = phone_number[1].phone_number

	local vehicles = MySQL.Sync.fetchAll('SELECT * FROM `characters_cars` WHERE `cid` = @cid', {
		['@cid'] = offender.id
	})

	for i = 1, #vehicles do
		pVehicleData = json.decode(vehicles[i].data)
		if pVehicleData ~= nil then
			if colors[tostring(pVehicleData.colors[2])] and colors[tostring(pVehicleData.colors[1])] then
				vehicles[i].color = colors[tostring(pVehicleData.colors[2])] .. " on " .. colors[tostring(pVehicleData.colors[1])]
			elseif colors[tostring(vehicles[i].data.cololes[i].data.color2)] then
				vehicles[i].color = colors[tostring(pVehicleData.colors[1])]
			elseif colors[tostring(pVehicleData.colors[2])] then
				vehicles[i].color = colors[tostring(pVehicleData.colors[2])]
				vehicles[i].color = "Unknown"
			end
		else
			vehicles[i].color = "Unknown"
		end
		vehicles[i].data = nil
	end
	offender.vehicles = vehicles

	TriggerClientEvent("ot-mdt:returnOffenderDetails", usource, offender)
end)

RegisterServerEvent("ot-mdt:getOffenderDetailsById")
AddEventHandler("ot-mdt:getOffenderDetailsById", function(char_id)
	local usource = source

	local result = MySQL.Sync.fetchAll('SELECT * FROM `characters` WHERE `id` = @id', {
		['@id'] = char_id
	})
	local offender = result[1]

	if not offender then
		TriggerClientEvent("ot-mdt:closeModal", usource)
		TriggerClientEvent("ot-mdt:sendNotification", usource, "This person no longer exists.")
		return
	end

	local result = MySQL.Sync.fetchAll('SELECT * FROM `user_mdt` WHERE `char_id` = @id', {
		['@id'] = offender.id
	})
	offender.notes = ""
	offender.mugshot_url = ""
	offender.bail = false
	if result[1] then
		offender.notes = result[1].notes
		offender.mugshot_url = result[1].mugshot_url
		offender.bail = result[1].bail
	end

	local convictions = MySQL.Sync.fetchAll('SELECT * FROM `user_convictions` WHERE `char_id` = @id', {
		['@id'] = offender.id
	}) 
	if convictions[1] then
		offender.convictions = {}
		for i = 1, #convictions do
			local conviction = convictions[i]
			offender.convictions[conviction.offense] = conviction.count
		end
	end

	local warrants = MySQL.Sync.fetchAll('SELECT * FROM `mdt_warrants` WHERE `char_id` = @id', {
		['@id'] = offender.id
	})
	if warrants[1] then
		offender.haswarrant = true
	end

	local phone_number = MySQL.Sync.fetchAll('SELECT `phone_number` FROM `characters` WHERE `id` = @id', {
		['@id'] = offender.id
	})
	offender.phone_number = phone_number[1].phone_number

	local vehicles = MySQL.Sync.fetchAll('SELECT * FROM `characters_cars` WHERE `cid` = @cid', {
		['@cid'] = offender.id
	})
	
	for i = 1, #vehicles do
		pVehicleData = json.decode(vehicles[i].data)
		if pVehicleData ~= nil then
			if colors[tostring(pVehicleData.colors[2])] and colors[tostring(pVehicleData.colors[1])] then
				vehicles[i].color = colors[tostring(pVehicleData.colors[2])] .. " on " .. colors[tostring(pVehicleData.colors[1])]
			elseif colors[tostring(vehicles[i].data.cololes[i].data.color2)] then
				vehicles[i].color = colors[tostring(pVehicleData.colors[1])]
			elseif colors[tostring(pVehicleData.colors[2])] then
				vehicles[i].color = colors[tostring(pVehicleData.colors[2])]
				vehicles[i].color = "Unknown"
			end
		else
			vehicles[i].color = "Unknown"
		end
		vehicles[i].data = nil
	end
	offender.vehicles = vehicles

	TriggerClientEvent("ot-mdt:returnOffenderDetails", usource, offender)
end)

RegisterServerEvent("ot-mdt:saveOffenderChanges")
AddEventHandler("ot-mdt:saveOffenderChanges", function(id, changes, identifier)
	local usource = source
	MySQL.Async.fetchAll('SELECT * FROM `user_mdt` WHERE `char_id` = @id', {
		['@id']  = id
	}, function(result)
		if result[1] then
			MySQL.Async.execute('UPDATE `user_mdt` SET `notes` = @notes, `mugshot_url` = @mugshot_url, `bail` = @bail WHERE `char_id` = @id', {
				['@id'] = id,
				['@notes'] = changes.notes,
				['@mugshot_url'] = changes.mugshot_url,
				['@bail'] = changes.bail
			})
		else
			MySQL.Async.insert('INSERT INTO `user_mdt` (`char_id`, `notes`, `mugshot_url`, `bail`) VALUES (@id, @notes, @mugshot_url, @bail)', {
				['@id'] = id,
				['@notes'] = changes.notes,
				['@mugshot_url'] = changes.mugshot_url,
				['@bail'] = changes.bail
			})
		end

		if changes.convictions ~= nil then
			for conviction, amount in pairs(changes.convictions) do	
				MySQL.Async.execute('UPDATE `user_convictions` SET `count` = @count WHERE `char_id` = @id AND `offense` = @offense', {
					['@id'] = id,
					['@count'] = amount,
					['@offense'] = conviction
				})
			end
		end

		for i = 1, #changes.convictions_removed do
			MySQL.Async.execute('DELETE FROM `user_convictions` WHERE `char_id` = @id AND `offense` = @offense', {
				['@id'] = id,
				['offense'] = changes.convictions_removed[i]
			})
		end

		TriggerClientEvent("ot-mdt:sendNotification", usource, "Offender changes have been saved.")
	end)
end)

RegisterServerEvent("ot-mdt:saveReportChanges")
AddEventHandler("ot-mdt:saveReportChanges", function(data)
	MySQL.Async.execute('UPDATE `mdt_reports` SET `title` = @title, `incident` = @incident WHERE `id` = @id', {
		['@id'] = data.id,
		['@title'] = data.title,
		['@incident'] = data.incident
	})
	TriggerClientEvent("ot-mdt:sendNotification", source, "Report changes have been saved.")
end)

RegisterServerEvent("ot-mdt:deleteReport")
AddEventHandler("ot-mdt:deleteReport", function(id)
	MySQL.Async.execute('DELETE FROM `mdt_reports` WHERE `id` = @id', {
		['@id']  = id
	})
	TriggerClientEvent("ot-mdt:sendNotification", source, "Report has been successfully deleted.")
end)

RegisterServerEvent("ot-mdt:submitNewReport")
AddEventHandler("ot-mdt:submitNewReport", function(data)
	local usource = source
	local author = GetCharacterName(source)
	if tonumber(data.sentence) and tonumber(data.sentence) > 0 then
		data.sentence = tonumber(data.sentence)
	else 
		data.sentence = nil
	end
	charges = json.encode(data.charges)
	data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
	MySQL.Async.insert('INSERT INTO `mdt_reports` (`char_id`, `title`, `incident`, `charges`, `author`, `name`, `date`, `jailtime`) VALUES (@id, @title, @incident, @charges, @author, @name, @date, @sentence)', {
		['@id']  = data.char_id,
		['@title'] = data.title,
		['@incident'] = data.incident,
		['@charges'] = charges,
		['@author'] = author,
		['@name'] = data.name,
		['@date'] = data.date,
		['@sentence'] = data.sentence
	}, function(id)
		TriggerEvent("ot-mdt:getReportDetailsById", id, usource)
		TriggerClientEvent("ot-mdt:sendNotification", usource, "A new report has been submitted.")
	end)

	for offense, count in pairs(data.charges) do
		MySQL.Async.fetchAll('SELECT * FROM `user_convictions` WHERE `offense` = @offense AND `char_id` = @id', {
			['@offense'] = offense,
			['@id'] = data.char_id
		}, function(result)
			if result[1] then
				MySQL.Async.execute('UPDATE `user_convictions` SET `count` = @count WHERE `offense` = @offense AND `char_id` = @id', {
					['@id']  = data.char_id,
					['@offense'] = offense,
					['@count'] = count + 1
				})
			else
				MySQL.Async.insert('INSERT INTO `user_convictions` (`char_id`, `offense`, `count`) VALUES (@id, @offense, @count)', {
					['@id']  = data.char_id,
					['@offense'] = offense,
					['@count'] = count
				})
			end
		end)
	end
end)

RegisterServerEvent("ot-mdt:performReportSearch")
AddEventHandler("ot-mdt:performReportSearch", function(query)
	local usource = source
	local matches = {}
	MySQL.Async.fetchAll("SELECT * FROM `mdt_reports` WHERE `id` LIKE @query OR LOWER(`title`) LIKE @query OR LOWER(`name`) LIKE @query OR LOWER(`author`) LIKE @query or LOWER(`charges`) LIKE @query", {
		['@query'] = string.lower('%'..query..'%') -- % wildcard, needed to search for all alike results
	}, function(result)

		for index, data in ipairs(result) do
			data.charges = json.decode(data.charges)
			table.insert(matches, data)
		end

		TriggerClientEvent("ot-mdt:returnReportSearchResults", usource, matches)
	end)
end)

RegisterServerEvent("ot-mdt:performVehicleSearch")
AddEventHandler("ot-mdt:performVehicleSearch", function(pPlateNumber)
	local usource = source
	local matches = {}
	MySQL.Async.fetchAll("SELECT * FROM `characters_cars` WHERE LOWER(`license_plate`) LIKE @query", {
		['@query'] = string.lower('%'..pPlateNumber..'%') -- % wildcard, needed to search for all alike results
	}, function(result)

		for index, pData in ipairs(result) do
			local data_decoded = json.decode(pData.data)
			if data_decoded ~= nil then
				pData.color = colors[tostring(data_decoded.colors[1])]
				if colors[tostring(data_decoded.colors[2])] then
					pData.color = colors[tostring(data_decoded.colors[2])] .. " on " .. colors[tostring( data_decoded.colors[1])]
				end
			end
			table.insert(matches, pData)
		end

		TriggerClientEvent("ot-mdt:returnVehicleSearchResults", usource, matches)
	end)
end)


RegisterServerEvent("ot-mdt:getVehicle")
AddEventHandler("ot-mdt:getVehicle", function(vehicle)
	local usource = source
	local result = MySQL.Sync.fetchAll("SELECT * FROM `characters` WHERE `id` = @query", {
		['@query'] = vehicle.cid
	})
	if result[1] then
		vehicle.cid = result[1].first_name .. ' ' .. result[1].last_name
		vehicle.owner_id = result[1].id
	end

	local data = MySQL.Sync.fetchAll('SELECT * FROM `vehicle_mdt` WHERE `plate` = @plate', {
		['@plate'] = vehicle.plate
	})
	if data[1] then
		if data[1].stolen == 1 then vehicle.stolen = true else vehicle.stolen = false end
		if data[1].notes ~= null then vehicle.notes = data[1].notes else vehicle.notes = '' end
	else
		vehicle.stolen = false
		vehicle.notes = ''
	end

	local warrants = MySQL.Sync.fetchAll('SELECT * FROM `mdt_warrants` WHERE `char_id` = @id', {
		['@id'] = vehicle.owner_id
	})
	if warrants[1] then
		vehicle.haswarrant = true
	end

	local bail = MySQL.Sync.fetchAll('SELECT `bail` FROM user_mdt WHERE `char_id` = @id', {
		['@id'] = vehicle.owner_id
	})
	if bail and bail[1] and bail[1].bail == 1 then vehicle.bail = true else vehicle.bail = false end

	vehicle.type = types[vehicle.type]
	TriggerClientEvent("ot-mdt:returnVehicleDetails", usource, vehicle)
end)

RegisterServerEvent("ot-mdt:getWarrants")
AddEventHandler("ot-mdt:getWarrants", function()
	local usource = source
	MySQL.Async.fetchAll("SELECT * FROM `mdt_warrants`", {}, function(warrants)
		for i = 1, #warrants do
			warrants[i].expire_time = ""
			warrants[i].charges = json.decode(warrants[i].charges)
		end
		TriggerClientEvent("ot-mdt:returnWarrants", usource, warrants)
	end)
end)

RegisterServerEvent("ot-mdt:submitNewWarrant")
AddEventHandler("ot-mdt:submitNewWarrant", function(data)
	local usource = source
	data.charges = json.encode(data.charges)
	data.author = GetCharacterName(source)
	data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
	MySQL.Async.insert('INSERT INTO `mdt_warrants` (`name`, `char_id`, `report_id`, `report_title`, `charges`, `date`, `expire`, `notes`, `author`) VALUES (@name, @char_id, @report_id, @report_title, @charges, @date, @expire, @notes, @author)', {
		['@name']  = data.name,
		['@char_id'] = data.char_id,
		['@report_id'] = data.report_id,
		['@report_title'] = data.report_title,
		['@charges'] = data.charges,
		['@date'] = data.date,
		['@expire'] = data.expire,
		['@notes'] = data.notes,
		['@author'] = data.author
	}, function()
		TriggerClientEvent("ot-mdt:completedWarrantAction", usource)
		TriggerClientEvent("ot-mdt:sendNotification", usource, "A new warrant has been created.")
	end)
end)

RegisterServerEvent("ot-mdt:deleteWarrant")
AddEventHandler("ot-mdt:deleteWarrant", function(id)
	local usource = source
	MySQL.Async.execute('DELETE FROM `mdt_warrants` WHERE `id` = @id', {
		['@id']  = id
	}, function()
		TriggerClientEvent("ot-mdt:completedWarrantAction", usource)
	end)
	TriggerClientEvent("ot-mdt:sendNotification", usource, "Warrant has been successfully deleted.")
end)

RegisterServerEvent("ot-mdt:getReportDetailsById")
AddEventHandler("ot-mdt:getReportDetailsById", function(query, _source)
	if _source then source = _source end
	local usource = source
	MySQL.Async.fetchAll("SELECT * FROM `mdt_reports` WHERE `id` = @query", {
		['@query'] = query
	}, function(result)
		if result and result[1] then
			result[1].charges = json.decode(result[1].charges)
			TriggerClientEvent("ot-mdt:returnReportDetails", usource, result[1])
		else
			TriggerClientEvent("ot-mdt:closeModal", usource)
			TriggerClientEvent("ot-mdt:sendNotification", usource, "This report cannot be found.")
		end
	end)
end)

RegisterServerEvent("ot-mdt:saveVehicleChanges")
AddEventHandler("ot-mdt:saveVehicleChanges", function(data)
	if data.stolen then data.stolen = 1 else data.stolen = 0 end
	local usource = source
	MySQL.Async.fetchAll('SELECT * FROM `vehicle_mdt` WHERE `plate` = @plate', {
		['@plate'] = plate
	}, function(result)
		if result[1] then
			MySQL.Async.execute('UPDATE `vehicle_mdt` SET `stolen` = @stolen, `notes` = @notes WHERE `plate` = @plate', {
				['@plate'] = data.plate,
				['@stolen'] = data.stolen,
				['@notes'] = data.notes
			})
		else
			MySQL.Async.insert('INSERT INTO `vehicle_mdt` (`plate`, `stolen`, `notes`) VALUES (@plate, @stolen, @notes)', {
				['@plate'] = data.plate,
				['@stolen'] = data.stolen,
				['@notes'] = data.notes
			})
		end
		
		TriggerClientEvent("ot-mdt:sendNotification", usource, "Vehicle changes have been saved.")
	end)
end)

function GetCharacterName(source)
	local user = exports["ot-base"]:getModule("Player"):GetUser(source)
	if user ~= false then
		local characterId = user:getVar("character").id
		local result = MySQL.Sync.fetchAll('SELECT first_name, last_name FROM characters WHERE id = @id', {
			['@id'] = characterId
		})

		if result[1] and result[1].first_name and result[1].last_name then
			return ('%s %s'):format(result[1].first_name, result[1].last_name)
		end
	end
end

