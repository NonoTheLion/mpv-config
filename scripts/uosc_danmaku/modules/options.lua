local opt = require("mp.options")

-- Options
options = {
    -- Définit l'adresse du serveur de danmaku ; un service personnalisé doit être compatible avec l'API dandanplay
    -- Accepte une liste ordonnée de api_server séparés par des virgules
    -- Chaque entrée peut porter une note séparée par « | » ou « # »
    api_server = "https://danmaku-api.152468.xyz",
    -- Définit le serveur de secours pour Bilibili, iQIYI, Tencent et Youku, principalement pour les contenus non animés
    -- Disponible : https://dmku.hls.one
    fallback_server = "https://dmku.hls.one",
    -- Définit la clé API TMDB pour obtenir les informations chinoises des contenus non animés lorsque la recherche n'est pas en chinois
    -- Disponible dans les paramètres du compte après inscription sur https://www.themoviedb.org
    -- Attention : une clé personnalisée doit être encodée en base64
    tmdb_api_key = "NmJmYjIxOTZkNzIyN2UyMTIzMGM3Y2YzZjQ4MDNkZGM=",
    -- Active le chargement automatique des danmaku
    auto_load = false,
    -- Mémorise et réutilise les associations de danmaku pour les URL vidéo compatibles ; fonctionne au mieux avec les listes de lecture
    autoload_for_url = false,
    -- Ouvre automatiquement la recherche manuelle si le chargement automatique échoue
    auto_fallback_search = false,
    -- Charge automatiquement le fichier XML de même nom situé avec la vidéo
    autoload_local_danmaku = false,
    -- Enregistre automatiquement les danmaku en XML à la fin de la lecture
    save_danmaku = false,
    -- Définit le dossier d'enregistrement ; vide, utilise le dossier de la vidéo. Le dossier doit déjà exister
    save_danmaku_path = "",
    -- Définit la portée de save_danmaku_path : local / url / all
    save_danmaku_path_mode = "local",
    -- User-Agent des requêtes HTTP
    user_agent = "mpv_danmaku/1.0",
    -- Mandataire facultatif pour les requêtes HTTP, désactivé par défaut
    proxy = "",
    -- Chemin facultatif du fichier cookie.txt transmis aux requêtes HTTP
    cookie_file = "",
    -- Utilise le filtre vidéo fps pour fluidifier les danmaku ; désactivé par défaut
    vf_fps = false,
    -- Définit le paramètre du filtre fps
    fps = "60/1.001",
    -- Tolérance temporelle en secondes pour fusionner les doublons ; -1 désactive la fusion
    merge_tolerance = -1,
    -- Indique si les doublons de types ou couleurs différents doivent être fusionnés ; false limite la fusion aux styles identiques
    merge_without_style = false,
    -- Coefficient logarithmique d'agrandissement des danmaku fusionnés ; entier positif
    merge_fontsize_growth = 8,
    -- Taille maximale des danmaku fusionnés
    merge_fontsize_max = 100,
    -- Chemin absolu ou relatif du fichier d'historique des associations
    history_path = "~~/danmaku-history.json",
    -- Raccourcis personnalisés ; input-default-bindings=no dans mpv.conf désactive les deux options suivantes
    open_search_danmaku_menu_key = "Ctrl+d",
    show_danmaku_keyboard_key = "j",
    -- Conversion chinois traditionnel/simplifié : 0 aucune, 1 simplifié, 2 traditionnel
    chConvert = 0,
    -- Durée d'affichage des danmaku défilants
    scrolltime = 15,
    -- Durée d'affichage des danmaku fixes
    fixtime = 5,
    -- Police
    fontname = "sans-serif",
    -- Taille de police
    fontsize = 50,
    -- Ombre de la police
    shadow = 0,
    -- Police en gras
    bold = true,
    -- Opacité : 0 (transparent) à 1 (opaque)
    opacity = 0.7,
    -- Zone d’affichage de tous les danmaku (0,0–1,0)
    displayarea = 0.85,
    -- Contour de 0 à 4
    outline = 1.0,
    -- Nombre maximal de danmaku simultanés ; 0 signifie illimité
    max_screen_danmaku = 0,
    -- Chemin absolu ou relatif du fichier de mots bloqués (black.txt), une entrée par ligne
    -- Accepte les motifs Lua
    blacklist_path = "",
    -- Alignement des messages du script
    message_anlignment = 7,
    -- Coordonnée x des messages du script
    message_x = 30,
    -- Coordonnée y des messages du script
    message_y = 30,
    -- Règles supplémentaires de remplacement des titres, au format JSON, utilisant les motifs de string.gsub de Lua
    --! Attention : la version Lua de mpv n'accepte ici que les captures de forme %n, comme dans l'exemple
    title_replace = [[
       [{ 
           "rules": [{ "^〔(.-)〕": "%1"},{ "^.*《(.-)》": "%1" }],
       }]
    ]],
    -- Chemins absolus ou relatifs de volumes partagés à exclure de la correspondance par hachage, séparés par des virgules
    -- Exemple : ["X:", "Z:", "F:/Download/", "Download"]
    excluded_path = [[
        []
    ]],
}

opt.read_options(options, mp.get_script_name(), function() end)
