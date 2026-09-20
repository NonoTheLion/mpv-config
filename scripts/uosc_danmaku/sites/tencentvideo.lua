local msg = require('mp.msg')
local utils = require('mp.utils')

local user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

-- Décode les séquences pourcentées d'une URL
local function normalize_url(path)
    if not path then return '' end
    return (path:gsub('%%(%x%x)', hex_to_char))
end

-- Extrait vid de l'URL
local function extract_vid(url)
    if not url then return nil end
    local vid = url:match('[?&]vid=([^&?#]+)')
    if not vid then
        local last = nil
        for seg in url:gmatch('/([^/?#]+)') do
            last = seg
        end
        if last then
            vid = last:match('([^%.]+)')
        end
    end
    return vid
end

-- Construit les paramètres curl communs
local function build_curl_args(target_url)
    local args = {
        'curl',
        '-L',
        '-s',
        '--compressed',
        '--user-agent',
        user_agent,
        target_url,
    }

    if options.cookie_file and options.cookie_file ~= '' then
        table.insert(args, '-b')
        table.insert(args, mp.command_native({'expand-path', options.cookie_file}))
    end
    return args
end

-- Analyse un segment et ajoute ses danmaku à output_table
local function parse_segment_to_output(seg_json, output_table)
    if not seg_json or not seg_json['barrage_list'] then return end
    for _, item in ipairs(seg_json['barrage_list']) do
        local time = tonumber(item['time_offset']) and tonumber(item['time_offset']) / 1000 or 0
        local color = 16777215
        if item['content_style'] and item['content_style']['color'] then
            local col = item['content_style']['color']
            if type(col) == 'string' and col:match('^#') then
                color = hex_to_int_color(col)
            end
        end
        local mode = 1
        local c_param = string.format('%s,%s,%s,25,,,', time, color, mode)
        table.insert(output_table, {c = c_param, m = item['content'] or ''})
    end
end

-- Enregistre et charge le JSON final des danmaku
local function save_output_and_load(output_table, source_url)
    if #output_table == 0 then
        show_message('Aucun danmaku récupéré', 3)
        return
    end
    local final_json_str = utils.format_json(output_table)
    save_danmaku_json(source_url, final_json_str)
    load_danmaku(true)
end

-- Charge les danmaku Tencent Video
function load_danmaku_for_tencent(path, callback)
    callback = callback or function() end
    local url = normalize_url(path)
    if not url or url == '' then
        url = mp.get_property('stream-open-filename', '')
    end

    local vid = extract_vid(url)
    if not vid then
        msg.error("Impossible d'extraire vid de l'URL : " .. tostring(url))
        callback(false)
        return
    end

    local api_base = 'https://dm.video.qq.com/barrage/base/' .. vid
    local api_segment_base = 'https://dm.video.qq.com/barrage/segment/' .. vid .. '/'

    local base_args = build_curl_args(api_base)

    call_cmd_async(base_args, function(err, out)
        if err then
            msg.error('Échec de la requête de base des danmaku Tencent : ' .. tostring(err))
            callback(false)
            return
        end

        local base_json = utils.parse_json(out)
        if not base_json or not base_json['segment_index'] then
            show_message('Aucun danmaku ne semble disponible', 3)
            callback(false)
            return
        end

        -- Construit la liste des requêtes de segments
        local segments = {}
        local seg_index = base_json['segment_index']
        if type(seg_index) == 'table' then
            for k, v in pairs(seg_index) do
                local seg_name = nil
                if type(v) == 'table' and v['segment_name'] then
                    seg_name = v['segment_name']
                elseif type(k) == 'string' then
                    seg_name = k
                end
                if seg_name then
                    table.insert(segments, api_segment_base .. seg_name)
                end
            end
        end

        if #segments == 0 then
            show_message('Aucun segment de danmaku trouvé', 3)
            callback(false)
            return
        end

        local output_table = {}

        local function build_args_fn(server)
            return build_curl_args(server)
        end

        local function per_response_cb(server, err, out)
            if err then
                msg.warn('Échec de la requête du segment : ' .. tostring(server) .. ' erreur : ' .. tostring(err))
                return
            end
            local seg_json = utils.parse_json(out)
            parse_segment_to_output(seg_json, output_table)
        end

        local function final_cb()
            local ok = #output_table > 0
            save_output_and_load(output_table, url)
            callback(ok)
        end

        -- Interroge les segments en parallèle
        parallel_requests(segments, build_args_fn, per_response_cb, final_cb, {concurrency = 6, per_request_timeout = 15})
    end)
end
