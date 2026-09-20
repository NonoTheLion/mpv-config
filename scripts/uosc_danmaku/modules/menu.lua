local msg = require('mp.msg')
local utils = require("mp.utils")
local unpack = unpack or table.unpack

input_loaded, input = pcall(require, "mp.input")
uosc_available = false
latest_menu_anime = {}
local active_request_cancel = nil
local active_request_type = nil
local request_cancelled = false

-- Supprime le premier élément de chargement de latest_menu_anime s'il existe (compatible avec les propriétés de menu complètes et les tableaux items)
local function strip_loading_from_latest_menu_anime()
    if not latest_menu_anime or #latest_menu_anime == 0 then return end
    local parsed = utils.parse_json(latest_menu_anime)
    if not parsed or type(parsed) ~= "table" then return end
    local function is_loading_item(it)
        if not it or type(it) ~= "table" then return false end
        if it.title == "Chargement des données…" then return true end
        if it.italic == true and it.icon == "spinner" then return true end
        return false
    end
    if parsed.items and type(parsed.items) == "table" then
        if #parsed.items > 0 and is_loading_item(parsed.items[1]) then
            table.remove(parsed.items, 1)
            latest_menu_anime = utils.format_json(parsed)
        end
    else
        if #parsed > 0 and is_loading_item(parsed[1]) then
            table.remove(parsed, 1)
            latest_menu_anime = utils.format_json(parsed)
        end
    end
end

-- Annule les requêtes concurrentes : pose le drapeau d'annulation, retire l'élément de chargement et appelle la fonction d'annulation
local function perform_cancel_active_request(expected_type)
    if expected_type and active_request_type and tostring(expected_type) ~= tostring(active_request_type) then
        return
    end
    if active_request_cancel then
        request_cancelled = true
        strip_loading_from_latest_menu_anime()
        pcall(active_request_cancel)
        active_request_cancel = nil
        active_request_type = nil
    end
end

local function make_build_args(encoded_query)
    return function(server)
        local url = server .. "/api/v2/search/anime"
        local full_url = url .. "?keyword=" .. encoded_query
        return make_danmaku_request_args("GET", full_url)
    end
end

local function make_handle_response(ctx)
    return function(server, err, out)
        if request_cancelled then
            ctx.remaining.n = math.max(0, ctx.remaining.n - 1)
            return
        end

        local function do_final_update()
            local final_items = {}
            -- Assemble les résultats dans l'ordre des serveurs configurés
            for _, srv in ipairs(ctx.server_order or {}) do
                local list = ctx.server_items and ctx.server_items[srv]
                if list and type(list) == 'table' then
                    for _, v in ipairs(list) do table.insert(final_items, v) end
                end
            end
            if request_cancelled then return end
            if uosc_available then
                latest_menu_anime = update_menu_uosc(ctx.menu_type, ctx.menu_title, final_items, ctx.footnote, ctx.menu_cmd, ctx.query)
            else
                latest_menu_anime = utils.format_json(final_items)
                if input_loaded then
                    input.terminate()
                    mp.add_timeout(0.1, function()
                        open_menu_select(final_items)
                    end)
                end
            end
        end

        if err then
            msg.debug(("search anime failed for %s: %s"):format(server, tostring(err)))
            ctx.remaining.n = math.max(0, ctx.remaining.n - 1)
            if ctx.remaining.n == 0 then pcall(do_final_update) end
            return
        end
        local data = utils.parse_json(out)
        if not data or not data.animes then
            ctx.remaining.n = math.max(0, ctx.remaining.n - 1)
            if ctx.remaining.n == 0 then pcall(do_final_update) end
            return
        end
        for _, anime in ipairs(data.animes) do
            local key = anime.bangumiId or (anime.animeTitle and anime.animeTitle:gsub("%s+", " ") or nil)
            if key and not ctx.seen[key] then
                ctx.seen[key] = true
                ctx.server_items[server] = ctx.server_items[server] or {}
                local note = (ctx.server_notes and ctx.server_notes[server]) or nil
                local hint = anime.typeDescription
                if note and note ~= "" then
                    if hint and hint ~= "" then
                        hint = hint .. "|" .. note
                    else
                        hint = note
                    end
                end
                table.insert(ctx.server_items[server], {
                    title = anime.animeTitle,
                    hint = hint,
                    value = { "script-message-to", mp.get_script_name(), "search-episodes-event", anime.animeTitle, anime.bangumiId, server },
                })
                ctx.total_count = (ctx.total_count or 0) + 1
            end
        end
        local display_items = {}
        if ctx.remaining.n > 0 then
            local progress_msg = ctx.message or ""
            if ctx.total_servers and ctx.total_servers > 1 and ctx.remaining and ctx.remaining.n then
                local completed = math.max(0, (ctx.total_servers - ctx.remaining.n) + 1)
                progress_msg = tostring(progress_msg):gsub("%.+$", "")
                progress_msg = progress_msg .. string.format("（%d/%d）...", completed, ctx.total_servers)
            end
            table.insert(display_items, {
                title = progress_msg,
                value = "",
                italic = true,
                keep_open = true,
                selectable = false,
                icon = "spinner",
            })
        end
        -- Assemble les résultats reçus selon server_order
        for _, srv in ipairs(ctx.server_order or {}) do
            local list = ctx.server_items and ctx.server_items[srv]
            if list and type(list) == 'table' then
                for _, v in ipairs(list) do table.insert(display_items, v) end
            end
        end

        if uosc_available then
            latest_menu_anime = update_menu_uosc(ctx.menu_type, ctx.menu_title, display_items, ctx.footnote, ctx.menu_cmd, ctx.query,
                { "script-message-to", mp.get_script_name(), "cancel-active-request", ctx.menu_type })
        else
            if not ctx.first_opened.val and input_loaded and (ctx.total_count or 0) > 0 then
                ctx.first_opened.val = true
                show_message("", 0)
                input.terminate()
                mp.add_timeout(0.1, function()
                    latest_menu_anime = utils.format_json(display_items)
                    open_menu_select(display_items)
                end)
            end
        end

        ctx.remaining.n = math.max(0, ctx.remaining.n - 1)
        if ctx.remaining.n == 0 then
            pcall(do_final_update)
        end
    end
end

