if _G.__FishItTrackStatRunning then return end
_G.__FishItTrackStatRunning = true

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local API_KEY = _G.FISHIT_API_KEY or (getgenv and getgenv().FISHIT_API_KEY)
local API_URL = _G.FISHIT_API_URL or (getgenv and getgenv().FISHIT_API_URL) or "https://stats.zetsu.lol/api"

local HEARTBEAT_INTERVAL = 45 + math.random(0, 5)
local SNAPSHOT_MAX_INTERVAL = 900 + math.random(0, 30)
local SNAPSHOT_CHECK_INTERVAL = 180

local function notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = text, Duration = 8})
    end)
end

if not API_KEY or API_KEY == "" then
    notify("FishIt TrackStat", "Set _G.FISHIT_API_KEY before loadstring")
    warn("[FishIt TrackStat] Missing API key")
    return
end

local function httpRequest(options)
    local fn = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    if not fn then return false, "No HTTP request function" end
    local ok, response = pcall(fn, options)
    if not ok then return false, tostring(response) end
    local code = response.StatusCode or response.status_code or 0
    if code < 200 or code >= 300 then
        return false, "HTTP " .. tostring(code) .. ": " .. tostring(response.Body or response.body or "")
    end
    return true, response
end

local function post(path, payload)
    payload.apiKey = API_KEY
    local body = HttpService:JSONEncode(payload)
    return httpRequest({
        Url = API_URL .. path,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["X-API-Key"] = API_KEY,
        },
        Body = body,
    })
end

local function loadPlayerData()
    local packages = ReplicatedStorage:FindFirstChild("Packages")
    local replionMod = packages and packages:FindFirstChild("Replion")
    if not replionMod then return nil, nil, "Replion not found" end
    local ok, Replion = pcall(require, replionMod)
    if not ok or not Replion then return nil, nil, "Replion require failed" end
    local PD = Replion.Client:WaitReplion("Data")
    if not PD then return nil, nil, "Data replion not found" end
    local raw = PD.Data or {}
    local okInv, inv = pcall(function() return PD:GetExpect("Inventory") end)
    if not okInv then inv = nil end
    return raw, inv, nil
end

local function buildCatalog()
    local catalog = {}
    local function addModule(mod, categoryHint)
        local ok, data = pcall(require, mod)
        if ok and type(data) == "table" then
            local src = data.Data or data
            if src.Id then
                table.insert(catalog, {
                    id = src.Id,
                    name = src.Name or mod.Name or ("ID:" .. tostring(src.Id)),
                    tier = src.Tier,
                    icon = src.Icon,
                    itemType = src.Type or data.Type or categoryHint,
                    category = categoryHint,
                })
            end
        end
    end
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    if itemsFolder then
        for _, subfolder in ipairs(itemsFolder:GetChildren()) do
            if subfolder:IsA("Folder") then
                for _, mod in ipairs(subfolder:GetDescendants()) do
                    if mod:IsA("ModuleScript") then
                        addModule(mod, subfolder.Name)
                    end
                end
            end
        end
    end
    local baitsFolder = ReplicatedStorage:FindFirstChild("Baits")
    if baitsFolder then
        for _, mod in ipairs(baitsFolder:GetDescendants()) do
            if mod:IsA("ModuleScript") then
                addModule(mod, "Baits")
            end
        end
        if baitsFolder:IsA("ModuleScript") then
            addModule(baitsFolder, "Baits")
        end
    end
    return catalog
end

