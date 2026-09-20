local msg = require('mp.msg')
local utils = require("mp.utils")

local function extract_url(url)
    local path = url:match("^https?://[^/]+(/[^%?]*)")
    return path
end

local function generateXSignature(url, time, appid, app_accept)
    local url_path = extract_url(url)
    if not url_path then
        return nil
    end

    local dataToHash = string.format("%s%d%s%s", AES.ECB.decrypt(KEY, Base64.decode(appid)),
    time, url_path, AES.ECB.decrypt(KEY, Base64.decode(app_accept)))
    local hash = Sha256(dataToHash)
    local base64Hash = Base64.encode(hex_to_bin(hash))
    return base64Hash
end

-- Écrit history.json
-- Lit episodeId pour récupérer les danmaku
function set_episode_id(input, from_menu, api_server)
    from_menu = from_menu or false
    DANMAKU.source = "dandanplay"
    local selected_server = api_server
    for url, source in pairs(DANMAKU.sources) do
        if source.from == "api_server" then
            if not source.from_history then
                DANMAKU.sources[url] = nil
            else
                DANMAKU.sources[url]["data"] = nil
            end
        end
    end

    if not api_server then
        if DANMAKU.api_server ~= nil then
            selected_server = DANMAKU.api_server
        else
            local servers = get_api_server_list(options.api_server)
            if servers and #servers > 0 then
                selected_server = servers[1]
            end
        end
    end

    DANMAKU.api_server = selected_server

    local episodeId = tonumber(input)
    write_history(episodeId, selected_server)
    set_danmaku_button()
    fetch_danmaku(episodeId, from_menu, selected_server)
end

-- Utilise en secours une autre méthode de récupération des danmaku
function get_danmaku_fallback(query)
    local function do_fallback()
        if options.fallback_server == "" then return end
        local url = options.fallback_server .. "/?ac=dm&url=" .. query
        msg.verbose("Tentative de récupération des danmaku : " .. url)

        local args = make_danmaku_request_args("GET", url)
        if not args then return end

        fetch_danmaku_data(args, function(data)
            if data ~= nil and data["xml"] ~= nil then
                if DANMAKU.sources[query] ~= nil then
                    DANMAKU.sources[query]["data"] = data["xml"]
                else
                    DANMAKU.sources[query] = {from = "user_custom", data = data["xml"]}
                end
                load_danmaku(true)
                return
            end

            if not data or not data["comments"] or data["count"] <= 1 then
                msg.info("Le serveur de secours ne contient aucune donnée ou a renvoyé un format incorrect")
                show_message("Le serveur de secours ne contient aucune donnée ou a renvoyé un format incorrect", 3)
                return
            end

            save_danmaku_data(data["comments"], query, "user_custom")
            load_danmaku(true)
        end)
    end

    if query:find('bilibili.com') or query:find('bilivideo.c[nom]+') then
        load_danmaku_for_bilibili(query, function(success)
            if not success then do_fallback() end
        end)
        return
    end

    if query:find('bahamut.akamaized.net') then
        load_danmaku_for_bahamut(query, function(success)
            if not success then do_fallback() end
        end)
        return
    end

    if query:find('mgtv.com') then
        load_danmaku_for_mgtv(query, function(success)
            if not success then do_fallback() end
        end)
        return
    end

    if query:find('iqiyi.com') then
        load_danmaku_for_iqiyi(query, function(success)
            if not success then do_fallback() end
        end)
        return
    end

    if query:find('v.qq.com') then
        load_danmaku_for_tencent(query, function(success)
            if not success then do_fallback() end
        end)
        return
    end

    if query:find('v.youku.com') then
        load_danmaku_for_youku(query, function(success)
            if not success then do_fallback() end
        end)
        return
    end

    do_fallback()
end