-- Ouvre le menu de correspondance des séries
function get_animes(query, filter_note)
    local encoded_query = url_encode(query)
    local all_metas = get_api_server_list(options.api_server, true)
    local server_hint = ""
    local server_metas = {}
    if filter_note and filter_note ~= "" then
        local matched = {}
        for _, m in ipairs(all_metas) do
            if m.note and m.note == filter_note then
                table.insert(matched, m)
            end
        end
        if #matched > 0 then
            server_metas = { matched[1] }  -- Ne conserve que la première correspondance
            server_note = "Serveur « " .. filter_note .. " »"
        else
            show_message("Aucun serveur portant la note « " .. filter_note .. " » n'a été trouvé ; tous les serveurs seront utilisés", 3)
            msg.info("Aucun serveur portant la note « " .. filter_note .. " » n'a été trouvé ; tous les serveurs seront utilisés")
            server_metas = all_metas
        end
    else
        server_metas = all_metas
    end

    local servers = {}
    local server_notes = {}
    for _, m in ipairs(server_metas) do
        table.insert(servers, m.url)
        if m.note and m.note ~= '' then
            server_notes[m.url] = m.note
        end
    end

    local items = {}
    local seen = {}
    local first_opened = false
    local remaining = #servers
    local total_servers = remaining
    local server_items = {}
    local server_order = servers
    local total_count = 0
    request_cancelled = false

    local message = server_hint .. "Chargement des données…"
    local menu_type = "menu_anime"
    local menu_title = "Saisissez ici le titre de la série"
    local footnote = "Appuyez sur Entrée ou Ctrl+Entrée pour rechercher"
    local menu_cmd = { "script-message-to", mp.get_script_name(), "search-anime-event" }

    local function strip_trailing_dots(s)
        if not s then return "" end
        return tostring(s):gsub("%.+$", "")
    end

    local initial_message = message
    if total_servers and total_servers > 1 then
        initial_message = strip_trailing_dots(message) .. string.format("（%d/%d）...", 0, total_servers)
    end
    if uosc_available then
        active_request_type = menu_type
        update_menu_uosc(menu_type, menu_title, initial_message, footnote, menu_cmd, query, "spinner",
            { "script-message-to", mp.get_script_name(), "cancel-active-request", menu_type })
    else
        show_message(initial_message, 30)
    end

    msg.verbose("Tentative de récupération des données de la série, serveurs : " .. table.concat(servers, ", ") .. " query: " .. query)

    local build_args = make_build_args(encoded_query)

    -- Construit ctx pour permettre à la fermeture handle_response d'accéder à l'état partagé et de le modifier
    local ctx = {
        items = items,
        seen = seen,
        first_opened = { val = first_opened },
        remaining = { n = remaining },
        message = message,
        total_servers = total_servers,
        menu_type = menu_type,
        menu_title = menu_title,
        footnote = footnote,
        menu_cmd = menu_cmd,
        query = query,
        server_items = server_items,
        server_order = server_order,
        server_notes = server_notes,
        total_count = total_count,
    }

    local handle_response = make_handle_response(ctx)

    local cancel_fn = parallel_requests(servers, build_args, handle_response, function()
        if request_cancelled then return end
        local final_items = {}
        for _, srv in ipairs(ctx.server_order or {}) do
            local list = ctx.server_items and ctx.server_items[srv]
            if list and type(list) == 'table' then
                for _, v in ipairs(list) do table.insert(final_items, v) end
            end
        end
        if uosc_available then
            latest_menu_anime = update_menu_uosc(ctx.menu_type, ctx.menu_title, final_items, ctx.footnote, ctx.menu_cmd, ctx.query)
        else
            latest_menu_anime = utils.format_json(final_items)
            if not ctx.first_opened.val and input_loaded and #final_items > 0 then
                ctx.first_opened.val = true
                show_message("", 0)
                input.terminate()
                mp.add_timeout(0.1, function()
                    open_menu_select(final_items)
                end)
            end
        end
    end, { concurrency = 5, per_request_timeout = 60 })
    active_request_cancel = cancel_fn
    active_request_type = menu_type
end

function get_episodes(animeTitle, bangumiId, api_server)
    local url = api_server .. "/api/v2/bangumi/" .. bangumiId
    local items = {}

    local message = "Chargement des données…"
    local menu_type = "menu_episodes"
    local menu_title = "Informations sur les épisodes"
    local footnote = "Appuyez sur / pour filtrer"

    if uosc_available then
        active_request_type = menu_type
        update_menu_uosc(menu_type, menu_title, message, footnote, nil, nil, "spinner",
            { "script-message-to", mp.get_script_name(), "cancel-active-request", menu_type })
    else
        show_message(message, 30)
    end

    local args = make_danmaku_request_args("GET", url)

    if args == nil then
        return
    end

    request_cancelled = false
    active_request_type = menu_type
    active_request_cancel = call_cmd_async(args, function(err, stdout)
        active_request_cancel = nil
        if request_cancelled then
            return
        end

        table.insert(items, {
            title = "↩️ Retour aux résultats de recherche",
            value = { "script-message-to", mp.get_script_name(), "open-latest-menu-anime", latest_menu_anime },
            keep_open = false,
            selectable = true,
        })

        if err then
            local message = "Échec de la récupération des données"
            if uosc_available then
                table.insert(items, {
                    title = message,
                    value = "",
                    italic = true,
                    keep_open = true,
                    selectable = false,
                    align = "center",
                })
                update_menu_uosc(menu_type, menu_title, items, footnote)
            else
                show_message(message, 3)
            end
            msg.error("Échec de la requête HTTP : " .. tostring(err))
            return
        end

        local response = utils.parse_json(stdout)
        if not response or not response.bangumi or not response.bangumi.episodes then
            local message = "Aucun résultat"
            if uosc_available then
                table.insert(items, {
                    title = message,
                    value = "",
                    italic = true,
                    keep_open = true,
                    selectable = false,
                    align = "center",
                })
                update_menu_uosc(menu_type, menu_title, items, footnote)
            else
                show_message(message, 3)
            end
            msg.info(message)
            return
        end

        for _, episode in ipairs(response.bangumi.episodes) do
            table.insert(items, {
                title = episode.episodeTitle,
                hint = episode.episodeNumber,
                value = { "script-message-to", mp.get_script_name(), "load-danmaku",
                animeTitle, episode.episodeTitle, episode.episodeId, api_server },
                keep_open = false,
                selectable = true,
            })
        end

        -- ====== Met à jour latest_menu_anime ======
        if latest_menu_anime and latest_menu_anime ~= "" then
            local menu_table = utils.parse_json(latest_menu_anime)
            if menu_table and type(menu_table.items) == "table" then
                for i, back_item in ipairs(menu_table.items) do
                    if type(back_item.value) == "table" and
                    back_item.value[5] == bangumiId and back_item.value[6] == api_server then
                        menu_table.items[i].footnote = mp.get_property("filename")
                        menu_table.items[i].items = { unpack(items, 2) }
                        break
                    end
                end
                latest_menu_anime = utils.format_json(menu_table)
            end
        end

        if uosc_available then
            footnote = mp.get_property("filename")
            update_menu_uosc(menu_type, menu_title, items, footnote)
        elseif input_loaded then
            show_message("", 0)
            input.terminate()
            mp.add_timeout(0.1, function()
                open_menu_select(items)
            end)
        end
    end)
    active_request_type = menu_type
