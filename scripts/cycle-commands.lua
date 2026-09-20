--[[
    script permettant de faire défiler des commandes avec un raccourci clavier, au moyen de script-messages
    disponible sur : https://github.com/CogentRedTester/mpv-scripts

    syntaxe :
        script-message cycle-commands "commande1 args" "commande2 args" "commande3 args"

    La syntaxe de chaque commande est identique à celle d'input.conf, mais chaque commande doit être
    une chaîne entre guillemets. Cela peut donc obliger à imbriquer (et éventuellement échapper) les guillemets des arguments.
    Voir la documentation de mpv pour la marche à suivre : https://mpv.io/manual/master/#flat-command-syntax.

    Les points-virgules fonctionnent aussi comme d'habitude, on peut donc facilement envoyer plusieurs commandes par cycle.

    Voici quelques exemples d'une même commande avec différents types de guillemets :
        script-message cycle-commands "show-text one 1000 ; print-text two" "show-text \"three four\""
        script-message cycle-commands 'show-text one 1000 ; print-text two' 'show-text "three four"'
        script-message cycle-commands ``show-text one 1000 ; print-text two`` ``show-text "three four"``

    Au premier appui sur la touche, cela affiche « one » sur l'OSD pendant 1 seconde et « two » dans la console,
    et au deuxième appui « three four » est affiché sur l'OSD.
    À noter que les guillemets simples (') et les accents graves (`) n'ont été ajoutés que dans mpv v0.34.

    Le nombre de commandes n'est pas limité, et le script-message peut être utilisé autant de fois que souhaité.
    Le script mémorise la position d'itération courante pour chaque ensemble unique de chaînes de commandes,
    il ne devrait donc pas y avoir de chevauchement, sauf si l'on associe exactement le même ensemble de chaînes (espaces compris).

    Si la première commande est `!reverse`, les commandes défilent dans le sens inverse.
    Si toutes les chaînes de commandes suivantes sont identiques à celles d'un cycle non inversé, elles partagent
    la même position d'itération, ce qui permet de se déplacer en avant ou en arrière dans le cycle :
        script-message cycle-commands 'apply-profile profile1' 'apply-profile profile2' 'apply-profile profile3'
        script-message cycle-commands !reverse 'apply-profile profile1' 'apply-profile profile2' 'apply-profile profile3'

    La plupart des commandes affichent automatiquement des messages sur l'OSD ; ce comportement se règle
    en ajoutant des préfixes d'entrée aux commandes : https://mpv.io/manual/master/#input-command-prefixes.
    Certaines commandes n'afficheront pas de message OSD même si on le leur demande ; dans ce cas, deux options :
    ajouter une commande show-text au cycle, ou utiliser le script-message cycle-commands/osd
    qui affichera la chaîne de commande sur l'OSD. Par exemple :
        script-message cycle-commands 'apply-profile profile1;show-text "applying profile1"' 'apply-profile profile2;show-text "applying profile2"'
        script-message cycle-commands/osd 'apply-profile profile1' 'apply-profile profile2'

    Tout message OSD affiché par la commande elle-même remplacera celui envoyé par cycle-commands/osd.
]]--

local mp = require 'mp'
local msg = require 'mp.msg'

--mémorise la position courante d'un cycle donné
local iterators = {}

--fonction principale : identifie et exécute les cycles
local function main(osd, ...)
    local commands = {...}

    local reverse = commands[1] == '!reverse'
    if reverse then table.remove(commands, 1) end

    --pour identifier le cycle, on concatène toutes les chaînes afin d'en faire la clef de notre table
    local str = ("%d> %s"):format(#commands, table.concat(commands, '|'))
    msg.trace('recieved:', str)

    -- on initialise l'itérateur à 0 (position invalide) pour permettre l'itération avant ou arrière
    if iterators[str] == nil then
        msg.debug('unknown cycle, creating iterator')
        iterators[str] = 0
    end

    iterators[str] = iterators[str] + (reverse and -1 or 1)
    if iterators[str] > #commands then iterators[str] = 1 end
    if iterators[str] < 1 then iterators[str] = #commands end

    --mp.command exécute les commandes exactement comme si elles étaient saisies dans input.conf.
    --Cela assure la prise en charge complète de la syntaxe de commande d'input.conf
    local cmd = commands[ iterators[str] ]
    msg.verbose('sending command:', cmd)
    if osd then mp.osd_message(cmd) end
    mp.command(cmd)
end

mp.register_script_message('cycle-commands', function(...) main(false, ...) end)
mp.register_script_message('cycle-commands/osd', function(...) main(true, ...) end)