-- Renvoie les paramètres de la requête de danmaku
function make_danmaku_request_args(method, url, headers, body)
    local args = {
        "curl",
        "--ssl-no-revoke",
        "-L",
        "-X",
        method,
        "-H",
        "Accept: application/json",
        "-H",
        "User-Agent: " .. options.user_agent,
    }

    if headers then
        for k, v in pairs(headers) do
            table.insert(args, '-H')
            table.insert(args, string.format('%s: %s', k, v))
        end
    end

    if body then
        table.insert(args, '-d')
        table.insert(args, utils.format_json(body))
        table.insert(args, '-H')
        table.insert(args, 'Content-Type: application/json')
    end

    table.insert(args, '--compressed')

    if url:find("api%.dandanplay%.") then
        local time = os.time()
        local appid = "UgjRIH45lE1BBLNmir1WKw=="
        local app_accept = "SzuWlFZAPRMqeWf9qmfp8dcvYr3hvxuSrIRZuAeEfko="
        table.insert(args, '-H')
        table.insert(args, string.format('X-AppId: %s', AES.ECB.decrypt(KEY, Base64.decode(appid))))
        table.insert(args, '-H')
        table.insert(args, string.format('X-Signature: %s', generateXSignature(url, time, appid, app_accept)))
        table.insert(args, '-H')
        table.insert(args, string.format('X-Timestamp: %s', time))
    end

    if options.proxy ~= "" then
        table.insert(args, '-x')
        table.insert(args, options.proxy)
    end

    table.insert(args, url)

    return args
end