end

function update_menu_uosc(menu_type, menu_title, menu_item, menu_footnote, menu_cmd, query, message_icon, on_close)
    local items = {}
    if type(menu_item) == "string" then
        table.insert(items, {
            title = menu_item,
            value = "",
            italic = true,
            keep_open = true,
            selectable = false,
            align = "center",
            icon = message_icon or "",
        })
    else
        items = menu_item
    end

    local menu_props = {
        type = menu_type,
        title = menu_title,
        search_style = menu_cmd and "palette" or "on_demand",
        search_debounce = menu_cmd and "submit" or 0,
        on_search = menu_cmd,
        footnote = menu_footnote,
        search_suggestion = query,
        items = items,
    }

    if on_close ~= nil then
        menu_props.on_close = on_close
    end

    local current_menu_type = mp.get_property_native('user-data/uosc/menu/type')
    local cmd = "open-menu"
    if current_menu_type and tostring(current_menu_type) == tostring(menu_type) then
        cmd = "update-menu"
    end

    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", cmd, json_props)

    return json_props
end

function open_menu_select(menu_items, is_time)
    local item_titles, item_values = {}, {}
    for i, v in ipairs(menu_items) do
        item_titles[i] = is_time and "[" .. v.hint .. "] " .. v.title or
            (v.hint and v.title .. " (" .. v.hint .. ")" or v.title)
        item_values[i] = v.value
    end
    mp.commandv('script-message-to', 'console', 'disable')
    input.select({
        prompt = is_time and 'Filtrer :' or 'Sélectionner :',
        items = item_titles,
        submit = function(id)
            input.terminate()
            perform_cancel_active_request()
            local v = item_values[id]
            if type(v) == 'table' then
                mp.commandv(unpack(v))
            elseif type(v) == 'string' then
                mp.command(v)
            end
        end,
        closed = function()
            show_message("", 0)
            input.terminate()
            perform_cancel_active_request()
        end,
    })
end

-- Ouvre le menu de recherche de danmaku
function open_input_menu_get()
    mp.commandv('script-message-to', 'console', 'disable')
    local title = parse_title()
    input.get({
        prompt = 'Titre de la série :',
        default_text = title,
        cursor_position = title and #title + 1,
        submit = function(text)
            input.terminate()
            mp.commandv("script-message-to", mp.get_script_name(), "search-anime-event", text)
        end
    })
end

function open_input_menu_uosc()
    local items = {}

    if DANMAKU.anime and DANMAKU.episode then
        local episode = DANMAKU.episode:gsub("%s.-$","")
        episode = episode:match("^(第.*[话回集]+)%s*") or episode
        items[#items + 1] = {
            title = string.format("Danmaku associés : %s-%s", DANMAKU.anime, episode),
            bold = true,
            italic = true,
            keep_open = true,
            selectable = false,
        }
    end

    items[#items + 1] = {
        hint = "  Ajouter | ds, dy ou dm permet de rechercher des séries, films ou animations chinoises",
        keep_open = true,
        selectable = false,
    }

    local menu_props = {
        type = "menu_danmaku",
        title = "Saisissez ici le titre de la série",
        search_style = "palette",
        search_debounce = "submit",
        search_suggestion = parse_title(),
        on_search = { "script-message-to", mp.get_script_name(), "search-anime-event" },
        footnote = "Appuyez sur Entrée ou Ctrl+Entrée pour rechercher",
        items = items
    }
    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", "open-menu", json_props)
end

function open_input_menu()
    if uosc_available then
        open_input_menu_uosc()
    elseif input_loaded then
        mp.add_timeout(0.01, function()
            open_input_menu_get()
        end)
    end
end

-- Ouvre le menu d'ajout et de gestion des sources de danmaku
function open_add_menu_get()
    local menu_log, deal_value = {}, {}

    -- Fonction de reconstruction du contenu du menu
    local function rebuild_menu_log(select_num)
        deal_value = {}
        menu_log = {
            { text = "【Sources de danmaku existantes】", style = "{\\c&H00CCFF&\\b1}" },
            { text = "----------------------------", style = "{\\c&H888888&}" }
        }

        local serial = 0
        for url, source in pairs(DANMAKU.sources) do
            if source.data then
                if source.from == "api_server" then
                    serial = serial + 1
                    local action = source.blocked and "unblock" or "block"
                    local text = string.format("  [%02d] %s [source : serveur de danmaku%s]  ", serial, url,
                        source.blocked and " (bloquée)" or " (active)")
                    local style = (tonumber(select_num) == serial) and "{\\c&HFFDE7F&\\b1}" or (action == "unblock" and "{\\c&H4C4CC3&\\b0}" or "{\\c&HCCCCCC&\\b0}")
                    deal_value[serial] = {value = url, action = action}
                    table.insert(menu_log, {text = text, style = style})
                else
                    serial = serial + 1
                    local action1 = source.blocked and "unblock" or "block"
                    local text1 = string.format("  [%02d] %s [source : ajoutée par l'utilisateur]%s  ", serial, url, source.blocked and " (bloquée)" or " (active)")
                    local style1 = (tonumber(select_num) == serial) and "{\\c&HFFDE7F&\\b1}" or (action1 == "unblock" and "{\\c&H4C4CC3&\\b0}" or "{\\c&HCCCCCC&\\b0}")
                    deal_value[serial] = {value = url, action = action1}
                    table.insert(menu_log, {text = text1, style = style1})

                    serial = serial + 1
                    local action2 = "delete"
                    local text2 = string.format("  [%02d] %s [source : ajoutée par l'utilisateur] (supprimer)  ", serial, url)
                    local style2 = (tonumber(select_num) == serial) and "{\\c&HFFDE7F&\\b1}" or "{\\c&HCCCCCC&\\b0}"
                    deal_value[serial] = {value = url, action = action2}
                    table.insert(menu_log, {text = text2, style = style2})
                end
            end
        end

        if serial == 0 then
            table.insert(menu_log, { text = "        Aucune", style = "" })
        end
    end

    -- Affiche le menu
    local function show_menu(extra_lines, select_num)
        rebuild_menu_log(select_num)

        local display = {}
        for _, item in ipairs(menu_log) do table.insert(display, item) end
        table.insert(display, { text = "----------------------------", style = "{\\c&H888888&}" })

        if extra_lines then
            if #extra_lines < 2 then table.insert(display, { text = "\n", style = "" }) end
            for _, line in ipairs(extra_lines) do table.insert(display, line) end
        else
            table.insert(display, { text = "\n", style = "" })
            table.insert(display, {
                text = "Conseil : saisissez le numéro d’une option pour bloquer ou supprimer une source existante",
                style = "{\\c&H999999&}"
            })
        end

        input.set_log(display)
    end

    -- Renvoie l'indication correspondant à l'action
    local function get_hint(action)
        local hints = {
            block = "Appuyez sur Entrée pour bloquer cette source",
            unblock = "Appuyez sur Entrée pour débloquer cette source",
            delete = "Appuyez sur Entrée pour supprimer cette source"
        }
        return hints[action] or "Appuyez sur Entrée pour charger les danmaku de l'URL saisie"
    end

    input.get({
        keep_open = true,
        prompt = "Saisissez ici l'URL de la source : ",
        opened = function() show_menu() end,
        edited = function(text)
            text = text:gsub("^%s*(.-)%s*$", "%1")

            if text == "" then
                show_menu()
                return
            end

            local num = tonumber(text)
            local event = num and deal_value[num]
            local hint = get_hint(event and event.action)

            show_menu({
                { text = string.format("Saisie : %s", text), style = "{\\c&HCCCCCC&}" },
                { text = hint, style = "{\\c&H999999&}" }
            }, text)
        end,
        submit = function(text)
            text = text:gsub("^%s*(.-)%s*$", "%1")
            if text == "" then return end

            local num = tonumber(text)
            local event = num and deal_value[num]

            if event then
                local args = string.format('{"type":"activate","value":"%s","action":"%s"}',
                    string.gsub(event.value, '\\', '\\\\'), event.action)
                mp.commandv("script-message-to", mp.get_script_name(), "setup-danmaku-source", args)
            else
                input.terminate()
                mp.commandv("script-message-to", mp.get_script_name(), "add-source-event", text)
            end

            mp.add_timeout(0.1, show_menu)
        end
    })
