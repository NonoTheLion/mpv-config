local msg   = require 'mp.msg'
local utils = require 'mp.utils'
local s2t   = require("dicts/s2t_chars")
local t2s   = require("dicts/t2s_chars")

local function ass_escape(text)
    return text:gsub("\\", "\\\\")
               :gsub("{", "\\{")
               :gsub("}", "\\}")
               :gsub("\n", "\\N")
end

-- Construit la fonction de recherche du décalage par source
local function make_delay_lookup(source)
    local segments = nil
    local prefix = nil
    if source and source.delay_segments and #source.delay_segments > 0 then
        segments = {}
        for i, v in ipairs(source.delay_segments) do segments[i] = v end
        table.sort(segments, function(a, b) return (a.start or 0) < (b.start or 0) end)
        prefix = {}
        local s = 0
        for i, v in ipairs(segments) do
            s = s + (v.delay or 0)
            prefix[i] = s
        end
    end

    return function(t)
        local segs = segments or {}
        local pre = prefix or {}
        if #segs == 0 then return 0 end
        local idx = binary_search(segs, t, function(s) return (s and s.start) or 0 end)
        local target = idx - 1
        if target < 1 then return 0 end
        return pre[target] or 0
    end
end

local function xml_unescape(str)
    return str:gsub("&quot;", "\"")
              :gsub("&apos;", "'")
              :gsub("&gt;", ">")
              :gsub("&lt;", "<")
              :gsub("&amp;", "&")
end

local function decode_html_entities(text)
    return text:gsub("&#x([%x]+);", function(hex)
        local codepoint = tonumber(hex, 16)
        return unicode_to_utf8(codepoint)
    end):gsub("&#(%d+);", function(dec)
        local codepoint = tonumber(dec, 10)
        return unicode_to_utf8(codepoint)
    end)
end

-- Charge les motifs de la liste noire
local function load_blacklist_patterns(filepath)
    local patterns = {}
    if not file_exists(filepath) then
        return patterns
    end
    local file = io.open(filepath, "r")
    if not file then
        msg.error("Impossible d'ouvrir le fichier de liste noire : " .. filepath)
        return patterns
    end

    if string.match(filepath, "%.xml$") then
        -- Exemple de format XML
        --<?xml version="1.0" encoding="utf-8"?>
        --<filters>
        --  <item enabled="true">t=卡在</item>
        --  <item enabled="true">t=进度条</item>
        --</filters>
        print("Chargement du fichier de liste noire : " .. filepath)
        for line in file:lines() do
            local pattern = line:match('<item%s+enabled="true">t=(.-)</item>')
            if pattern then
                print("Chargement du motif de liste noire : " .. pattern)
                table.insert(patterns, pattern)
            end
        end
    end

    if string.match(filepath, "%.json$") then
        -- Exemple de format JSON
        -- [{"type":0,"filter":"开门","opened":true,"id":15628936}
        -- ,{"type":0,"filter":"tony","opened":true,"id":15628939}
        -- ,{"type":1,"filter":"0+.1","opened":true,"id":15628951}]
        local content = read_file(filepath)
        if content then
            local json = utils.parse_json(content)
            if json and type(json) == "table" then
                for _, entry in ipairs(json) do
                    if entry.opened and entry.filter and entry.type == 0 then
                        table.insert(patterns, entry.filter)
                    end
                end
            end
        end
    end

    if string.match(filepath, "%.txt$") then
        -- Exemple de format texte
        -- 卡在
        -- 进度条
        for line in file:lines() do
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed ~= "" then
                table.insert(patterns, trimmed)
            end
        end
    end

    file:close()
    return patterns
end

local blacklist_file = mp.command_native({ "expand-path", options.blacklist_path })
local black_patterns = load_blacklist_patterns(blacklist_file)

-- Vérifie si une chaîne correspond à la liste noire
function is_blacklisted(str, patterns)
    for _, pattern in ipairs(patterns) do
        local ok, result = pcall(function()
            return str:match(pattern)
        end)

        if ok and result then
            return true, pattern
        elseif not ok then
            -- msg.debug("Motif de liste noire invalide, ignoré : " .. pattern .. " ; erreur : " .. result)
        end
    end
    return false
end