local function buildEnchantCatalog()
    local enchants = {
        [1] = "Glistening I", ["1"] = "Glistening I",
        [2] = "Reeler I", ["2"] = "Reeler I",
        [3] = "Big Hunter I", ["3"] = "Big Hunter I",
        [4] = "Gold Digger I", ["4"] = "Gold Digger I",
        [5] = "Leprechaun I", ["5"] = "Leprechaun I",
        [6] = "Leprechaun II", ["6"] = "Leprechaun II",
        [7] = "Mutation Hunter I", ["7"] = "Mutation Hunter I",
        [8] = "Stargazer I", ["8"] = "Stargazer I",
        [9] = "Empowered I", ["9"] = "Empowered I",
        [10] = "XPerienced I", ["10"] = "XPerienced I",
        [11] = "Stormhunter I", ["11"] = "Stormhunter I",
        [12] = "Cursed I", ["12"] = "Cursed I",
        [13] = "Prismatic I", ["13"] = "Prismatic I",
        [14] = "Mutation Hunter II", ["14"] = "Mutation Hunter II",
        [15] = "Perfection", ["15"] = "Perfection",
        [16] = "SECRET Hunter", ["16"] = "SECRET Hunter",
        [17] = "Stargazer II", ["17"] = "Stargazer II",
        [18] = "Fairy Hunter", ["18"] = "Fairy Hunter",
        [19] = "Stormhunter II", ["19"] = "Stormhunter II",
        [20] = "Shark Hunter I", ["20"] = "Shark Hunter I",
        [21] = "Reeler II", ["21"] = "Reeler II",
        [22] = "Mutation Hunter III", ["22"] = "Mutation Hunter III",
        [23] = "Blob Hunter", ["23"] = "Blob Hunter",
        [24] = "Glistening II", ["24"] = "Glistening II",
        [25] = "Lovestruck", ["25"] = "Lovestruck",
        [26] = "More Hearts", ["26"] = "More Hearts",
        [27] = "Dynamic Duo", ["27"] = "Dynamic Duo",
        [28] = "Heartbreaker", ["28"] = "Heartbreaker",
        [29] = "FORGOTTEN Hunter", ["29"] = "FORGOTTEN Hunter",
        [30] = "Incubator", ["30"] = "Incubator",
        [31] = "Easter Spirit", ["31"] = "Easter Spirit",
        [32] = "Empowered II", ["32"] = "Empowered II",
        [33] = "Cursed II", ["33"] = "Cursed II",
        [34] = "Shark Hunter II", ["34"] = "Shark Hunter II",
        [35] = "XPerienced II", ["35"] = "XPerienced II",
    }
    for _, mod in ipairs(ReplicatedStorage:GetDescendants()) do
        if mod:IsA("ModuleScript") then
            local path = mod:GetFullName():lower()
            if path:find("enchant") then
                local ok, data = pcall(require, mod)
                if ok and type(data) == "table" then
                    local src = data.Data or data
                    local id = src.Id or src.EnchantId or data.Id
                    if id then
                        enchants[id] = src.Name or data.Name or mod.Name or ("Enchant " .. tostring(id))
                        enchants[tostring(id)] = enchants[id]
                    end
                    for key, value in pairs(data) do
                        if type(value) == "table" then
                            local child = value.Data or value
                            local childId = child.Id or child.EnchantId or value.Id
                            if childId then
                                enchants[childId] = child.Name or value.Name or tostring(key)
                                enchants[tostring(childId)] = enchants[childId]
                            end
                        end
                    end
                end
            end
        end
    end
    return enchants
end

local catalogById = {}
local catalogByCategoryId = {}
local enchantById = {}
local function rememberCategoryInfo(category, id, item)
    if not category or not id then return end
    catalogByCategoryId[category] = catalogByCategoryId[category] or {}
    catalogByCategoryId[category][id] = item
    catalogByCategoryId[category][tostring(id)] = item
end

local function refreshCatalogMaps(catalog)
    catalogById = {}
    catalogByCategoryId = {}
    for _, item in ipairs(catalog) do
        catalogById[item.id] = item
        catalogById[tostring(item.id)] = item
        rememberCategoryInfo(item.category, item.id, item)
        rememberCategoryInfo(item.itemType, item.id, item)
    end
    enchantById = buildEnchantCatalog()
end

local function itemInfo(item, category)
    if not item then return {} end
    if category and catalogByCategoryId[category] and catalogByCategoryId[category][item.Id] then
        return catalogByCategoryId[category][item.Id]
    end
    return catalogById[item.Id] or {}
end

--[[ legacy body removed by category-aware catalog maps
            for _, mod in ipairs(subfolder:GetDescendants()) do
                if mod:IsA("ModuleScript") then
                    local ok, data = pcall(require, mod)
                    if ok and type(data) == "table" then
                        local src = data.Data or data
                        if src.Id then
                            table.insert(catalog, {
                                id = src.Id,
                                name = src.Name or mod.Name or ("ID:" .. tostring(src.Id)),
                                tier = src.Tier,
                                icon = src.Icon,
                                itemType = src.Type or data.Type,
                            })
                        end
                    end
                end
            end
        end
    end
]]