end

function open_add_menu_uosc()
    local sources = {}
    for url, source in pairs(DANMAKU.sources) do
        if source.data then
            local count = #source.data  -- Nombre de danmaku
            local count_text = string.format(" (%d) danmaku", count)
            local item = {title = utf8_sub(url, 1, 100), value = url, keep_open = true,}
            if source.from == "api_server" then
                if source.blocked then
                    item.hint = "source : serveur de danmaku (bloquée)"
                    item.actions = {{icon = "check", name = "unblock", label = "Débloquer" .. count_text},}
                else
                    item.hint = "source : serveur de danmaku (active)"
                    item.actions = {{icon = "not_interested", name = "block", label = "Bloquer" .. count_text},}
                end
            else
                item.hint = "source : ajoutée par l'utilisateur"
                if source.blocked then
                    item.actions = {
                        {icon = "check", name = "unblock", label = "Débloquer" .. count_text},
                        {icon = "delete", name = "delete", label = "Supprimer" .. count_text},
                    }
                else
                    item.actions = {
                        {icon = "not_interested", name = "block", label = "Bloquer" .. count_text},
                        {icon = "delete", name = "delete", label = "Supprimer" .. count_text},
                    }
                end
            end
            table.insert(sources, item)
        end
    end
    local menu_props = {
        type = "menu_source",
        title = "Saisissez ici l'URL de la source",
        search_style = "palette",
        search_debounce = "submit",
        on_search = { "script-message-to", mp.get_script_name(), "add-source-event" },
        footnote = "Appuyez sur Entrée ou Ctrl+Entrée pour ajouter",
        items = sources,
        item_actions_place = "outside",
        callback = {mp.get_script_name(), 'setup-danmaku-source'},
    }
    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", "open-menu", json_props)
end

function open_add_menu()
    if uosc_available then
        open_add_menu_uosc()
    elseif input_loaded then
        mp.add_timeout(0.01, function()
            open_add_menu_get()
        end)
    end
end

-- Ouvre le menu du contenu des danmaku
function open_content_menu(pos)
    local items = {}
    local time_pos = pos or mp.get_property_native("time-pos")
    local duration = mp.get_property_number("duration", 0)

    if COMMENTS ~= nil then
        for _, event in ipairs(COMMENTS) do
            local text = event.clean_text:gsub("^m%s[mbl%s%-%d%.]+$", ""):gsub("^%s*(.-)%s*$", "%1")
            local delay = event.delay
            local start_time = event.start_time
            local end_time = event.end_time
            if text and text ~= "" and start_time >= 0 and start_time <= duration then
                local delay_label_suffix = nil
                local delay_num = delay and tonumber(delay)
                if delay_num and math.abs(delay_num) > 0 then
                    delay_label_suffix = string.format("Décalage existant : %+0.1fs", delay_num)
                end

                local adjust_label = 'Régler le décalage des danmaku'
                if delay_label_suffix then
                    adjust_label = adjust_label .. '（' .. delay_label_suffix .. '）'
                end

                table.insert(items, {
                    title = abbr_str(text, 60),
                    hint = seconds_to_time(start_time) .. "  (" .. utf8_sub(remove_query(event.source), 1, 70) .. ")",
                    actions = {
                        {
                            name = 'block_source',
                            icon = 'block',
                            label = 'Bloquer la source correspondante'
                        },
                        {
                            name = 'adjust_delay',
                            icon = 'more_time',
                            label = adjust_label,
                        },
                    },
                    value = { "seek", start_time, "absolute" },
                    active = time_pos >= start_time and time_pos <= end_time,
                })
            end
        end
    end

    local menu_props = {
        type = "menu_content",
        title = "Contenu des danmaku",
        footnote = "Appuyez sur / pour rechercher",
        items = items,
        item_actions_place = "outside",
        callback = {mp.get_script_name(), 'handle-danmaku-content-action'},
    }
    local json_props = utils.format_json(menu_props)

    if uosc_available then
        mp.commandv("script-message-to", "uosc", "open-menu", json_props)
    elseif input_loaded then
        open_menu_select(items, true)
    end
end

local menu_items_config = {
    bold = { title = "Gras", hint = options.bold, original = options.bold,
        footnote = "true / false", },
    fontsize = { title = "Taille", hint = options.fontsize, original = options.fontsize,
        scope = { min = 0, max = math.huge }, footnote = "Saisissez un entier (≥ 0)", },
    outline = { title = "Contour", hint = options.outline, original = options.outline,
        scope = { min = 0.0, max = 4.0 }, footnote = "Plage autorisée : 0,0 à 4,0" },
    shadow = { title = "Ombre", hint = options.shadow, original = options.shadow,
        scope = { min = 0, max = math.huge }, footnote = "Saisissez un entier (≥ 0)", },
    scrolltime = { title = "Vitesse", hint = options.scrolltime, original = options.scrolltime,
        scope = { min = 1, max = math.huge }, footnote = "Saisissez un entier (≥ 1)", },
    opacity = { title = "Opacité", hint = options.opacity, original = options.opacity,
        scope = { min = 0, max = 1 }, footnote = "Plage : 0 (transparent) à 1 (opaque)", },
    displayarea = { title = "Zone d'affichage des danmaku", hint = options.displayarea, original = options.displayarea,
        scope = { min = 0.0, max = 1.0 }, footnote = "Zone d'affichage (0,0–1,0)", },
}
-- Crée la liste ordonnée des clés utilisée pour disposer le menu de style
local ordered_keys = {"bold", "fontsize", "outline", "shadow", "scrolltime", "opacity", "displayarea"}