-- Conversion chinois traditionnel/simplifié
local function convert(text, dict)
    return text:gsub("[%z\1-\127\194-\244][\128-\191]*", function(c)
        return dict[c] or c
    end)
end

local function ch_convert(str)
    if options.chConvert == 1 then
        return convert(str, t2s)
    elseif options.chConvert == 2 then
        return convert(str, s2t)
    end
    return str
end

local ch_convert_cache = {}
local ch_cache_keys = {}
local ch_cache_max = 5000

local function ch_convert_cached(text)
    if type(text) ~= "string" or text == "" then return text end
    local cached = ch_convert_cache[text]
    if cached ~= nil then return cached end

    local converted = ch_convert(text)
    ch_convert_cache[text] = converted
    ch_cache_keys[#ch_cache_keys+1] = text

    if #ch_cache_keys > ch_cache_max then
        local old_key = table.remove(ch_cache_keys, 1)
        ch_convert_cache[old_key] = nil
    end

    return converted
end

-- Fusionne les danmaku en double
local function merge_duplicate_danmaku(danmakus, threshold)
    if not threshold or tonumber(threshold) < 0 then return danmakus end

    local groups = {}

    for _, d in ipairs(danmakus) do
        local tkey = options.merge_without_style and "any" or tostring(d.type or "")
        local text = d.text or ""

        groups[text] = groups[text] or {}
        groups[text][tkey] = groups[text][tkey] or {}
        table.insert(groups[text][tkey], d)
    end

    local final_groups = {}

    -- Fusion des couleurs
    for _, type_groups in pairs(groups) do
        for _, list in pairs(type_groups) do
            if options.merge_without_style then
                table.insert(final_groups, list)
            else
                local color_groups = {}
                -- Exploite les nombreuses couleurs répétées et met en cache couleur -> indice color_groups
                local exact_color_cache = {}

                for _, d in ipairs(list) do
                    local c = d.color or 16777215
                    local g_idx = exact_color_cache[c]

                    if g_idx then
                        -- En cas de cache trouvé, insère directement
                        table.insert(color_groups[g_idx], d)
                    else
                        -- Sinon, vérifie si la couleur se trouve à moins de 15 d’une couleur représentative
                        local found = false
                        for i, cg in ipairs(color_groups) do
                            if color_dist(cg[1].color or 16777215, c) <= 15 then
                                table.insert(cg, d)
                                -- Met en cache l’indice représentatif afin de retrouver directement cette couleur
                                exact_color_cache[c] = i
                                found = true
                                break
                            end
                        end

                        -- Crée un groupe pour une nouvelle couleur hors tolérance
                        if not found then
                            table.insert(color_groups, {d})
                            exact_color_cache[c] = #color_groups
                        end
                    end
                end

                for _, cg in ipairs(color_groups) do
                    table.insert(final_groups, cg)
                end
            end
        end
    end

    local merged = {}
    local abs = math.abs

    for _, group in ipairs(final_groups) do
        table.sort(group, function(a, b) return a.time < b.time end)

        local i = 1
        while i <= #group do
            local base = group[i]
            local times = { base.time }
            local count = 1
            local j = i + 1

            while j <= #group and abs(group[j].time - base.time) <= threshold do
                times[#times+1] = group[j].time
                count = count + 1
                j = j + 1
            end

            local same_time = true
            for k = 2, #times do
                if times[k] ~= times[1] then
                    same_time = false
                    break
                end
            end

            local danmaku = {
                time = base.time,
                type = base.type,
                size = base.size,
                color = base.color,
                text = base.text,
                source = base.source,
                orig_time = base.orig_time,
                merge_count = count,
            }
            if count > 2 or not same_time then
                danmaku.text = danmaku.text .. string.format("x%d", count)
            end

            table.insert(merged, danmaku)
            i = j
        end
    end

    table.sort(merged, function(a, b) return a.time < b.time end)
    return merged
end

-- Limite le nombre de danmaku à l’écran
local function limit_danmaku(danmakus, limit)
    if not limit or limit <= 0 then
        return danmakus
    end

    local window = {}
    for _, d in ipairs(danmakus) do
        for i = #window, 1, -1 do
            if window[i].end_time <= d.start_time then
                table.remove(window, i)
            end
        end

        if #window < limit then
            table.insert(window, d)
        else
            local max_idx = 1
            for i = 2, #window do
                if window[i].end_time > window[max_idx].end_time then
                    max_idx = i
                end
            end
            if window[max_idx].end_time > d.end_time then
                window[max_idx].drop = true
                window[max_idx] = d
            else
                d.drop = true
            end
        end
    end

    local result = {}
    for _, d in ipairs(danmakus) do
        if not d.drop then
            table.insert(result, d)
        end
    end
    return result
end

-- Analyse les danmaku XML
function parse_xml_danmaku(xml_string)
    local danmakus = {}
    if not xml_string then
        return danmakus
    end
    -- [^>]* correspond aux autres attributs
    -- %f[^%s] garantit que p= est précédé d'un espace
    for p_attr, text in xml_string:gmatch('<d%s+[^>]*%f[^%s]p="([^"]+)"[^>]*>([^<]+)</d>') do
        local params = {}
        local i = 1
        for val in p_attr:gmatch("([^,]+)") do
            params[i] = tonumber(val)
            i = i + 1
        end

        if params[1] and params[2]  and params[3] and params[4] then
            table.insert(danmakus, {
                time = params[1],
                type = params[2] or 1,
                size = params[3] or 25,
                color = params[4] or 0xFFFFFF,
                text = xml_unescape(text)
            })
        end
    end

    table.sort(danmakus, function(a, b) return a.time < b.time end)
    return danmakus
end

-- Analyse les danmaku JSON
function parse_json_danmaku(json_string)
    local danmakus = {}
    if json_string:sub(1, 3) == "\239\187\191" then
        json_string = json_string:sub(4)
    end

    local json = utils.parse_json(json_string)
    if not json or type(json) ~= "table" then
        msg.info("Échec de l'analyse JSON")
        return danmakus
    end

    for _, entry in ipairs(json) do
        local c = entry.c
        local text = entry.m or ""
        if type(c) == "string" then
            local params = {}
            local i = 1
            for val in c:gmatch("([^,]+)") do
                params[i] = tonumber(val)
                i = i + 1
            end

            if params[1] and params[2] and params[3] and params[4] then
                table.insert(danmakus, {
                    time = params[1],
                    color = params[2] or 0xFFFFFF,
                    type = params[3] or 1,
                    size = params[4] or 25,
                    text = text
                })
            end
        end
    end

    table.sort(danmakus, function(a, b) return a.time < b.time end)
    return danmakus
end

-- Analyse un fichier de danmaku
function parse_danmaku_file(danmaku_input)
    local danmakus = {}

    if file_exists(danmaku_input) then
        local content = read_file(danmaku_input)
        if content then
            local parsed = {}
            if danmaku_input:match("%.xml$") then
                parsed = parse_xml_danmaku(content)
            elseif danmaku_input:match("%.json$") then
                parsed = parse_json_danmaku(content)
            end

            for _, d in ipairs(parsed) do
                table.insert(danmakus, d)
            end
        else
            msg.info("Impossible de lire le contenu du fichier : " .. danmaku_input)
        end
    else
        msg.info("Fichier introuvable : " .. danmaku_input)
    end

    for _, d in ipairs(danmakus) do
        if d.orig_time == nil then d.orig_time = d.time end
    end

    if #danmakus == 0 then
        msg.info("Aucun danmaku n'a pu être analysé")
        return nil
    end

    return danmakus
end

--# Tableaux de danmaku et algorithmes de placement
local DanmakuArray = {}
DanmakuArray.__index = DanmakuArray

-- Avant arrondi, la fonction logarithmique est strictement croissante et concave.
-- Après arrondi, la taille entière ne décroît pas ; la taille maximale évite les valeurs excessives.
function DanmakuArray.get_merged_font_size(base_size, count, growth, max_size)
    local base = positive_integer(base_size, 1)
    local n = positive_integer(count, 1)
    local scale = positive_integer(growth, 8)
    local maximum = math.max(base, positive_integer(max_size, base))
    local size = base + math.floor(scale * math.log(n) + 0.5)
    return math.min(maximum, size)
end

function DanmakuArray:new(max_y)
    local obj = {
        max_y = positive_integer(max_y, 1),
        danmakus = {},
    }
    setmetatable(obj, self)
    return obj
end

-- Les danmaku sont traités par ordre d’apparition. Dès qu’un danmaku défilant a quitté l’écran,
-- ou que la durée d’un danmaku fixe est écoulée, il peut être retiré sans risque de collision.
function DanmakuArray:remove_expired(now)
    for i = #self.danmakus, 1, -1 do
        if self.danmakus[i].end_time <= now then
            table.remove(self.danmakus, i)
        end
    end
end

local function y_intersects(y1, height1, y2, height2)
    return y1 < y2 + height2 and y2 < y1 + height1
end

local function rolling_danmaku_collides(previous, start_time, velocity)
    local delta_velocity = velocity - previous.velocity
    local delta_x = (start_time - previous.start_time) * previous.velocity - previous.length

    -- Un delta_x négatif signifie que l’ancien danmaku n’est pas entièrement entré : le nouveau le chevaucherait.
    if delta_x < 0 then
        return true
    end

    -- Si le nouveau danmaku n’est pas plus rapide, il ne réduira pas l’écart delta_x.
    if delta_velocity <= 0 then
        return false
    end

    -- Compare le temps nécessaire pour rattraper l’ancien danmaku à sa durée restante ;
    -- il n’y a collision que si le rattrapage survient avant sa sortie de l’écran.
    local delta_time = delta_x / delta_velocity
    local remaining_time = previous.end_time - start_time
    return delta_time < remaining_time
end

-- Cherche une position depuis le haut de l’axe y. Pour chaque position, ne vérifie que les intervalles
-- qui croisent le nouveau danmaku ; en cas de collision, reprend sous l’intervalle concerné.
local function find_y_from_top(array, height, collides)
    local y = 1
    while y + height - 1 <= array.max_y do
        local next_y = nil
        for _, danmaku in ipairs(array.danmakus) do
            if y_intersects(y, height, danmaku.y, danmaku.height) and collides(danmaku) then
                local below = danmaku.y + danmaku.height
                next_y = next_y and math.max(next_y, below) or below
            end
        end
        if not next_y then return y end
        y = next_y
    end
    return nil
end

-- Cherche depuis le haut une place pour un danmaku défilant et mémorise l’intervalle occupé.
function DanmakuArray:get_position_y(start_time, length, height, resolution_x, duration)
    height = positive_integer(height, 1)
    length = math.max(0, tonumber(length) or 0)
    resolution_x = math.max(1, tonumber(resolution_x) or 1)
    duration = math.max(0.001, tonumber(duration) or 0.001)
    self:remove_expired(start_time)

    local velocity = (length + resolution_x) / duration
    local y = find_y_from_top(self, height, function(previous)
        return rolling_danmaku_collides(previous, start_time, velocity)
    end)
    if not y then return nil end

    self.danmakus[#self.danmakus + 1] = {
        y = y,
        height = height,
        start_time = start_time,
        end_time = start_time + duration,
        length = length,
        velocity = velocity,
    }
    return y
end

-- Les danmaku fixes du haut sont placés de haut en bas, ceux du bas de bas en haut.
function DanmakuArray:get_fixed_y(start_time, height, duration, from_top)
    height = positive_integer(height, 1)
    duration = math.max(0.001, tonumber(duration) or 0.001)
    self:remove_expired(start_time)

    local y
    if from_top then
        y = find_y_from_top(self, height, function() return true end)
    else
        y = self.max_y - height + 1
        while y >= 1 do
            local next_y = nil
            for _, danmaku in ipairs(self.danmakus) do
                if y_intersects(y, height, danmaku.y, danmaku.height) then
                    local above = danmaku.y - height
                    next_y = next_y and math.min(next_y, above) or above
                end
            end
            if not next_y then break end
            y = next_y
        end
        if y < 1 then y = nil end
    end

    if not y then return nil end
    self.danmakus[#self.danmakus + 1] = {
        y = y,
        height = height,
        start_time = start_time,
        end_time = start_time + duration,
    }
    return y
end

-- Convertit les danmaku au format XML
function convert_danmaku_to_xml(danmaku_out)
    local danmakus = {}
    for url, source in pairs(DANMAKU.sources) do
        if not source.blocked and source.data then
            local get_cached_delay = make_delay_lookup(source)

            for _, d in ipairs(source.data) do
                local base_time = d.orig_time or d.time
                local adjusted_time = base_time + get_cached_delay(base_time)
                table.insert(danmakus, {
                    orig_time = d.orig_time,
                    time = adjusted_time,
                    type = d.type,
                    size = d.size,
                    color = d.color,
                    text = d.text,
                    source = url,
                })
            end
        end
    end

    if #danmakus == 0 then
        show_message("Le contenu des danmaku est vide ; enregistrement impossible", 3)
        msg.verbose("Le contenu des danmaku est vide ; enregistrement impossible")
        COMMENTS = {}
        return false
    end

    -- Assemble le contenu XML
    local xml = { '<?xml version="1.0" encoding="UTF-8"?><i>\n' }
    for _, d in ipairs(danmakus) do
       local time = d.time
       local type = d.type or 1
       local size = d.size or 25
       local color = d.color or 0xFFFFFF
       local text = d.text or ""

       text = text:gsub("&", "&amp;")
                  :gsub("<", "&lt;")
                  :gsub(">", "&gt;")
                  :gsub("\"", "&quot;")
                  :gsub("'", "&apos;")

       table.insert(xml, string.format('<d p="%s,%s,%s,%s">%s</d>\n', time, type, size, color, text))
    end
    table.insert(xml, '</i>')

    -- Écrit le fichier XML
    local file = io.open(danmaku_out, "w")
    if not file then
       show_message("Impossible d'écrire le fichier XML de destination", 3)
       msg.info("Impossible d'écrire le fichier XML de destination: " .. danmaku_out)
       return false
    end
    file:write(table.concat(xml))
    file:close()
    show_message("Conversion des danmaku en XML réussie : " .. danmaku_out, 3)
    msg.info("Conversion des danmaku en XML réussie : " .. danmaku_out)
    return true
end

function convert_danmaku_to_ass_events(force)
    local per_source_lists = {}
    for url, source in pairs(DANMAKU.sources) do
        if not source.blocked and source.data then
            local get_cached_delay = make_delay_lookup(source)

            local list = {}
            for _, d in ipairs(source.data) do
                local base_time = d.orig_time or d.time
                if d.orig_time == nil then d.orig_time = base_time end
                local adjusted_time = base_time + get_cached_delay(base_time)
                local entry = {
                    orig_time = d.orig_time,
                    time = adjusted_time,
                    type = d.type,
                    size = d.size,
                    color = d.color,
                    text = d.text,
                    source = url,
                }
                if not is_blacklisted(d.text, black_patterns) then
                    table.insert(list, entry)
                end
            end

            if #list > 0 then
                table.sort(list, function(a, b) return a.time < b.time end)
                per_source_lists[#per_source_lists + 1] = list
            end
        end
    end

    local danmakus = {}

    local heap = new_min_heap()
    for li = 1, #per_source_lists do
        local lst = per_source_lists[li]
        if lst and #lst > 0 then
            heap.push({ time = lst[1].time, list_idx = li, pos = 1, entry = lst[1] })
        end
    end

    while true do
        local node = heap.pop()
        if not node then break end
        table.insert(danmakus, node.entry)
        local li = node.list_idx
        local next_pos = node.pos + 1
        local lst = per_source_lists[li]
        if lst and lst[next_pos] then
            heap.push({ time = lst[next_pos].time, list_idx = li, pos = next_pos, entry = lst[next_pos] })
        end
    end

    if options.max_screen_danmaku > 0 and options.merge_tolerance <= 0 then
        options.merge_tolerance = options.scrolltime
    end

    danmakus = merge_duplicate_danmaku(danmakus, options.merge_tolerance)

    if #danmakus == 0 then
        if not force then
            show_message("Cet épisode ne contient aucun danmaku ; chargement interrompu", 3)
            msg.verbose("Cet épisode ne contient aucun danmaku ; chargement interrompu")
        end
        COMMENTS = {}
        return
    end

    if not force then
        msg.info("Analyse terminée : " .. #danmakus .. " danmaku")
    end

    local fontsize = tonumber(options.fontsize) or 50
    local fontsize_growth = tonumber(options.merge_fontsize_growth) or 8
    local fontsize_max = tonumber(options.merge_fontsize_max) or 100
    local scrolltime = tonumber(options.scrolltime) or 15
    local fixtime = tonumber(options.fixtime) or 5

    local res_x = 1920
    local res_y = 1080

    local display_height = math.max(1, math.floor(res_y * (tonumber(options.displayarea) or 1)))
    local roll_array = DanmakuArray:new(display_height)
    local fixed_array = DanmakuArray:new(display_height)

    -- Prétraite les danmaku et calcule leurs intervalles afin d'en limiter le nombre
    local pre_events = {}
    for _, d in ipairs(danmakus) do
        local time = d.type == 1 and math.floor(d.time + 0.5) or d.time
        local orig_time = d.type == 1 and math.floor(d.orig_time + 0.5) or d.orig_time
        local appear_time = time
        local danmaku_type = d.type

        local end_time = nil
        if danmaku_type >= 1 and danmaku_type <= 3 then
            end_time = appear_time + scrolltime
        elseif danmaku_type == 5 or danmaku_type == 4 then
            end_time = appear_time + fixtime
        end

        if end_time then
            table.insert(pre_events, {orig_time = orig_time, start_time = appear_time, end_time = end_time, danmaku = d})
        end
    end

    if options.max_screen_danmaku > 0 then
        pre_events = limit_danmaku(pre_events, options.max_screen_danmaku)
    end

    local ass_events = {}
    for _, ev in ipairs(pre_events) do
        local d = ev.danmaku
        local appear_time = ev.start_time
        local danmaku_type = d.type
        local clean_text = ch_convert_cached(decode_html_entities(d.text))
        local text = ass_escape(clean_text)
                    :gsub("x(%d+)$", "{\\b1\\i1}x%1")
        local event_fontsize = DanmakuArray.get_merged_font_size(
            fontsize, d.merge_count or 1, fontsize_growth, fontsize_max
        )

        -- Convertit la couleur décimale en hexadécimal BGR
        local color = math.max(0, math.min(d.color or 0xFFFFFF, 0xFFFFFF))
        local color_hex = string.format("%06X", color)
        local r = string.sub(color_hex, 1, 2)
        local g = string.sub(color_hex, 3, 4)
        local b = string.sub(color_hex, 5, 6)
        local color_text = string.format("{\\c&H%s%s%s&}", b, g, r)

        local style, effect
        local pos, move = nil, nil

        -- Danmaku défilants (types 1, 2 et 3)
        if danmaku_type >= 1 and danmaku_type <= 3 then
            style = "R2L"
            local text_length = get_str_width(clean_text, event_fontsize)
            local x1 = res_x + text_length / 2
            local x2 = -text_length / 2
            local y = roll_array:get_position_y(appear_time, text_length, event_fontsize, res_x, scrolltime)
            if y then
                effect = string.format("{\\move(%d, %d, %d, %d)}", x1, y, x2, y)
                move = {x1, y, x2, y}
            end

        -- Danmaku fixes en haut (type 5)
        elseif danmaku_type == 5 then
            style = "TOP"
            local x = res_x / 2
            local y = fixed_array:get_fixed_y(appear_time, event_fontsize, fixtime, true)
            if y then
                effect = string.format("{\\pos(%d, %d)}", x, y)
                pos = {x, y}
            end

        -- Danmaku fixes en bas (type 4)
        elseif danmaku_type == 4 then
            style = "BTM"
            local x = res_x / 2
            local y = fixed_array:get_fixed_y(appear_time, event_fontsize, fixtime, false)
            if y then
                effect = string.format("{\\pos(%d, %d)}", x, y)
                pos = {x, y}
            end
        end

        if style and effect then
            text = effect .. color_text .. text
            local event = {
                orig_time = ev.orig_time,
                start_time = ev.start_time,
                end_time = ev.end_time,
                delay = ev.start_time - (ev.orig_time or ev.start_time),
                style = style,
                text = text,
                clean_text = clean_text,
                pos = pos,
                move = move,
                layer = (style == "R2L") and 0 or 1,
                source = d.source,
                font_size = event_fontsize,
                merge_count = d.merge_count or 1,
            }
            table.insert(ass_events, event)
        end
    end
    COMMENTS = ass_events
end