local function findEquippedRod(raw, inv)
    local equipped = {}
    for _, uuid in ipairs(raw.EquippedItems or {}) do
        if type(uuid) == "string" then equipped[uuid] = true end
    end
    for _, rod in ipairs((inv and inv["Fishing Rods"]) or {}) do
        if type(rod) == "table" and rod.UUID and equipped[rod.UUID] then
            local info = itemInfo(rod, "Fishing Rods")
            return {rod.Id, info and info.name or ("ID:" .. tostring(rod.Id)), info and info.tier or 0, info and info.icon or "", rod.UUID, rod}
        end
    end
    return nil
end

local function normalizeItemType(value)
    local text = tostring(value or "item")
    text = text:gsub("%s+", " ")
    local lower = text:lower()
    if lower:find("rod") then return "rod" end
    if lower:find("bait") then return "bait" end
    if lower:find("stone") or lower:find("enchant") then return "stone" end
    if lower:find("gem") or lower:find("ruby") or lower:find("diamond") then return "gem" end
    if lower:find("gear") or lower:find("charm") or lower:find("artifact") or lower:find("key") then return "gear" end
    if lower:find("fish") then return "fish" end
    return lower
end

local function equippedUuidSet(raw)
    local equipped = {}
    for _, uuid in ipairs(raw.EquippedItems or {}) do
        if type(uuid) == "string" then equipped[uuid] = true end
    end
    return equipped
end

local function equippedFromCategory(raw, inv, categoryNames)
    local equipped = equippedUuidSet(raw)
    for _, category in ipairs(categoryNames) do
        for _, item in ipairs((inv and inv[category]) or {}) do
            if type(item) == "table" and item.UUID and equipped[item.UUID] then
                local info = itemInfo(item, category)
                return info.name or info.Name or ("ID:" .. tostring(item.Id))
            end
        end
    end
    return nil
end

local function readFirst(raw, keys)
    for _, key in ipairs(keys) do
        local value = raw[key]
        if value ~= nil then
            if type(value) == "table" then
                return value.Name or value.name or value.Id or value.id or value.Value or value.value
            end
            return value
        end
    end
    return nil
end