-- Configure le menu de style des danmaku
function open_style_menu_get(query, indicator)
    mp.commandv('script-message-to', 'console', 'disable')
    local menu_log = {}

    local select_num = 0
    local select_query = nil
    if query then
        if tonumber(query) ~= nil then
            select_num = tonumber(query)
        else
            for i, v in ipairs(ordered_keys) do
                if v == query then
                    select_num = i
                end
            end
        end
        select_query = ordered_keys[select_num]
    end

    local function build_menu(source)
        menu_log = {
            { text = "【Style des danmaku】", style = "{\\c&H00CCFF&\\b1}" },
            { text = ("-"):rep(33), style = "{\\c&H888888&}" }
        }

        local serial = 0
        for _, key in ipairs(ordered_keys) do
            serial = serial + 1
            local config = menu_items_config[key]
            local text = string.format("  [%02d] %s   [Actuel : %s] ", serial, config.title, config.hint)
            text = config.hint ~= config.original and text .. "⟳" or text
            local style = serial == select_num and "{\\c&HFFDE7F&}" or "{\\c&HCCCCCC&}"
            local item_config = { text = text, style = style }
            table.insert(menu_log, item_config)
        end

        table.insert(menu_log, { text = ("-"):rep(33), style = "{\\c&H888888&}" })
        if select_num == 0 then
            table.insert(menu_log, {
                text = "Remarque : les changements de style ne valent que pour cette lecture",
                style = "{\\c&HFFDE7F&}"
            })
            table.insert(menu_log, {
                text = "Conseil : saisissez « w » pour monter et « s » pour descendre",
                style = "{\\c&H999999&}"
            })
        else
            local input_text = source and source or ""
            local config = menu_items_config[select_query]
            local suffix = ""
            if config and config.hint ~= config.original then
                suffix = " (saisissez \\r pour rétablir la valeur par défaut)"
            end
            input_text = string.format("Saisie%s : %s", suffix, input_text)

            local scope = config and config.footnote or ""
            local hint_text = select_query == "bold" and "Conseil : saisissez « y » pour changer l’état" or "Conseil : " .. scope
            local hint_style = "{\\c&H999999&}"
            if source and source:lower() == "\\r" then
                hint_text = string.format("Conseil : Entrée rétablira la valeur par défaut < %s >", config.original)
            end
            if indicator == "refresh" or indicator == "updata" then
                indicator = ""
                hint_text = "Conseil : Style modifié"
                hint_style = "{\\c&HFFDE7F&}"
                mp.add_timeout(1.5, build_menu)
            elseif indicator == "error" then
                indicator = ""
                hint_text = "Conseil : Saisie non numérique ou hors limites"
                hint_style = "{\\c&H4C4CC3&}"
                mp.add_timeout(1.5, build_menu)
            end

            table.insert(menu_log, { text = input_text, style = "{\\c&HCCCCCC&}" })
            table.insert(menu_log, { text = hint_text, style = hint_style })
        end
        input.set_log(menu_log)
    end

    input.get({
        keep_open = true,
        prompt = "Saisissez une action (w/s | monter/descendre) : ",
        opened = function() build_menu() end,
        edited = function(text)
            text = text:gsub("^%s*(.-)%s*$", "%1")

            if text == "" then
                build_menu()
                return
            end

            if text:lower() == "w" or text:lower() == "s" then
                input.terminate()
                select_num = text:lower() == "w" and select_num - 1 or select_num + 1
                select_num = (select_num > #ordered_keys) and 1 or (select_num <= 0 and #ordered_keys or select_num)
                mp.add_timeout(0.01, function()
                    open_style_menu_get(select_num)
                end)
                return
            end

            build_menu(text)
        end,
        submit = function(text)
            if select_query == nil then return end
            text = text:gsub("^%s*(.-)%s*$", "%1")
            if text == "" then return end

            if text:lower() == "\\r" then
                input.terminate()
                local args = string.format('{"type":"activate","action":"%s","index":%d}', select_query, select_num)
                mp.commandv("script-message-to", mp.get_script_name(), "setup-danmaku-style", args)
            else
                if menu_items_config[select_query]["scope"] ~= nil then
                    input.terminate()
                    mp.commandv("script-message-to", mp.get_script_name(), "setup-danmaku-style", select_query, text)
                elseif text:lower() == "y" and select_query == "bold" then
                    input.terminate()
                    local args = string.format('{"type":"activate","index":%d}', select_num)
                    mp.commandv("script-message-to", mp.get_script_name(), "setup-danmaku-style", args)
                end
            end
            return
        end
    })
end

function open_style_menu_uosc(actived, status)
    local items = {}
    for _, key in ipairs(ordered_keys) do
        local config = menu_items_config[key]
        local item_config = {
            title = config.title,
            hint = "Actuel : " .. tostring(config.hint),
            active = key == actived,
            keep_open = true,
            selectable = true,
        }
        if config.hint ~= config.original then
            local original_str = tostring(config.original)
            item_config.actions = {{icon = "refresh", name = key, label = "Rétablir la valeur par défaut < " .. original_str .. " >"}}
        end
        table.insert(items, item_config)
    end

    local menu_props = {
        type = "menu_style",
        title = "Style des danmaku",
        search_style = "disabled",
        footnote = "Les changements de style ne valent que pour cette lecture",
        item_actions_place = "outside",
        items = items,
        callback = { mp.get_script_name(), 'setup-danmaku-style'},
    }

    local actions = "open-menu"
    if status ~= nil then
        -- msg.info(status)
        if status == "updata" then
            -- Le mode « updata » conserve le texte du champ
            menu_props.title = "  " .. menu_items_config[actived]["footnote"]
            actions = "update-menu"
        elseif status == "refresh" then
            -- Le mode « refresh » efface le texte du champ
            menu_props.title = "  " .. menu_items_config[actived]["footnote"]
        elseif status == "error" then
            menu_props.title = "Saisie non numérique ou hors limites"
            -- Crée une minuterie qui efface le message d’erreur du champ après une seconde
            mp.add_timeout(1.0, function() open_style_menu_uosc(actived, "updata") end)
        end
        menu_props.search_style = "palette"
        menu_props.search_debounce = "submit"
        menu_props.footnote = menu_items_config[actived]["footnote"] or ""
        menu_props.on_search = { "script-message-to", mp.get_script_name(), "setup-danmaku-style", actived }
    end

    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", actions, json_props)
end

function open_style_menu(actived, status)
    if uosc_available then
        open_style_menu_uosc(actived, status)
    elseif input_loaded then
        mp.add_timeout(0.01, function()
            open_style_menu_get(actived, status)
        end)
    else
        show_message("Aucune interface compatible n'est disponible ; cette fonction est indisponible", 3)
    end
end

-- Ouvre le menu de décalage à partir de l'instant indiqué
function open_delay_from_time_get(source, time, status)
    mp.commandv('script-message-to', 'console', 'disable')
    local menu_log = {}

    local function build_menu(query, input_text)
        menu_log = {
            { text = "【Régler le décalage à partir de cet instant】", style = "{\\c&H00CCFF&\\b1}" },
            { text = ("-"):rep(33), style = "{\\c&H888888&}" }
        }

        table.insert(menu_log, { text = "\n", style = "" })
        local hint_text = "Saisissez un nombre de secondes, ou une durée au format \"14m15s\""
        local hint_style = "{\\c&H999999&}"
        if status == "error" then
            hint_text = "Conseil : Saisie non numérique ou hors limites"
            hint_style = "{\\c&H4C4CC3&}"
        end

        table.insert(menu_log, { text = input_text and ("Saisie : " .. input_text) or "", style = "{\\c&HCCCCCC&}" })
        table.insert(menu_log, { text = hint_text, style = hint_style })
        input.set_log(menu_log)
    end

    input.get({
        keep_open = true,
        prompt = "Saisissez le décalage (secondes ou XmYs) : ",
        opened = function() build_menu() end,
        edited = function(text)
            text = text:gsub("^%s*(.-)%s*$", "%1")
            if text == "" then
                build_menu()
                return
            end
            build_menu(text)
        end,
        submit = function(text)
            text = text and text:gsub("^%s*(.-)%s*$", "%1") or ""
            if text == "" then return end
            input.terminate()
            local parsed = parse_delay_input(text)
            if parsed ~= nil then
                mp.commandv("script-message", "danmaku-delay", tostring(parsed), tostring(time), tostring(source))
            else
                open_delay_from_time(time, "error")
            end
        end
    })
end

function open_delay_from_time_uosc(source, time, status)
    if not uosc_available then
        show_message("uosc n'est pas disponible ; cette fonction est indisponible", 2)
        return
    end

    local menu_props = {
        type = "menu_delay_from_time",
        title = "Régler le décalage à partir de cet instant",
        search_style = "palette",
        search_debounce = "submit",
        footnote = "Saisissez un nombre de secondes, ou une durée au format \"14m15s\"",
        items = {},
        on_search = { "script-message-to", mp.get_script_name(), "setup-content-delay", tostring(time), tostring(source) },
    }

    if status == "error" then
    menu_props.title = "Saisie non numérique ou hors limites"
    mp.add_timeout(1.0, function() open_delay_from_time_uosc(source, time) end)
    end

    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", "open-menu", json_props)
end

function open_delay_from_time(source, time, status)
    if uosc_available then
        open_delay_from_time_uosc(source, time, status)
    elseif input_loaded then
        mp.add_timeout(0.01, function()
            open_delay_from_time_get(source, time, status)
        end)
    else
        show_message("Aucune interface compatible n'est disponible ; cette fonction est indisponible", 3)
    end
end

-- Configure le menu de décalage des sources
function open_delay_menu_get(source, status)
    mp.commandv('script-message-to', 'console', 'disable')
    local menu_log = {}

    local serial = 0
    local select_num = 0
    if source and tonumber(source) ~= nil then
        select_num = tonumber(source)
    end
    local select_url = nil

    local function build_menu(query, text)
        menu_log = {
            { text = "【Décalage des sources de danmaku】", style = "{\\c&H00CCFF&\\b1}" },
            { text = ("-"):rep(33), style = "{\\c&H888888&}" }
        }

        serial, select_num = 0, 0
        for url, src in pairs(DANMAKU.sources) do
            if src.data and not src.blocked then
                local delay = 0
                serial = serial + 1
                select_num = (url == source) and serial or select_num
                if src.delay_segments then
                    for _, seg in ipairs(src.delay_segments) do
                        if seg.start == 0 then
                            delay = seg.delay or 0
                            break
                        end
                    end
                end
                local hint = "Décalage actuel de la source : " .. string.format("%.1f", delay + 1e-10) .. " s"
                local text = string.format("  [%02d] %s   [%s] ", serial, url, hint)
                local style = (serial == select_num) and "{\\c&HFFDE7F&}" or "{\\c&HCCCCCC&}"
                table.insert(menu_log, { text = text, style = style })
                select_url = serial == select_num and url or select_url
            end
        end
        if serial == 0 then
            table.insert(menu_log, { text = "        Aucune", style = "" })
        end

        table.insert(menu_log, { text = ("-"):rep(33), style = "{\\c&H888888&}" })
        if select_num == 0 then
            table.insert(menu_log, { text = "\n", style = "" })
            table.insert(menu_log, {
                text = "Conseil : saisissez « w » pour monter et « s » pour descendre",
                style = "{\\c&H999999&}"
            })
        else
            local input_text = "Saisie : " .. (text ~= nil and text or "")

            local hint_text = "Saisissez un nombre de secondes, ou une durée au format \"14m15s\""
            local hint_style = "{\\c&H999999&}"
            if status == "refresh" then
                status = ""
                hint_text = "Conseil : Style modifié"
                hint_style = "{\\c&HFFDE7F&}"
                mp.add_timeout(1.5, build_menu)
            elseif status == "error" then
                status = ""
                hint_text = "Conseil : Saisie non numérique ou hors limites"
                hint_style = "{\\c&H4C4CC3&}"
                mp.add_timeout(1.5, build_menu)
            end

--            table.insert(menu_log, { text = input_text, style = "{\\c&HCCCCCC&}" })
            table.insert(menu_log, { text = input_text, style = "{\\c&HCCCCCC&}" })
            table.insert(menu_log, { text = hint_text, style = hint_style })
        end
        input.set_log(menu_log)
    end

    input.get({
        keep_open = true,
        prompt = "Saisissez une action (w/s | monter/descendre) : ",
        opened = function() build_menu() end,
        edited = function(text)
            text = text:gsub("^%s*(.-)%s*$", "%1")

            if text == "" then
                build_menu()
                return
            end

            if text:lower() == "w" or text:lower() == "s" then
                input.terminate()
                select_num = text:lower() == "w" and select_num - 1 or select_num + 1
                select_num = (select_num > serial) and 1 or (select_num <= 0 and serial or select_num)
                mp.add_timeout(0.01, function()
                    open_delay_menu_get(select_num)
                end)
                return
            end

            build_menu(select_num, text)
        end,
        submit = function(text)
            if select_url == nil then return end
            text = text:gsub("^%s*(.-)%s*$", "%1")
            if text == "" then return end

            input.terminate()
            mp.commandv("script-message-to", mp.get_script_name(), "setup-source-delay", select_url, text)
            return
        end
    })
end

function open_delay_menu_uosc(source_url, status)
    if not uosc_available then
        show_message("uosc n'est pas disponible ; cette fonction est indisponible", 2)
        return
    end

    local sources = {}
    for url, source in pairs(DANMAKU.sources) do
        if source.data and not source.blocked then
            local delay = 0
            if source.delay_segments then
                for _, seg in ipairs(source.delay_segments) do
                    if seg.start == 0 then
                        delay = seg.delay or 0
                        break
                    end
                end
            end
            local item = {title = utf8_sub(url, 1, 100), value = url, keep_open = true,}
            item.hint = "Décalage actuel de la source : " .. string.format("%.1f", delay + 1e-10) .. " s"
            item.active = url == source_url
            table.insert(sources, item)
        end
    end

    local menu_props = {
        type = "menu_delay",
        title = "Décalage des sources de danmaku",
        search_style = "disabled",
        items = sources,
        callback = {mp.get_script_name(), 'setup-source-delay'},
    }
    if source_url ~= nil then
        if status == "error" then
            menu_props.title = "Saisie non numérique ou hors limites"
            -- Crée une minuterie qui efface le message d’erreur du champ après une seconde
            mp.add_timeout(1.0, function() open_delay_menu_uosc(source_url) end)
        else
            menu_props.title = "Saisissez un nombre de secondes, ou une durée au format \"14m15s\""
        end
        menu_props.search_style = "palette"
        menu_props.search_debounce = "submit"
        menu_props.on_search = { "script-message-to", mp.get_script_name(), "setup-source-delay", source_url }
    end

    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", "open-menu", json_props)
end

function open_delay_menu(source, status)
    if uosc_available then
        open_delay_menu_uosc(source, status)
    elseif input_loaded then
        mp.add_timeout(0.01, function()
            open_delay_menu_get(source, status)
        end)
    else
        show_message("Aucune interface compatible n'est disponible ; cette fonction est indisponible", 3)
    end
end

-- Menu principal des danmaku
local total_menu_items_config = {
    { title = "Rechercher des danmaku", action = "open_search_danmaku_menu" },
    { title = "Ajouter des danmaku depuis une source", action = "open_add_source_menu" },
    { title = "Décalage des sources de danmaku", action = "open_source_delay_menu" },
    { title = "Style des danmaku", action = "open_danmaku_style_menu" },
    { title = "Contenu des danmaku", action = "open_content_danmaku_menu" },
}

function open_add_total_menu_uosc()
    local items = {}

    if DANMAKU.anime and DANMAKU.episode then
        local episode = DANMAKU.episode:gsub("%s.-$","")
        episode = episode:match("^(第.*[话回集]+)%s*") or episode
        items[#items + 1] = {
            title = string.format("Danmaku associés : %s-%s", DANMAKU.anime, episode),
            bold = true,
            italic = true,
            keep_open = true,
            selectable = false,
        }
    end

    for _, config in ipairs(total_menu_items_config) do
        table.insert(items, {
            title = config.title,
            value = { "script-message-to", mp.get_script_name(), config.action },
            keep_open = false,
            selectable = true,
        })
    end

    local menu_props = {
        type = "menu_total",
        title = "Paramètres des danmaku",
        search_style = "disabled",
        items = items,
    }
    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", "open-menu", json_props)
end

function open_add_total_menu_select()
    local item_titles, item_values = {}, {}
    for i, config in ipairs(total_menu_items_config) do
        item_titles[i] = config.title
        item_values[i] = { "script-message-to", mp.get_script_name(), config.action }
    end

    mp.commandv('script-message-to', 'console', 'disable')
    input.select({
        prompt = 'Sélectionner :',
        items = item_titles,
        submit = function(id)
            local cmd = item_values[id]
            mp.add_timeout(0.1, function()
                mp.commandv(unpack(cmd))
            end)
        end,
    })
end

function open_add_total_menu()
    if uosc_available then
        open_add_total_menu_uosc()
    elseif input_loaded then
        open_add_total_menu_select()
    end
end

function toggle_danmaku_switch(value)
    mp.commandv("script-message-to", "uosc", "set", "show_danmaku", value)
    mp.set_property_bool(DANMAKU_SWITCH_ON, value == "on")
end

mp.commandv(
    "script-message-to",
    "uosc",
    "set-button",
    "danmaku",
    utils.format_json({
        icon = "search",
        tooltip = "Rechercher des danmaku",
        command = "script-message open_search_danmaku_menu",
    })
)

mp.commandv(
    "script-message-to",
    "uosc",
    "set-button",
    "danmaku_source",
    utils.format_json({
        icon = "add_box",
        tooltip = "Ajouter des danmaku depuis une source",
        command = "script-message open_add_source_menu",
    })
)

mp.commandv(
    "script-message-to",
    "uosc",
    "set-button",
    "danmaku_styles",
    utils.format_json({
        icon = "palette",
        tooltip = "Style des danmaku",
        command = "script-message open_danmaku_style_menu",
    })
)

mp.commandv(
    "script-message-to",
    "uosc",
    "set-button",
    "danmaku_delay",
    utils.format_json({
        icon = "more_time",
        tooltip = "Décalage des sources de danmaku",
        command = "script-message open_source_delay_menu",
    })
)

mp.commandv(
    "script-message-to",
    "uosc",
    "set-button",
    "danmaku_menu",
    utils.format_json({
        icon = "grid_view",
        tooltip = "Paramètres des danmaku",
        command = "script-message open_add_total_menu",
    })
)


mp.register_script_message('uosc-version', function()
    uosc_available = true
end)

mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "off")
mp.register_script_message("set", function(prop, value)
    if prop ~= "show_danmaku" then
        return
    end

    if value == "on" then
        ENABLED = true
        if COMMENTS == nil then
            set_danmaku_visibility(true)
            local path = mp.get_property("path")
            init(path)
        else
            show_loaded()
            show_danmaku_func()
        end
    else
        show_message("Masquer les danmaku", 2)
        ENABLED = false
        hide_danmaku_func()
    end

    toggle_danmaku_switch(value)
end)