local function normalize_danmaku_response(d)
    if not d then return d end
    -- Renvoie directement les données déjà au format comments/count
    if d.comments or d.count then return d end

    if d.danmuku and type(d.danmuku) == "table" then
        local out = {}
        for _, item in ipairs(d.danmuku) do
            -- item doit être un tableau : 1=time, 2=pos(right/top/bottom), 3=color(hex), 5=content
            local time = tonumber(item[1]) or 0
            local pos = item[2] or "right"
            local color = item[3] or ""
            local content = item[5] or item[4] or ""

            local mode = 1
            if pos == "right" then
                mode = 1
            elseif pos == "top" then
                mode = 4
            elseif pos == "bottom" then
                mode = 5
            end

            local colorDec = 16777215
            if type(color) == "number" then
                colorDec = color
            elseif type(color) == "string" then
                colorDec = hex_to_int_color(color)
            end

            local p = string.format("%.2f,%d,%d", time, mode, colorDec)
            table.insert(out, { p = p, m = content })
        end
        return { comments = out, count = tonumber(d.danum) or #out }
    end

    return d
end

-- Tente d'associer l'épisode en analysant le nom du fichier
local function match_episode(animeTitle, bangumiId, episode_num, api_server)
    local url = api_server .. "/api/v2/bangumi/" .. bangumiId
    local args = make_danmaku_request_args("GET", url)

    if args == nil then
        return
    end

    call_cmd_async(args, function(error, json)
        if error then
            show_message("Échec de la requête HTTP ; consultez la console", 5)
            msg.error(error)
            return
        end

        local data = utils.parse_json(json)
        if not data or not data.bangumi or not data.bangumi.episodes then
            msg.info("Aucun résultat")
            return
        end

        for _, episode in ipairs(data.bangumi.episodes) do
            local ep_num = tonumber(episode.episodeNumber)
            if ep_num and ep_num == tonumber(episode_num) then
                DANMAKU.anime = animeTitle
                DANMAKU.episode = episode.episodeTitle
                set_episode_id(episode.episodeId, nil, api_server)
                break
            end
        end
    end)
end

local function match_anime()
    local anime_type = "tvseries"
    local title, season_num, episode_num = parse_title()
    if not episode_num then
        mp.commandv("script-message", "auto_load_fallback")
        msg.error("Impossible d’analyser les informations de l’épisode")
        return
    end

    if title:match("OVA") or title:match("OAD") then
        anime_type = "ova"
    end

    -- Recherche en parallèle sur plusieurs api_server et annule les autres dès la première correspondance acceptable
    local encoded_query = url_encode(title)
    local servers = get_api_server_list(options.api_server)

    local matched = false
    local cancel_fn = nil

    local function build_args(server)
        local url = server .. "/api/v2/search/anime"
        local full_url = url .. "?keyword=" .. encoded_query
        return make_danmaku_request_args("GET", full_url)
    end

    local function per_response(server, err, out)
        if matched then return end
        if err then
            msg.debug(("search anime failed for %s: %s"):format(server, tostring(err)))
            return
        end
        local data = utils.parse_json(out)
        if not data or not data.animes then
            return
        end
        local local_candidates = {}
        for _, anime in ipairs(data.animes) do
            if anime.type == anime_type then
                table.insert(local_candidates, anime)
            end
        end
        if #local_candidates == 1 then
            matched = true
            local a = local_candidates[1]
            match_episode(a.animeTitle, a.bangumiId, episode_num, server)
            if cancel_fn then pcall(cancel_fn) end
            return
        end
        if #local_candidates > 1 and season_num then
            local best_match, best_score = nil, -1
            local target_title = title
            if tonumber(season_num) > 1 then
                target_title = title .. " 第" .. number_to_chinese(season_num) .. "季"
            end
            for _, anime in ipairs(local_candidates) do
                local animeTitle = tostring(anime.animeTitle or "")
                animeTitle = animeTitle:gsub("^%s*(.-)%s*$", "%1")
                            :gsub("%s*%(.-%)%s*$", "")
                            :gsub("%s*【.-】.*$", "")
                if animeTitle:match("第一[季部]") and tonumber(season_num) == 1 then
                    target_title = title .. " 第一季"
                end
                local score = jaro_winkler(target_title, animeTitle)
                msg.debug(("Candidat : %s -> similarité %.3f"):format(animeTitle, score))
                if score > best_score then
                    best_score = score
                    best_match = anime
                end
            end
            if best_match and best_score >= 0.75 then
                matched = true
                msg.info(("Correspondance approximative retenue : %s (score=%.2f)"):format(best_match.animeTitle, best_score))
                match_episode(best_match.animeTitle, best_match.bangumiId, episode_num, server)
                if cancel_fn then pcall(cancel_fn) end
                return
            end
        end
        -- En l'absence de correspondance acceptable, attend les autres serveurs
    end

    local function final_cb()
        if not matched then
            mp.commandv("script-message", "auto_load_fallback")
            msg.info("Aucune correspondance appropriée")
        end
    end

    cancel_fn = parallel_requests(servers, build_args, per_response, final_cb, { concurrency = 5, per_request_timeout = 60 })
end

-- Récupère les danmaku par correspondance de hachage
local function match_file(file_path, file_name, callback)
    -- Calcule le hachage du fichier
    local hash = nil
    local file_info = utils.file_info(file_path)
    if file_info and file_info.size >= 16 * 1024 * 1024 then
        local file, error = io.open(normalize(file_path), 'rb')
        if file and not error then
            local m = MD5.new()
            for _ = 1, 16 * 1024 do
                local content = file:read(1024)
                if not content then
                    break
                end
                m:update(content)
            end
            file:close()
            hash = m:finish()
        end
    end

    if hash then msg.info('hash:', hash) end

    local title, season_num, episode_num = parse_title()
    if title and episode_num then
        if season_num then
            file_name = title .. " S" .. season_num .. "E" .. episode_num
        else
            file_name = title .. " E" .. episode_num
        end
    else
        file_name = title
    end

    local servers = get_api_server_list(options.api_server)

    local matched = false
    local cancel_fn = nil

    local function build_args(server)
        local url = server .. "/api/v2/match"
        return make_danmaku_request_args("POST", url, { ["Content-Type"] = "application/json" }, {
            fileName = file_name,
            fileHash = hash or "a1b2c3d4e5f67890abcd1234ef567890",
            matchMode = "hashAndFileName"
        })
    end

    local function per_response(server, err, out)
        if matched then return end
        if err then
            msg.debug(("match failed for %s: %s"):format(server, tostring(err)))
            return
        end
        local data = utils.parse_json(out)
        if not data or not data.isMatched then
            return
        end
        matched = true
        DANMAKU.anime = data.matches[1].animeTitle
        DANMAKU.episode = data.matches[1].episodeTitle

        set_episode_id(data.matches[1].episodeId, nil, server)
        if cancel_fn then pcall(cancel_fn) end
        if callback then pcall(callback) end
    end

    local function final_cb()
        if not matched then
            mp.commandv("script-message", "auto_load_fallback")
            callback("Aucun épisode correspondant au hachage")
        end
    end

    cancel_fn = parallel_requests(servers, build_args, per_response, final_cb, { concurrency = 5, per_request_timeout = 60 })
end

-- Récupère les danmaku de façon asynchrone
function fetch_danmaku_data(args, callback)
    call_cmd_async(args, function(error, json)
        if error then
            show_message("Échec de la récupération des données", 3)
            msg.error("Échec de la requête HTTP : " .. error)
            return
        end
        local data = utils.parse_json(json)
        if data ~= nil then
            data = normalize_danmaku_response(data)
        else
            local danmaku = parse_xml_danmaku(json)
            if #danmaku > 0 then
                data = {}
                data["xml"] = danmaku
            end
        end
        callback(data)
    end)
end

-- Enregistre les données de danmaku
function save_danmaku_data(comments, query, danmaku_source)
    local danmaku_list = save_danmaku_to_list(comments)

    if DANMAKU.sources[query] ~= nil then
        DANMAKU.sources[query]["data"] = danmaku_list
    else
        DANMAKU.sources[query] = {from = danmaku_source, data = danmaku_list}
    end
end

function save_danmaku_xml(url, xml_string)
    local danmaku_list = parse_xml_danmaku(xml_string)

    if DANMAKU.sources[url] ~= nil then
        DANMAKU.sources[url]["data"] = danmaku_list
    else
        DANMAKU.sources[url] = {from = "user_custom", data = danmaku_list}
    end
end

function save_danmaku_json(url, json_string)
    local danmaku_list = parse_json_danmaku(json_string)

    if DANMAKU.sources[url] ~= nil then
        DANMAKU.sources[url]["data"] = danmaku_list
    else
        DANMAKU.sources[url] = {from = "user_custom", data = danmaku_list}
    end
end

function save_danmaku_downloaded(url, downloaded_file)
    local danmaku_list = parse_danmaku_file(downloaded_file)
    if file_exists(downloaded_file) then
        os.remove(downloaded_file)
    end
    if DANMAKU.sources[url] ~= nil then
        DANMAKU.sources[url]["data"] = danmaku_list
    else
        DANMAKU.sources[url] = {from = "user_custom", data = danmaku_list}
    end
end

-- Traite les données récupérées
function handle_fetched_danmaku(data, url, from_menu)
    if data and data["comments"] then
        if data["count"] == 0 then
            if DANMAKU.sources[url] == nil then
                DANMAKU.sources[url] = {from = "api_server"}
            end
            show_message("Cet épisode ne contient aucun danmaku ; chargement interrompu", 3)
            msg.info("Cet épisode ne contient aucun danmaku ; chargement interrompu")
            if not from_menu then
                mp.commandv("script-message", "auto_load_fallback")
            end
            return
        end
        save_danmaku_data(data["comments"], url, "api_server")
        load_danmaku(from_menu)
    else
        show_message("Aucune donnée", 3)
        msg.info("Aucune donnée")
        if not from_menu then
            mp.commandv("script-message", "auto_load_fallback")
        end
    end
end

-- Associe les commentaires de la bibliothèque dandanplay uniquement
-- Récupère les danmaku via l'URL de l'API et l'identifiant
function fetch_danmaku(episodeId, from_menu, api_server)
    local url = api_server .. "/api/v2/comment/" .. episodeId .. "?withRelated=true&chConvert=0"
    show_message("Chargement des danmaku…", 30)
    msg.verbose("Tentative de récupération des danmaku : " .. url)
    local args = make_danmaku_request_args("GET", url)

    if args == nil then
        return
    end

    fetch_danmaku_data(args, function(data)
        handle_fetched_danmaku(data, url, from_menu)
    end)
end

-- Ajoute les danmaku d'une source ajoutée par l'utilisateur
function addon_danmaku(dir, from_menu)
    if dir then
        local history_json = read_file(HISTORY_PATH)
        local history = utils.parse_json(history_json) or {}
        if history[dir] and history[dir].extra ~= nil then
            return
        end
    end
    for url, source in pairs(DANMAKU.sources) do
        if source.from ~= "api_server" then
            add_danmaku_source(url, from_menu)
        end
    end
end

--Récupère une bibliothèque de danmaku depuis une URL
function add_danmaku_source(query, from_menu)
    if DANMAKU.sources[query] == nil then
        DANMAKU.sources[query] = {from = "user_custom"}
    end

    from_menu = from_menu or false
    if from_menu then
        add_source_to_history(query, DANMAKU.sources[query])
    end

    if is_protocol(query) then
        add_danmaku_source_online(query, from_menu)
    else
        add_danmaku_source_local(query, from_menu)
    end
end

function add_danmaku_source_local(query, from_menu)
    local path = normalize(query)
    if not file_exists(path) then
        msg.warn("Chemin de fichier invalide")
        return
    end
    if not (string.match(path, "%.xml$") or string.match(path, "%.json$")) then
        msg.warn("Seuls les fichiers de danmaku sont pris en charge")
        return
    end

    if DANMAKU.sources[query] ~= nil then
        DANMAKU.sources[query]["from"] = "user_local"
        DANMAKU.sources[query]["data"] = parse_danmaku_file(path)
    else
        DANMAKU.sources[query] = {from = "user_local", data = parse_danmaku_file(path)}
    end

    set_danmaku_button()
    load_danmaku(from_menu)
end

--Récupère une bibliothèque de danmaku depuis une URL
function add_danmaku_source_online(query, from_menu)
    set_danmaku_button()
    show_message("Chargement des danmaku…", 30)
    msg.verbose("Tentative de récupération des danmaku : " .. query)

    local servers = get_api_server_list(options.api_server)

    -- Exclut les serveurs pointant vers dandanplay.net
    local filtered = {}
    for _, s in ipairs(servers) do
        if type(s) == "string" and not s:lower():find("dandanplay%.net") then
            table.insert(filtered, s)
        end
    end
    servers = filtered
    if #servers == 0 then
        get_danmaku_fallback(query)
        return
    end

    local matched = false
    local cancel_fn = nil

    local function build_args(server)
        local url = server .. "/api/v2/extcomment?url=" .. url_encode(query)
        return make_danmaku_request_args("GET", url)
    end

    local function per_response(server, err, out)
        if matched then return end
        if err then
            msg.debug(("extcomment failed for %s: %s"):format(server, tostring(err)))
            return
        end
        local data = utils.parse_json(out)
        data = normalize_danmaku_response(data)
        if not data or not data["comments"] or data["count"] <= 1 then
            return
        end
        matched = true
        -- Enregistre puis charge les danmaku
        save_danmaku_data(data["comments"], query, "user_custom")
        load_danmaku(from_menu)
        -- Annule les autres requêtes en cours
        if cancel_fn then pcall(cancel_fn) end
    end

    local function final_cb()
        if not matched then
            -- Si aucun serveur ne renvoie de danmaku valide, utilise le serveur de secours
            msg.info("Aucun serveur n'a fourni de danmaku valide ; essai du serveur de secours")
            get_danmaku_fallback(query)
        end
    end

    cancel_fn = parallel_requests(servers, build_args, per_response, final_cb, { concurrency = 3, per_request_timeout = 60 })
end

-- Convertit les danmaku en table Lua
function save_danmaku_to_list(comments)
    local danmaku_list = {}

    for _, comment in ipairs(comments) do
        local p = comment["p"]
        local shift = comment["shift"]
        if p then
            local fields = split(p, ",")
            if shift ~= nil then
                fields[1] = tonumber(fields[1]) + tonumber(shift)
            end
            local time = tonumber(fields[1])
            local type = tonumber(fields[2])
            local color = tonumber(fields[3]) or 0xFFFFFF
            local size = 25
            local m_value = comment["m"]
                            :gsub("[%z\1-\31]", "")
                            :gsub("\\", "")
                            :gsub("\"", "")
            table.insert(danmaku_list, {
                time = time,
                type = type,
                size = size,
                color = color,
                text = m_value
            })
        end
    end

    return danmaku_list
end

-- Associe les danmaku avec le hachage des 16 premiers Mio du fichier
function get_danmaku_with_hash(file_name, file_path)
    if type(MD5) ~= "table" or not MD5.sum then
        msg.warn("Le module MD5 ne prend pas en charge Lua 5.1 ; recours à la correspondance par nom de fichier")
        match_anime()
        return
    end
    if is_protocol(file_path) then
        set_danmaku_button()
        local temp_file = "temp-" .. PID .. ".mp4"
        local arg = {
            "curl",
            "--connect-timeout",
            "10",
            "--max-time",
            "30",
            "--range",
            "0-16777215",
            "--user-agent",
            options.user_agent,
            "--output",
            utils.join_path(DANMAKU_PATH, temp_file),
            "-L",
            file_path,
        }

        if options.proxy ~= "" then
            table.insert(arg, '-x')
            table.insert(arg, options.proxy)
        end

        call_cmd_async(arg, function(error)
            file_path = utils.join_path(DANMAKU_PATH, temp_file)

            match_file(file_path, file_name, function(error)
                if error then
                    msg.error(error)
                    msg.info("Tentative de récupération des danmaku à partir du nom de fichier")
                    match_anime()
                end
            end)
        end)
    else
        local dir = get_parent_directory(file_path)
        local excluded_path = utils.parse_json(options.excluded_path)
        if PLATFORM == "windows" then
            for i, path in pairs(excluded_path) do
                excluded_path[i] = path:gsub("/", "\\")
            end
        end
        if contains_any(excluded_path, dir) then
            match_anime()
            return
        end
        match_file(file_path, file_name, function(error)
            if error then
                msg.error(error)
                msg.info("Tentative de récupération des danmaku à partir du nom de fichier")
                match_anime()
            end
        end)
    end
end