local function collectMeta(raw, inv)
	local location = raw.SavedLocation or (type(raw.Analytics) == "table" and raw.Analytics.LastLocation) or nil
	local lastLocation = type(raw.Analytics) == "table" and raw.Analytics.LastLocation or nil
	local baitId = raw.EquippedBaitId
	local baitSkinId = raw.EquippedBaitSkinId
	local baitInfo = baitId and catalogByCategoryId.Baits and catalogByCategoryId.Baits[baitId] or nil
	local baitName = baitInfo and baitInfo.name or nil
	local baitIcon = baitInfo and baitInfo.icon or nil
	local abilities = type(raw.Abilities) == "table" and raw.Abilities or {}
	local abilityUuid = abilities.Equipped
	local abilityName = nil
	local abilityRolls = abilities.CurrentRolls
	local abilityShards = abilities.Shards
	if abilityUuid and type(abilities.Inventory) == "table" then
		for _, a in ipairs(abilities.Inventory) do
			if type(a) == "table" and a.UUID == abilityUuid then
				abilityName = a.Name
				break
			end
		end
	end
	local rod = findEquippedRod(raw, inv)
	local rodId = rod and rod[1]
	local rodName = rod and rod[2]
	local rodUuid = rod and rod[5]
	local enchantId = nil
	local enchantId2 = nil
	local enchantName = nil
	local enchantName2 = nil
	local rodItem = rod and rod[6]
	if type(rodItem) == "table" then
		local meta = type(rodItem.Metadata) == "table" and rodItem.Metadata or {}
		enchantId = meta.EnchantId
		enchantId2 = meta.EnchantId2
		enchantName = enchantId and enchantById[enchantId] or nil
		enchantName2 = enchantId2 and enchantById[enchantId2] or nil
	end
	local activeQuests = {}
	local quests = type(raw.Quests) == "table" and raw.Quests or {}
	local mainline = type(quests.Mainline) == "table" and quests.Mainline or {}
	for questName, quest in pairs(mainline) do
		if type(quest) == "table" then
			local objectives = {}
			for k, obj in pairs(type(quest.Objectives) == "table" and quest.Objectives or {}) do
				if type(obj) == "table" then
					objectives[#objectives + 1] = {obj.Id, obj.Progress}
				end
			end
			activeQuests[#activeQuests + 1] = {questName, quest.CurrentObj, quest.Timestamp, objectives}
		end
	end
	local completedQuestCount = type(raw.CompletedQuests) == "table" and #raw.CompletedQuests or 0
	return {
		location = location and tostring(location) or nil,
		lastLocation = lastLocation and tostring(lastLocation) or nil,
		baitId = baitId,
		baitSkinId = baitSkinId,
		baitName = baitName,
		baitIcon = baitIcon,
		abilityUuid = abilityUuid,
		abilityName = abilityName,
		abilityRolls = abilityRolls,
		abilityShards = abilityShards,
		rodId = rodId,
		rodName = rodName,
		rodUuid = rodUuid,
		enchantId = enchantId,
		enchantId2 = enchantId2,
		enchantName = enchantName,
		enchantName2 = enchantName2,
		activeQuests = activeQuests,
		completedQuestCount = completedQuestCount,
	}
end

local function collectFish(inv)
    local fish = {}
    local totalWeight = 0
    local mutationCount = 0
    local secretCount = 0
    local mythicCount = 0
    for _, item in ipairs((inv and inv.Items) or {}) do
        if type(item) == "table" then
            local meta = item.Metadata or {}
            local weight = meta.Weight or 0
            if weight > 0 then
                local info = catalogById[item.Id]
                local tier = (info and info.tier) or 0
                local mutationValue = meta.VariantId
                local mutation = ""
                if type(mutationValue) == "string" then
                    mutation = mutationValue
                elseif type(mutationValue) == "table" then
                    mutation = mutationValue.Name or mutationValue.Id or mutationValue.Type or ""
                    mutation = tostring(mutation)
                elseif mutationValue ~= nil then
                    mutation = tostring(mutationValue)
                end
                local shiny = meta.Shiny == true and 1 or 0
                table.insert(fish, {item.Id, tier, weight, mutation, shiny})
                totalWeight = totalWeight + weight
                if tier == 7 then secretCount = secretCount + 1 end
                if tier == 6 then mythicCount = mythicCount + 1 end
                if mutation ~= "" or shiny == 1 then mutationCount = mutationCount + 1 end
            end
        end
    end
    table.sort(fish, function(a, b) return (a[3] or 0) > (b[3] or 0) end)
    return fish, totalWeight, secretCount, mythicCount, mutationCount
end

local function collectItems(inv)
    local byKey = {}
    if type(inv) ~= "table" then return {} end
    local allowedCategories = {Items = true, ["Fishing Rods"] = true, Baits = true}
    local function addItem(item, category)
        if type(item) ~= "table" or not item.Id then return end
        local info = itemInfo(item, category)
        local infoType = info.itemType and tostring(info.itemType):lower() or ""
        local catLower = category and tostring(category):lower() or ""
        local knownCategory = catLower == "fishing rods" or catLower == "items" or catLower == "baits"
        local typeSource = knownCategory and info.itemType or category
        local itemType = normalizeItemType(typeSource)
        if itemType == "fish" then return end
        local name
        if knownCategory and info.name then
            name = info.name
        elseif info.name and (infoType == catLower or catLower == "") then
            name = info.name
        else
            name = "ID:" .. tostring(item.Id)
        end
        local tier = knownCategory and (info.tier or 0) or 0
        local key = tostring(item.Id) .. ":" .. category
        local row = byKey[key] or {item.Id, category, itemType, 0, tier, name}
        row[4] = row[4] + (tonumber(item.Amount or item.Quantity or item.Count) or 1)
        byKey[key] = row
    end
    for category, bucket in pairs(inv) do
        if allowedCategories[category] and category ~= "Items" and type(bucket) == "table" then
            for _, item in ipairs(bucket) do
                addItem(item, category)
            end
        elseif category == "Items" and type(bucket) == "table" then
            for _, item in ipairs(bucket) do
                local meta = type(item) == "table" and item.Metadata or {}
                if type(meta) ~= "table" or not ((meta.Weight or 0) > 0) then
                    addItem(item, "Items")
                end
            end
        end
    end
    local out = {}
    for _, row in pairs(byKey) do table.insert(out, row) end
    table.sort(out, function(a, b) return tostring(a[2]) < tostring(b[2]) or (a[2] == b[2] and (a[4] or 0) > (b[4] or 0)) end)
    return out
end

local function masteryCounts(raw)
    local total = 0
    local species = 0
    if type(raw.CaughtFishMastery) == "table" then
        for _, data in pairs(raw.CaughtFishMastery) do
            if type(data) == "table" and data.Count then
                total = total + data.Count
                species = species + 1
            end
        end
    end
    return total, species
end

local function basePayload(raw, inv)
	local totalCaught, speciesCaught = masteryCounts(raw)
	local meta = collectMeta(raw, inv)
	return {
		username = LocalPlayer.Name,
		displayName = LocalPlayer.DisplayName,
		robloxUserId = LocalPlayer.UserId,
		placeId = game.PlaceId,
		jobId = game.JobId,
		executorName = identifyexecutor and identifyexecutor() or "unknown",
		trackerVersion = "0.1.1",
		level = raw.Level or 0,
		xp = raw.XP or 0,
		coins = raw.Coins or 0,
		totalCaught = totalCaught,
		speciesCaught = speciesCaught,
		equippedRodName = meta.rodName,
		meta = meta,
	}
end

local function snapshotHash(fish, rod)
    local parts = {"n" .. tostring(#fish), "r" .. tostring(rod and rod[1] or 0)}
    local limit = math.min(#fish, 12)
    for i = 1, limit do
        local f = fish[i]
        table.insert(parts, tostring(f[1]) .. ":" .. tostring(math.floor(f[3] or 0)))
    end
    return table.concat(parts, "|")
end

local function sendHeartbeat()
    local raw, inv, err = loadPlayerData()
    if err then return false, err end
    local payload = basePayload(raw, inv)
    local fish = collectFish(inv)
    payload.fishCount = #fish
    return post("/ingest/heartbeat", payload)
end

local lastSnapshotAt = 0
local lastHash = ""
local function sendSnapshot(force)
	local raw, inv, err = loadPlayerData()
	if err then return false, err end
	local fish = {collectFish(inv)}
	local fishList = fish[1]
	local totalWeight = fish[2]
	local extraItems = collectItems(inv)
	local meta = collectMeta(raw, inv)
	local rod = meta.rodId and {meta.rodId, meta.rodName or ("ID:" .. tostring(meta.rodId)), 0, ""} or nil
	local hash = snapshotHash(fishList, rod)
    if not force and hash == lastHash and (os.time() - lastSnapshotAt) < SNAPSHOT_MAX_INTERVAL then
        return true, "unchanged"
    end
    local totalCaught, speciesCaught = masteryCounts(raw)
    local payload = {
        username = LocalPlayer.Name,
        displayName = LocalPlayer.DisplayName,
        robloxUserId = LocalPlayer.UserId,
        placeId = game.PlaceId,
        jobId = game.JobId,
        executorName = identifyexecutor and identifyexecutor() or "unknown",
        trackerVersion = "0.1.0",
        stats = {raw.Level or 0, raw.XP or 0, raw.Coins or 0, totalCaught, speciesCaught},
        rod = rod,
        fish = fishList,
        items = extraItems,
        meta = meta,
        inventoryHash = hash .. "|w" .. tostring(math.floor(totalWeight)),
    }
    local ok, res = post("/ingest/fish-it/snapshot", payload)
    if ok then
        lastHash = hash
        lastSnapshotAt = os.time()
    end
    return ok, res
end

local catalog = buildCatalog()
refreshCatalogMaps(catalog)
local publicCatalog = {}
for _, item in ipairs(catalog) do
    if item.category ~= "Baits" then table.insert(publicCatalog, item) end
end
post("/ingest/fish-it/catalog", {items = publicCatalog})

-- Immediate lightweight heartbeat so user appears online right away
sendHeartbeat()

-- First snapshot delayed 5-30s to avoid pile-on at script start
local FIRST_SNAPSHOT_DELAY = 5 + math.random(0, 25)
local snapshotLock = false

task.spawn(function()
    while _G.__FishItTrackStatRunning do
        task.wait(HEARTBEAT_INTERVAL)
        local ok, err = sendHeartbeat()
        if not ok then warn("[FishIt TrackStat] heartbeat failed", err) end
    end
end)

task.spawn(function()
    -- Deferred first snapshot
    task.wait(FIRST_SNAPSHOT_DELAY)
    while _G.__FishItTrackStatRunning do
        if not snapshotLock then
            snapshotLock = true
            local force = (os.time() - lastSnapshotAt) >= SNAPSHOT_MAX_INTERVAL
            local ok, err = sendSnapshot(force)
            if not ok then warn("[FishIt TrackStat] snapshot failed", err) end
            snapshotLock = false
        end
        task.wait(SNAPSHOT_CHECK_INTERVAL)
    end
end)

notify("FishIt TrackStat", "Online — status live, inventory loading...")