-- Enregistre les fonctions utilisées par les boutons uosc
mp.register_script_message("search-anime-event", function(query)
    perform_cancel_active_request()
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "close-menu", "menu_danmaku")
    end
    local name, class = query:match("^(.-)%s*|%s*(.-)%s*$")
    if name and class then
        query_extra(name, class)
        return
    end
    local filter_note = nil
    local search_name = query
    local at_pos = query:find("@[^@]*$")
    if at_pos then
        search_name = query:sub(1, at_pos-1):gsub("%s+$", "")
        filter_note = query:sub(at_pos+1):gsub("^%s*(.-)%s*$", "%1")
        if filter_note == "" then filter_note = nil end
    end
    get_animes(search_name, filter_note)
end)

mp.register_script_message("search-episodes-event", function(animeTitle, bangumiId, api_server)
    perform_cancel_active_request()
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "close-menu", "menu_anime")
    end

    get_episodes(animeTitle, bangumiId, api_server)
end)

mp.register_script_message("load-danmaku", function(animeTitle, episodeTitle, episodeId, api_server)
    ENABLED = true
    DANMAKU.anime = animeTitle
    DANMAKU.episode = episodeTitle
    set_episode_id(episodeId, true, api_server)
end)

mp.register_script_message("add-source-event", function(query)
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "close-menu", "menu_source")
    end
    ENABLED = true
    add_danmaku_source(query, true)
