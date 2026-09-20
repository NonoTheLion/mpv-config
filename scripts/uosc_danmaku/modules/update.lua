local msg = require('mp.msg')
local utils = require("mp.utils")

local repo = "Tony15246/uosc_danmaku"
local zip_file = utils.join_path(os.getenv("TEMP") or "/tmp/", "uosc_danmaku.zip")

local local_version = VERSION or "0.0.0"
local platform = mp.get_property("platform")

local function version_greater(v1, v2)
    local function parse(ver)
        local a, b, c = ver:match("v?(%d+)%.(%d+)%.(%d+)")
        return tonumber(a), tonumber(b), tonumber(c)
    end
    local a1, a2, a3 = parse(v1)
    local b1, b2, b3 = parse(v2)
    if a1 ~= b1 then return a1 > b1 end
    if a2 ~= b2 then return a2 > b2 end
    return a3 > b3
end

local function get_latest_release(repo)
    local url = "https://api.github.com/repos/" .. repo .. "/releases/latest"
    local cmd = { "curl", "-sL", url }
    local res = mp.command_native({
        name = "subprocess",
        args = cmd,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
    })
    if not res or res.status ~= 0 then return nil end
    local tag = res.stdout:match([["tag_name"%s*:%s*"([^"]+)"]])
    local zip_url = res.stdout:match([["browser_download_url"%s*:%s*"([^"]+%.zip)"]])
    return tag, zip_url
end

local function escape_ps(str)
    return tostring(str):gsub("'", "''")
end

local function unzip_overwrite(zip_file)
    local outpath = mp.get_script_directory()
    -- Définit le dossier temporaire utilisé pour une mise à jour sûre
    local tmpdir = utils.join_path(
        (platform == "windows" and (os.getenv("TEMP") or "C:\\Windows\\Temp") or "/tmp"),
        "uosc_update_" .. tostring(os.time())
    )
    
    local cmd_unzip = {}

    msg.info("Création du dossier temporaire et extraction : " .. tmpdir)

    if platform == "windows" then
        -- PowerShell : Expand-Archive crée automatiquement le dossier cible
        local ps_script = string.format(
            "Expand-Archive -LiteralPath '%s' -DestinationPath '%s' -Force",
            escape_ps(zip_file),
            escape_ps(tmpdir)
        )
        cmd_unzip = { "powershell", "-NoProfile", "-Command", ps_script }
    else
        -- Unix : unzip
        cmd_unzip = { "unzip", "-o", zip_file, "-d", tmpdir }
    end

    local res = mp.command_native({
        name = "subprocess",
        args = cmd_unzip,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
    })

    if not res or res.status ~= 0 then
        msg.error("❌ Échec de l'extraction :\n" .. (res and (res.stdout .. res.stderr) or "erreur inconnue"))
        -- Nettoie le dossier temporaire restant
        if platform == "windows" then
            mp.command_native({
                name = "subprocess",
                args = {"powershell", "-NoProfile", "-Command", "Remove-Item -LiteralPath '"..escape_ps(tmpdir).."' -Recurse -Force"}
            })
        else
            os.execute("rm -rf \"" .. tmpdir .. "\"")
        end
        return false
    end

    msg.info("Extraction réussie ; remplacement de l'ancien dossier…")

    local cmd_swap = {}
    
    if platform == "windows" then
        -- Windows : supprime et déplace dans une seule instance PowerShell
        local ps_swap = string.format(
            "Remove-Item -LiteralPath '%s' -Recurse -Force -ErrorAction SilentlyContinue; Move-Item -LiteralPath '%s' -Destination '%s' -Force",
            escape_ps(outpath),
            escape_ps(tmpdir),
            escape_ps(outpath)
        )
        cmd_swap = { "powershell", "-NoProfile", "-Command", ps_swap }
    else
        -- Unix : rm && mv
        cmd_swap = { "sh", "-c", string.format("rm -rf \"%s\" && mv \"%s\" \"%s\"", outpath, tmpdir, outpath) }
    end

    local res_swap = mp.command_native({
        name = "subprocess",
        args = cmd_swap,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
    })

    if not res_swap or res_swap.status ~= 0 then
        msg.error("❌ Échec du remplacement du dossier :\n" .. (res_swap and (res_swap.stdout .. res_swap.stderr) or ""))
        return false
    end

    msg.info("Mise à jour terminée")
    return true
end

function check_for_update()
    local latest_version, download_url = get_latest_release(repo)
    if not latest_version or not download_url then
        show_message("❌ Impossible d'obtenir les informations sur la dernière version")
        msg.warn("❌ Impossible d'obtenir les informations sur la dernière version")
        return
    end

    if not version_greater(latest_version, local_version) then
        show_message("✅ La version installée est à jour ("..local_version..")")
        msg.info("✅ La version installée est à jour")
        return
    end

    show_message("⬇️ Nouvelle version disponible : " .. latest_version .. ", téléchargement…")
    msg.info("⬇️ Nouvelle version disponible : " .. latest_version .. ", adresse : " .. download_url)

    local cmd = { "curl", "-L", "-o", zip_file, download_url }
    local res = mp.command_native({
        name = "subprocess",
        args = cmd,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
    })
    if not res or res.status ~= 0 then
        show_message("❌ Échec du téléchargement !")
        msg.warn("❌ Échec du téléchargement !")
        return
    end

    show_message("📦 Téléchargement terminé ; extraction et remplacement…")
    msg.info("📦 Téléchargement terminé ; extraction et remplacement…")

    if unzip_overwrite(zip_file) then
        os.remove(zip_file)
        show_message("✅ Mise à jour réussie ! Redémarrez mpv pour l'appliquer. Version actuelle : " .. latest_version)
        msg.info("✅ Mise à jour réussie. Version actuelle : " .. latest_version)
    else
        os.remove(zip_file)
        show_message("❌ Échec de l'extraction ! Consultez le journal de la console")
        msg.warn("❌ Échec de l'extraction !")
    end
end
