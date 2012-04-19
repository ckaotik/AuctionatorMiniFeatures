-- inspired by LPT's dataminer: (c) 2007 Nymbia.  see LGPLv2.1.txt for full details.
--this tool is run in the lua command line.  http://lua.org
--socket is required for internet data.
--get socket here: http://luaforge.net/projects/luasocket/
--if available, curl will be used, which allows connection re-use

local SOURCE = SOURCE or "data.lua"
local DEBUG = DEBUG or 2
local LOCATION = LOCATION or "eu" -- which battle.net?

local DATASTART = arg[1] and tonumber(arg[1]) or 1
local DATAEND = arg[2] and tonumber(arg[2]) or 70000

local function dprint(dlevel, ...)
	if dlevel and DEBUG >= dlevel then
		print(...)
	end
end

local sets

local json = require("json")
json.register_constant("undefined", json.null)
local url = require("socket.url")
local httptime, httpcount = 0, 0

local function Armory(page, value, filter)
	local escape = url.escape
	local url = {"http://"..LOCATION..".battle.net/api/wow/", page}
	if value then
		url[#url + 1] = "/"
		url[#url + 1] = escape(value)
	end

	return table.concat(url)
end

local getpage
do
	local status, curl = pcall(require, "luacurl")
	if status then
		local write = function (temp, s)
			temp[#temp + 1] = s
			return s:len()
		end
		local c = curl.new()
		function getpage(url)
			dprint(3, "curl", url)
			local temp = {}
			c:setopt(curl.OPT_URL, url)
			c:setopt(curl.OPT_USERAGENT, "Mozilla/5.0") -- needed or item information will be missing
			c:setopt(curl.OPT_WRITEFUNCTION, write)
			c:setopt(curl.OPT_WRITEDATA, temp)
			local stime = os.time()
			local status, info = c:perform()
			httptime = httptime + (os.time() - stime)
			httpcount = httpcount + 1
			if not status then
				dprint(1, "curl error", url, info)
			else
				temp = table.concat(temp)
				if temp:len() > 0 then
					return temp
				end
			end
		end
	else
		local http = require("socket.http")

		function getpage(url)
			dprint(3, "socket.http", url)
			local stime = os.time()
			local r = http.request(url)
			httptime = httptime + (os.time() - stime)
			httpcount = httpcount + 1
			return r
		end
	end
end

local function read_data_file()
	local subset = string.gsub(arg[1] or '','%.','%.')
	local f = assert(io.open(SOURCE, "r"))
	local file = f:read("*all")
	f:close()

	local dataSet, setcount = ""
	-- currently should only create one match
	for data in file:gmatch('addon%.itemBinds = "([^"]-)"') do
		dataSet = data
		setcount = string.len(data or "")
	end

	return file, dataSet, setcount or 0
end

local function update_all_sets(oldData, from, to)
	if not (from and to) then return end

	local sets, setsEnd, data, page = "", "", nil, nil
	if oldData then
		if arg[1] and from == arg[1] then
			dprint(3, "replace")
			-- replace specific parts
			sets = string.sub(oldData, 1, from-1)
			setsEnd = string.sub(oldData, to+1)
		elseif to > string.len(oldData) then
			dprint(3, "continue")
			-- start where we left off
			sets = oldData
			from = string.len(oldData) + 1
		else
			return
		end
	end

	local currentItem, missedItems = from, 0
	while currentItem <= to do
		io.write(".")
		io.flush()
		page = getpage(Armory("item", currentItem))
		if not page then
			dprint(1, "ERROR", currentItem)
			return sets, missedItems
		end
		data = json(page, true)

		if data and data.itemBind then
			dprint(3, data.name .. "\t"..data.itemBind)
			sets = sets .. data.itemBind
		elseif data then
			dprint(3, data.status .. "\t"..data.reason)
			if data.reason ~= "unable to get item information." then
				-- something went horribly wrong, exit prematurely
				dprint(1, "ERROR", currentItem, data.reason)
				return sets, missedItems
			end
			sets = sets .. "."
			missedItems = missedItems + 1
		end
		currentItem = currentItem + 1
	end
	return sets..setsEnd, missedItems
end

local function write_output(file, data)
	if not data then return end
	local f = assert(io.open(SOURCE, "w"))
	for line in file:gmatch('([^\n]-\n)') do
		local oldCount = line:match('addon%.itemBindsCount = ([^\n]-)')
		local oldData = line:match('addon%.itemBinds = "([^"]-)"')
		if oldCount then
			f:write('addon.itemBindsCount = "',string.len(data),'"','\n')
		elseif oldData then
			f:write('addon.itemBinds = "',data,'"','\n')
		else
			f:write(line)
		end
	end
	f:close()
end

local function main()
	local starttime = os.time()

	local file, setcount
	file, sets, setcount = read_data_file()
	print(("%d items in datafile"):format(setcount))
	local sets, notmined = update_all_sets(sets, DATASTART, DATAEND)
	local elapsed = os.time()- starttime
	local cputime = os.clock()
	print()
	print(("Elapsed Time: %dm %ds"):format(elapsed/60, elapsed%60))
	print(("%dm %ds spent servicing %d web requests"):format(httptime/60, httptime%60, httpcount))
	print(("%dm %ds spent in processing data"):format((elapsed-httptime)/60,(elapsed-httptime)%60))
	print(("Approx %dm %.2fs CPU time used"):format(cputime/60, cputime%60))
	if sets then
		print(("%d new sets mined, %d sets not mined."):format(string.len(sets) - setcount - notmined, notmined))
		write_output(file, sets)
	else
		print("ERROR! No data was mined")
	end
end

main()