end)

mp.register_script_message("open_danmaku_style_menu", function()
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "close-menu", "menu_total")
    end
    open_style_menu()
end)

mp.register_script_message("open_content_danmaku_menu", function()
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "close-menu", "menu_total")
    end
    open_content_menu()
end)

mp.register_script_message("open-latest-menu-anime", function ()
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "open-menu", latest_menu_anime)
    elseif input_loaded then
        show_message("", 0)
        mp.add_timeout(0.1, function()
            open_menu_select(utils.parse_json(latest_menu_anime))
        end)
    end
end)

mp.register_script_message('cancel-active-request', function(menu_type)
    perform_cancel_active_request(menu_type)
end)

mp.register_script_message("setup-danmaku-style", function(query, text)
    local event = utils.parse_json(query)
    if event ~= nil then
        -- Clic sur un élément ou une icône
        if event.type == "activate" then
            if not event.action then
                if ordered_keys[event.index] == "bold" then
                    options.bold = not options.bold
                    menu_items_config.bold.hint = options.bold and "true" or "false"
                end
                -- Le mode « updata » conserve le texte du champ
                open_style_menu(ordered_keys[event.index], "updata")
                return
            else
                -- msg.info("event.action：" .. event.action)
                options[event.action] = menu_items_config[event.action]["original"]
                menu_items_config[event.action]["hint"] = options[event.action]
                open_style_menu(event.action, "updata")
                if event.action == "fontsize" or event.action == "scrolltime" then
                    load_danmaku(true)
                end
            end
        end
    else
        -- Saisie numérique
        if text == nil or text == "" then
            return
        end
        local newText, _ = text:gsub("%s", "") -- Supprime tous les espaces
        if tonumber(newText) ~= nil and menu_items_config[query]["scope"] ~= nil then
            local num = tonumber(newText)
            local min_num = menu_items_config[query]["scope"]["min"]
            local max_num = menu_items_config[query]["scope"]["max"]
            if num and min_num <= num and num <= max_num then
                if string.match(menu_items_config[query]["footnote"], "entier") then
                    -- Arrondit à l'entier inférieur lorsque la plage impose un entier
                    num = tostring(math.floor(num))
                end
                options[query] = tostring(num)
                menu_items_config[query]["hint"] = options[query]
                -- Le mode « refresh » efface le texte du champ
                open_style_menu(query, "refresh")
                if query == "fontsize" or query == "scrolltime" then
                    load_danmaku(true, true)
                end
                return
            end
        end
        open_style_menu(query, "error")
    end
end)

mp.register_script_message('setup-danmaku-source', function(json)
    local event = utils.parse_json(json)
    if event.type == 'activate' then

        if event.action == "delete" then
            DANMAKU.sources[event.value] = nil
            remove_source_from_history(event.value)
            mp.commandv("script-message-to", "uosc", "close-menu", "menu_source")
            open_add_menu()
            load_danmaku(true)
        end

        if event.action == "block" then
            DANMAKU.sources[event.value]["blocked"] = true
            add_source_to_history(event.value, DANMAKU.sources[event.value])
            mp.commandv("script-message-to", "uosc", "close-menu", "menu_source")
            open_add_menu()
            load_danmaku(true)
        end

        if event.action == "unblock" then
            DANMAKU.sources[event.value]["blocked"] = false
            add_source_to_history(event.value, DANMAKU.sources[event.value])
            mp.commandv("script-message-to", "uosc", "close-menu", "menu_source")
            open_add_menu()
            load_danmaku(true)
        end
    end
end)

mp.register_script_message("setup-source-delay", function(query, text)
    local event = utils.parse_json(query)
    if event ~= nil then
        -- Clic sur un élément
        if event.type == "activate" then
            open_delay_menu(event.value)
        end
    else
        -- Saisie numérique
        if text == nil or text == "" then
            return
        end
        local delay = parse_delay_input(text)
        if delay ~= nil then
            mp.commandv("script-message", "danmaku-delay", tostring(delay), "0", tostring(query))
            mp.commandv("script-message-to", "uosc", "close-menu", "menu_delay")
            mp.add_timeout(0.1, function()
                open_delay_menu(query, "refresh")
            end)
        else
            open_delay_menu(query, "error")
        end
    end
end)

mp.register_script_message('handle-danmaku-content-action', function(json)
    local event = utils.parse_json(json)
    if not event or event.type ~= 'activate' then return end

    if event.action then
        local d = COMMENTS[event.index]
        if not d or not d.source then return end

        if event.action == "block_source" then
            DANMAKU.sources[d.source]["blocked"] = true
            add_source_to_history(d.source, DANMAKU.sources[d.source])
            mp.commandv("script-message-to", "uosc", "close-menu", "menu_content")
            load_danmaku(true)
        elseif event.action == "adjust_delay" then
            -- Ouvre le menu de décalage à partir de ce danmaku ; le décalage s'applique ensuite uniquement à sa source
            mp.commandv("script-message", "open_content_delay_menu", d.source, tostring(d.start_time))
        end
    else
        if event.value then
            if type(event.value) == "table" then
                mp.commandv(unpack(event.value))
            else
                mp.command(event.value)
            end
            mp.commandv("script-message-to", "uosc", "close-menu", "menu_content")
        end
    end
end)

mp.register_script_message("open_content_delay_menu", function(source, time)
    open_delay_from_time(source, tonumber(time))
end)

mp.register_script_message("setup-content-delay", function(...)
    local args = {...}
    if #args == 1 then
        return
    end
    if #args >= 2 then
        local time = tonumber(args[1])
        local source = args[2]
        local delay_str = args[3]
        local delay = parse_delay_input(delay_str)
        if delay ~= nil then
            mp.commandv("script-message", "danmaku-delay", tostring(delay), tostring(time), tostring(source))
            mp.commandv("script-message-to", "uosc", "close-menu", "menu_delay_from_time")
        else
            open_delay_from_time(source, tonumber(time), "error")
        end
    end
end)
