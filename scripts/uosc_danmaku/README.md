# uosc_danmaku

Charge les danmaku de DanDanPlay dans le lecteur MPV. Il s’agit d’une extension mpv pour les danmaku, basée sur l’interface uosc et l’API de DanDanPlay.

> [!WARNING]
> Dans la version 1.2.0 et les versions antérieures, certaines fonctions sont indisponibles en raison d’une modification de la politique d’utilisation de l’API DanDanPlay. Si l’extension ne fonctionne pas correctement, par exemple si la recherche de danmaku ne renvoie jamais de résultat, récupérez ou téléchargez le code source le plus récent de la branche principale, ou téléchargez la [dernière version publiée](https://github.com/Tony15246/uosc_danmaku/releases/latest).

> [!NOTE]
> Par défaut, l’extension accède au réseau public de danmaku de DanDanPlay via le proxy d’API maintenu par le projet, `https://danmaku-api.152468.xyz`. Les utilisateurs ordinaires n’ont pas besoin de créer un compte, ni de configurer ou de posséder un AppId/AppSecret DanDanPlay. Le proxy comporte une mise en cache et une limitation de la fréquence d’accès ; ne l’utilisez pas pour des téléchargements en masse.

> [!NOTE]
> La prise en charge de l’interface interne `mp.input` de mpv a été ajoutée. Lorsque uosc n’est pas disponible, les menus peuvent être affichés de cette manière au moyen de raccourcis clavier.
> 
> Pour activer cette prise en charge, mpv 0.39.0 ou une version ultérieure est requis.

## Présentation du projet

Consultez la vidéo de démonstration pour voir l’extension en action :

<video width="902" src="https://github.com/user-attachments/assets/86717e75-9176-4f1a-88cd-71fa94da0c0e">
</video>

Lorsque l’interface uosc n’est pas installée, les menus sont affichés via l’interface interne `mp.input` de mpv. Consultez [cette PR](https://github.com/Tony15246/uosc_danmaku/pull/24) pour voir le résultat.

### Fonctionnalités principales

<details open>

1. Récupère les séries et les danmaku depuis l’API de DanDanPlay ou d’un service personnalisé, puis charge les danmaku de l’épisode sélectionné par l’utilisateur.

2. Un clic sur le bouton de recherche de danmaku dans la barre de commandes de uosc affiche un menu permettant de choisir les danmaku souhaités.

3. Un clic sur l’interrupteur des danmaku ajouté à la barre de commandes de uosc permet d’activer ou de désactiver leur affichage.

4. Un clic sur le bouton [Obtenir des danmaku depuis une source](#ajouter-de-nouveaux-danmaku-depuis-une-source-facultatif), ajouté à la barre de commandes de uosc, permet d’ajouter des danmaku depuis une source en ligne prise en charge ou un fichier local.

5. Un clic sur le bouton [Style des danmaku](#modifier-le-style-des-danmaku-en-temps-réel-facultatif), ajouté à la barre de commandes de uosc, ouvre le menu de style des danmaku de uosc afin de modifier leur apparence en temps réel pendant la lecture (attention ⚠️ : cette fonction est indisponible si l’interface uosc n’est pas installée).

6. Un clic sur le bouton [Menu général des réglages des danmaku](#menu-général-des-réglages-des-danmaku-facultatif), ajouté à la barre de commandes de uosc, ouvre un menu composite à plusieurs niveaux qui regroupe toutes les fonctions graphiques actuellement proposées par l’extension.

7. Un clic sur le bouton [Réglage du décalage des sources de danmaku](#réglage-du-décalage-des-sources-de-danmaku-facultatif), ajouté à la barre de commandes de uosc, ouvre le menu de réglage du décalage des sources et permet de régler séparément le décalage de chaque source de danmaku (attention ⚠️ : cette fonction est indisponible si l’interface uosc n’est pas installée).

8. Chargement automatique des danmaku avec mémorisation : après avoir chargé une fois les danmaku d’un épisode situé dans un dossier, ces danmaku sont automatiquement associés à cet épisode. Ils seront ensuite chargés automatiquement chaque fois que le fichier sera relu. Tous les fichiers des autres épisodes présents dans le même dossier chargeront eux aussi automatiquement leurs danmaku lors de la lecture, sans qu’il soit nécessaire de saisir à nouveau le nom de la série pour effectuer une recherche (attention ⚠️ : le chargement entièrement automatique des danmaku est désactivé par défaut ; pour l’activer, consultez la [description de l’option auto_load](#auto_load)).

9. Avant tout chargement manuel de danmaku et avant la création d’une association mémorisée pour le chargement automatique, les danmaku sont ajoutés automatiquement par comparaison du hachage du fichier (~fichiers locaux uniquement~, les vidéos en ligne sont désormais prises en charge). Les fichiers pouvant être associés grâce à leur hachage ne nécessitent plus de recherche manuelle : les danmaku sont chargés automatiquement et l’association est mémorisée. Cette fonction est activée en même temps que le chargement automatique avec mémorisation (la précision de l’association automatique par hachage est faible ; si le mauvais épisode est associé, chargez manuellement le bon épisode).
   
   > La comparaison par hachage exige une version de mpv compilée avec LuaJIT ou Lua 5.2 ; Lua 5.1 n’est pas pris en charge.

10. Mémorise automatiquement l’état d’activation des danmaku afin de conserver, à la lecture d’une vidéo, l’état dans lequel ils se trouvaient lors de la dernière fermeture.

11. Permet de personnaliser le style d’affichage par défaut des danmaku (pour la procédure détaillée, consultez [Configuration du style personnalisé des danmaku](#configuration-du-style-personnalisé-des-danmaku)).

12. Charge automatiquement les danmaku lors de la lecture de vidéos en ligne avec des outils tels que [Play-With-MPV](https://github.com/LuckyPuppy514/Play-With-MPV) ou [ff2mpv](https://github.com/woodruffw/ff2mpv) (attention ⚠️ : le chargement automatique prend actuellement en charge Bilibili et Bahamut Anime ; pour plus de détails, consultez la [description de l’option autoload_for_url](#autoload_for_url)).

13. Enregistre localement les danmaku actuels (pour une description détaillée, consultez la [description de l’option save_danmaku](#save_danmaku)).

14. Peut fusionner un grand nombre de danmaku identiques apparaissant simultanément pendant une période donnée (pour la procédure détaillée, consultez la [description de l’option merge_tolerance](#merge_tolerance)).

15. Convertit les danmaku entre caractères chinois simplifiés et traditionnels afin d’éviter leur mélange (pour la procédure détaillée, consultez la [description de l’option chConvert](#chConvert)).

16. Permet de personnaliser la position d’affichage des messages de l’extension en réglant librement leur distance horizontale et verticale par rapport au coin supérieur gauche de l’image (pour la procédure détaillée, consultez les descriptions des options [message_x](#message_x) et [message_y](#message_y)).

Plus besoin de télécharger et de regrouper vous-même des fichiers de danmaku, ni d’en convertir le format : dans le lecteur mpv, un seul clic suffit pour charger les danmaku d’anime fournis par DanDanPlay et provenant notamment de Bilibili ou de Bahamut Anime.

L’extension prend en charge Linux et Windows. Le projet dépend de l’[interface uosc](https://github.com/tomasklaen/uosc). Il est vivement recommandé d’installer uosc dans le lecteur mpv pour utiliser cette extension. Pour installer uosc, consultez son [guide d’installation officiel](https://github.com/tomasklaen/uosc?tab=readme-ov-file#install). Si vous utilisez un pack prêt à l’emploi intégrant déjà uosc, tel que [MPV_lazy](https://github.com/hooke007/MPV_lazy), il suffit bien sûr d’installer cette extension.

</details>

## Sommaire

- [Présentation du projet](#présentation-du-projet)
  - [Fonctionnalités principales](#fonctionnalités-principales)
- [Installation](#installation)
  - [Téléchargement](#téléchargement)
- [Configuration de base](#configuration-de-base)
  - [Configuration des commandes de uosc](#configuration-des-commandes-de-uosc)
  - [Associer des raccourcis clavier (facultatif)](#associer-des-raccourcis-clavier-facultatif)
- [Fonctions avancées (facultatif)](#fonctions-avancées-facultatif)
  - [Ajouter de nouveaux danmaku depuis une source (en ligne ou locale)](#ajouter-de-nouveaux-danmaku-depuis-une-source-facultatif)
  - [Réglage du décalage des sources de danmaku](#réglage-du-décalage-des-sources-de-danmaku-facultatif)
  - [Modifier le style des danmaku en temps réel](#modifier-le-style-des-danmaku-en-temps-réel-facultatif)
  - [Menu général des réglages des danmaku](#menu-général-des-réglages-des-danmaku-facultatif)
  - [Régler le décalage des danmaku (facultatif)](#régler-le-décalage-des-danmaku-facultatif)
  - [Enregistrer les danmaku de la vidéo actuelle (facultatif)](#enregistrer-les-danmaku-de-la-vidéo-actuelle-facultatif)
  - [Effacer les sources de danmaku associées à la vidéo actuelle (facultatif)](#effacer-les-sources-de-danmaku-associées-à-la-vidéo-actuelle-facultatif)
  - [Rechercher les mises à jour du script (facultatif)](#rechercher-les-mises-à-jour-du-script-facultatif)
- [Options configurables (facultatif)](#options-configurables-facultatif)
  - [Chargement des danmaku](#chargement-des-danmaku)
  - [Affichage des danmaku](#affichage-des-danmaku)
  - [Service d’analyse des danmaku](#service-danalyse-des-danmaku)
  - [Configuration de l’extension](#configuration-de-lextension)
  - [Configuration du style personnalisé des danmaku](#configuration-du-style-personnalisé-des-danmaku)
- [Propriétés personnalisées de l’extension](#propriétés-personnalisées-de-lextension)
- [Questions fréquentes](#questions-fréquentes)
- [Remerciements particuliers](#remerciements-particuliers)
- [Projets associés](#projets-associés)

## Installation

### Téléchargement

La structure d’un répertoire de configuration mpv classique ressemble généralement à ceci :

> [!NOTE]
> Sous Windows, le chemin de configuration global équivalent est `%APPDATA%/mpv/`. Vous pouvez également utiliser le dossier portable_config situé dans le répertoire de mpv.exe (configuration portable).

```
~/.config/mpv
├── fonts
├── input.conf
├── mplayer-input.conf
├── mpv.conf
├── script-opts
└── scripts
```

Pour utiliser cette extension, [téléchargez-la](https://github.com/Tony15246/uosc_danmaku/releases) entièrement ou clonez-la simplement dans le répertoire `scripts`. Consultez ci-dessous la structure des fichiers.

> [!IMPORTANT]
> 
> 1. Dans le répertoire scripts, le dossier contenant cette extension doit être nommé uosc_danmaku. Dans le cas contraire, vous devez [modifier les commandes de uosc](#modifier-les-commandes-de-uosc-facultatif) comme indiqué dans la section consacrée à leur configuration.
> 2. N’oubliez pas d’accorder les droits d’exécution aux fichiers du dossier bin.

<details>
<summary>Structure des fichiers</summary>

```
~/.config/mpv/scripts
└── uosc_danmaku
    ├── apis
    │   ├── dandanplay.lua
    │   └── extra.lua
    ├── LICENSE
    ├── main.lua
    ├── modules
    │   ├── base64.lua
    │   ├── guess.lua
    │   ├── md5.lua
    │   ├── menu.lua
    │   ├── options.lua
    │   ├── render.lua
    │   └── utils.lua
    └── README.md
```

</details>

## Configuration de base

#### Configuration des commandes de uosc

Cette étape est essentielle. Si vous n’ajoutez pas ces commandes, le bouton de recherche et l’interrupteur des danmaku ne s’afficheront pas dans la barre de commandes située au-dessus de la barre de progression. Sans ces commandes, la recherche et l’activation des danmaku ne seront accessibles que par des [raccourcis clavier](#associer-des-raccourcis-clavier-facultatif).

Pour ajouter des commandes uosc, modifiez le fichier `uosc.conf` du répertoire `script-opts` situé dans le dossier de configuration de mpv. Si uosc est déjà installé, mais que le dossier `script-opts` ne contient aucun fichier `uosc.conf`, téléchargez le fichier `uosc.conf` officiel depuis le [dépôt du projet uosc](https://github.com/tomasklaen/uosc), puis suivez les étapes de configuration ci-dessous.

Comme certaines interfaces et le code des commandes de uosc n’ont été mis à jour que récemment, la configuration diffère entre les anciennes et les nouvelles versions. Si vous avez téléchargé la dernière version Git de uosc ou si vous la maintenez à jour, suivez la `procédure de configuration des commandes de la dernière version de uosc`. Si vous ignorez votre version de uosc, ou si elle est gérée par un tiers, par exemple dans [MPV_lazy](https://github.com/hooke007/MPV_lazy), suivez la `procédure de configuration des commandes des anciennes versions de uosc`, compatible avec les versions récentes comme anciennes.

<details>
<summary>Procédure de configuration des commandes de la dernière version de uosc</summary>

Repérez l’option `controls` dans le fichier `uosc.conf`. La configuration officielle par défaut de uosc peut ressembler à ceci :

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

Dans l’option `controls`, ajoutez le bouton de recherche des danmaku `button:danmaku` et l’interrupteur `cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?Danmaku`. Leur position dans la liste détermine leur emplacement réel dans la barre de commandes située au-dessus de la barre de progression ; placez-les où vous le souhaitez. Personnellement, je les ai placés après la commande de sélection de la qualité vidéo `<stream>stream-quality`. Après leur ajout, la configuration devrait ressembler à ceci :

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,button:danmaku,cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?Danmaku,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

</details>

<details>
<summary>Procédure de configuration des commandes des anciennes versions de uosc</summary>

Repérez l’option `controls` dans le fichier `uosc.conf`. La configuration officielle par défaut de uosc peut ressembler à ceci :

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

Dans l’option `controls`, ajoutez le bouton de recherche des danmaku `command:search:script-message open_search_danmaku_menu?Rechercher des danmaku` et l’interrupteur `cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?Danmaku`. Leur position dans la liste détermine leur emplacement réel dans la barre de commandes située au-dessus de la barre de progression ; placez-les où vous le souhaitez. Personnellement, je les ai placés après la commande de sélection de la qualité vidéo `<stream>stream-quality`. Après leur ajout, la configuration devrait ressembler à ceci :

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,command:search:script-message open_search_danmaku_menu?Rechercher des danmaku,cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?Danmaku,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

</details>

<details>
<summary>Modifier les commandes de uosc (facultatif)</summary>

Si, pour éviter un conflit de noms ou pour toute autre raison, vous ne pouvez pas nommer `uosc_danmaku` le dossier contenant cette extension, remplacez `uosc_danmaku` dans la configuration de l’interrupteur `cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?Danmaku` par le nom du dossier contenant l’extension. Par exemple, si vous l’avez placée dans un dossier nommé `my_folder`, utilisez `cycle:toggle_on:show_danmaku@my_folder:on=toggle_on/off=toggle_off?Danmaku` pour l’interrupteur des danmaku.

</details>

#### Associer des raccourcis clavier (facultatif)

Les adeptes convaincus du clavier et les utilisateurs qui préfèrent se passer de la souris peuvent lancer la recherche et activer ou désactiver les danmaku à l’aide de raccourcis clavier.

Des raccourcis sont déjà définis par défaut. La recherche de danmaku est associée à « Ctrl+d » et l’activation des danmaku à « j ».

Le message de script associé à la recherche de danmaku est `open_search_danmaku_menu`, tandis que celui associé à l’activation des danmaku est `show_danmaku_keyboard`.

Pour configurer ces raccourcis, ajoutez simplement les lignes suivantes à `input.conf`. Vous pouvez remplacer les touches par les combinaisons de votre choix.

```
Ctrl+d script-message open_search_danmaku_menu
j script-message show_danmaku_keyboard
```

> À la suite d’une demande formulée dans [cette issue](https://github.com/Tony15246/uosc_danmaku/issues/6), il est désormais possible d’associer les raccourcis dans uosc_danmaku.conf. (Notez que les raccourcis définis dans input.conf restent prioritaires.)
> Pour personnaliser les raccourcis dans uosc_danmaku.conf, modifiez les valeurs par défaut comme ci-dessous.

```
open_search_danmaku_menu_key=Ctrl+i
show_danmaku_keyboard_key=i
```

## Fonctions avancées (facultatif)

Cette extension propose un ensemble complet de fonctions avancées consacrées aux danmaku.

---

**Fonctions accessibles par des commandes**

<details>
<summary>Ajouter de nouveaux danmaku à la liste actuelle depuis une source (en ligne ou locale)</summary>

> #### Ajouter de nouveaux danmaku depuis une source (facultatif)

Ajoute des danmaku depuis une source. Si des danmaku sont déjà en cours de lecture, les nouveaux seront ajoutés à la liste existante.

Parmi les sources acceptées figurent, par exemple, n’importe quelle vidéo Bilibili indiquée par une URL `/video/` suivie de son identifiant BV, ou encore une adresse de vidéo Bahamut Anime. Les adresses suivantes constituent toutes deux des sources de danmaku valides :

```
https://www.bilibili.com/video/BV1kx411o7Yo
https://ani.gamer.com.tw/animeVideo.php?sn=36843
```

Cette fonction appelle l’interface extcomment de DanDanPlay pour récupérer les danmaku correspondant à une URL donnée sur un site tiers (comme les sites A/B/C). Pour l’activer, reportez-vous à la [configuration des commandes de uosc](#configuration-des-commandes-de-uosc) et ajoutez `button:danmaku_source` ou `command:add_box:script-message open_add_source_menu?Ajouter des danmaku depuis une source` à l’option controls de `uosc.conf`, selon votre version de uosc.

Pour utiliser cette fonction au moyen d’un raccourci clavier, ajoutez une configuration semblable à celle ci-dessous dans `input.conf`. Le message de script correspondant à l’ajout de danmaku depuis une source est `open_add_source_menu`.

```
key script-message open_add_source_menu
```

Le chargement de fichiers de danmaku locaux est désormais pris en charge. Saisissez le chemin absolu d’un fichier local pour charger ses danmaku avec cette extension. Leur style sera celui défini dans l’extension. Les formats pris en charge sont les fichiers ASS et XML. Pour plus de détails, consultez [cette issue](https://github.com/Tony15246/uosc_danmaku/issues/26).

```
# Exemple sous Linux
/home/tony/Downloads/example.xml
# Exemple sous Windows
C:\Users\Tony\Downloads\example.xml
```

Ce menu a également été amélioré. Il permet désormais de gérer visuellement toutes les sources de danmaku et de supprimer ou de bloquer celles dont vous ne voulez pas. Les sources que vous avez ajoutées manuellement peuvent être supprimées. Celles provenant de DanDanPlay ne peuvent pas l’être, mais vous pouvez les bloquer afin de ne plus en récupérer les danmaku, puis les débloquer si nécessaire. Notez enfin que toute modification visuelle des sources effectuée dans ce menu ne prendra effet qu’à la prochaine ouverture de la vidéo ou après un nouveau chargement des danmaku au moyen de la fonction de recherche.

</details>

<details>
<summary>Réglage du décalage des sources de danmaku</summary>

> #### Réglage du décalage des sources de danmaku (facultatif)

Vous pouvez régler séparément le décalage de chaque source de danmaku. Deux modes de saisie sont possibles : saisir un nombre en secondes, avec une précision maximale de deux décimales, ou saisir une chaîne au format `14m15s`, qui représente le décalage en minutes et en secondes.

Pour activer cette fonction, reportez-vous à la [configuration des commandes de uosc](#configuration-des-commandes-de-uosc) et ajoutez `button:danmaku_delay` ou `command:more_time:script-message open_source_delay_menu?Décalage des sources de danmaku` à l’option controls de `uosc.conf`, selon votre version de uosc.

Pour utiliser cette fonction au moyen d’un raccourci clavier, ajoutez une configuration semblable à celle ci-dessous dans `input.conf`. Le message de script correspondant au réglage du décalage des sources de danmaku est `open_source_delay_menu`.

```
key script-message open_source_delay_menu
```

</details>

<details>
<summary> Modifier le style des danmaku en temps réel</summary>

> #### Modifier le style des danmaku en temps réel (facultatif)

Cette fonction s’appuie sur l’[interface uosc](https://github.com/tomasklaen/uosc) pour permettre la **modification en temps réel du style des danmaku**. Elle ouvre un menu graphique dans lequel l’utilisateur peut modifier manuellement leur style (la [configuration du style personnalisé des danmaku](#configuration-du-style-personnalisé-des-danmaku) est utilisée par défaut). Pour l’activer, reportez-vous à la [configuration des commandes de uosc](#configuration-des-commandes-de-uosc) et ajoutez `button:danmaku_styles` ou `command:palette:script-message open_danmaku_style_menu?Style des danmaku` à l’option controls de `uosc.conf`, selon votre version de uosc.

Pour utiliser cette fonction au moyen d’un raccourci clavier, ajoutez une configuration semblable à celle ci-dessous dans `input.conf`. Le message de script correspondant à la modification en temps réel du style des danmaku est `open_danmaku_style_menu`.

```
key script-message open_danmaku_style_menu
```

</details>

<details>
<summary> Menu général des réglages des danmaku</summary>

> #### Menu général des réglages des danmaku (facultatif)

Ouvre un menu composite à plusieurs niveaux regroupant toutes les fonctions graphiques actuellement proposées par le plugin. Pour activer cette fonction, reportez-vous à la [configuration des commandes de uosc](#configuration-des-commandes-de-uosc) et, selon la version d’uosc, ajoutez `button:danmaku_menu` ou `command:grid_view:script-message open_add_total_menu?弹幕设置` à l’option de configuration `controls` de `uosc.conf`.

Pour utiliser cette fonction avec un raccourci clavier, ajoutez une configuration semblable à celle ci-dessous dans `input.conf`. Le message de script correspondant à la fonction d’ajout de danmaku depuis une source est `open_add_total_menu`.

```
key script-message open_add_total_menu
```

</details>

---

**Fonctions accessibles uniquement par raccourci clavier**

<details>
<summary>Régler le décalage des danmaku</summary>

> #### Régler le décalage des danmaku (facultatif)

Vous pouvez associer la commande suivante à un raccourci clavier afin de régler le décalage des danmaku, en secondes. Le nombre de secondes indiqué s’ajoute au décalage actuel des danmaku ; il peut être négatif. La valeur 0 constitue un cas particulier : elle réinitialise le décalage à 0 et rétablit l’état initial.

```
# Régler le décalage global des danmaku
key script-message danmaku-delay <seconds>
# Régler le décalage des danmaku à partir de la position de lecture actuelle
key script-message danmaku-delay <seconds> ${=time-pos}
```

> La valeur actuelle du décalage des danmaku est disponible dans la propriété `user-data/uosc_danmaku/danmaku-delay`. Pour un exemple d’utilisation, consultez [cette issue](https://github.com/Tony15246/uosc_danmaku/issues/77).

</details>

<details>
<summary>Enregistrer les danmaku de la vidéo actuelle</summary>

> #### Enregistrer les danmaku de la vidéo actuelle (facultatif)

Permet d’enregistrer manuellement les danmaku pendant la lecture d’une vidéo, au format `xml` (remarque : le fichier de danmaku portera le même nom que la vidéo ; si un fichier du même nom existe déjà dans le dossier de destination, l’opération ne sera pas exécutée). Par défaut, il est enregistré dans le dossier de la vidéo, mais `save_danmaku_path` et `save_danmaku_path_mode` permettent de choisir un autre dossier.

Pour utiliser cette fonction avec un raccourci clavier, ajoutez une configuration semblable à celle ci-dessous dans `input.conf`. Le message de script correspondant à cette fonction est `immediately_save_danmaku`.

```
key script-message immediately_save_danmaku
```

</details>

<details>
<summary>Effacer les sources de danmaku associées à la vidéo actuelle</summary>

> #### Effacer les sources de danmaku associées à la vidéo actuelle (facultatif)

Permet d’effacer toutes les sources de danmaku que l’utilisateur a ajoutées manuellement à la vidéo actuelle depuis le menu [Obtenir des danmaku depuis une source](#ajouter-de-nouveaux-danmaku-depuis-une-source-facultatif). Cette fonction ne supprime pas les danmaku provenant du serveur de danmaku ; ceux-ci peuvent uniquement être masqués ou remplacés en associant manuellement une nouvelle bibliothèque de danmaku. Après avoir effacé les sources, elles ne seront plus chargées lors de la prochaine lecture de cette vidéo et vous pourrez les associer de nouveau.

Pour utiliser cette fonction avec un raccourci clavier, ajoutez une configuration semblable à celle ci-dessous dans `input.conf`. Le message de script correspondant est `clear-source`.

```
key script-message clear-source
```

</details>

<details>
<summary>Rechercher les mises à jour du script</summary>

> #### Rechercher les mises à jour du script (facultatif)

Vous pouvez associer la commande de script suivante à un raccourci afin de rechercher et d’installer automatiquement les mises à jour du script.

> Seules les mises à jour publiées dans les `Releases` seront recherchées.

```
key script-message check-update
```

</details>

---

## Options configurables (facultatif)

Ce plugin permet de créer un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv afin de personnaliser les options ci-dessous, d’activer des fonctions supplémentaires ou d’en ajuster les détails.

### Chargement des danmaku

<!--  Options relatives au chargement des danmaku  -->

<details>
<summary>
auto_load

> Active ou désactive le chargement entièrement automatique des danmaku

</summary>

### auto_load

#### Description

Cette option contrôle l’activation du chargement entièrement automatique des danmaku. Après le premier chargement des danmaku pour un épisode d’une série situé dans un dossier, les danmaku chargés sont automatiquement associés à cet épisode. À chaque lecture ultérieure du fichier, les danmaku correspondants seront chargés automatiquement. Tous les fichiers des autres épisodes présents dans le même dossier chargeront eux aussi automatiquement leurs danmaku lors de leur lecture.

Prenons, par exemple, la structure de dossier suivante :

```
败犬女主太多了
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_01WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_02WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_03WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_04WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_05WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_06WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_07v2WebRipHEVC_AACCHS_JP.mp4
└── KitaujiSub_Make_Heroine_ga_Oosugiru!_08WebRipHEVC_AACCHS_JP.mp4
```

Il suffit de rechercher et de charger manuellement les danmaku une fois pendant la lecture du premier épisode, `KitaujiSub_Make_Heroine_ga_Oosugiru!_01WebRipHEVC_AACCHS_JP.mp4`. Les danmaku du deuxième épisode seront alors chargés automatiquement à son ouverture, puis ceux du troisième épisode, et ainsi de suite, sans nouvelle recherche manuelle.

#### Utilisation

Pour activer cette option, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv et ajoutez-y le contenu suivant :

```
auto_load=yes
```

Attention ⚠️ : cette fonction n’est effective que si le dossier contient exclusivement plusieurs fichiers vidéo d’une seule et même série. Dans l’exemple ci-dessous, si vous recherchez et chargez manuellement les danmaku du premier épisode de « Revue Starlight », le deuxième épisode de « Girls Band Cry » devra être identifié manuellement à nouveau, ce qui écrasera les informations de danmaku de « Revue Starlight ».

```
少女歌剧
├── 少女歌剧1.mp4
├── 少女歌剧2.mp4
├── 少女歌剧3.mp4
├── 少女歌剧4.mp4
└── 哭泣少女乐队2.mp4
```

</details>

---

<details>
<summary>
autoload_for_url

> Active ou désactive le chargement automatique et l’héritage des associations de danmaku lors de la lecture d’URL

</summary>

### autoload_for_url

#### Description

Lorsque cette option est activée, les associations de danmaku des fichiers vidéo accessibles par URL potentiellement pris en charge sont mémorisées et héritées. Son utilisation avec une liste de lecture donne les meilleurs résultats. La mémorisation et l’héritage des associations de danmaku sont actuellement compatibles avec des solutions telles que [embyToLocalPlayer](https://github.com/kjtsune/embyToLocalPlayer), [mpv-torrserver](https://github.com/dyphire/mpv-config/blob/master/scripts/mpv-torrserver.lua) et [tsukimi](https://github.com/tsukinaha/tsukimi).

Pour connaître précisément la compatibilité actuelle et le résultat obtenu, consultez [cette PR](https://github.com/Tony15246/uosc_danmaku/pull/16).

Une fois cette option activée, les danmaku correspondants sont également chargés automatiquement lors de la lecture en ligne de vidéos Bilibili et Bahamut. Elle peut être utilisée avec des solutions de lecture en ligne telles que [Play-With-MPV](https://github.com/LuckyPuppy514/Play-With-MPV) ou [ff2mpv](https://github.com/woodruffw/ff2mpv). Si le chargement automatique des danmaku échoue pendant la lecture d’une vidéo Bahamut, vérifiez que l’option [proxy](#proxy) est correctement configurée.

#### Utilisation

Pour activer cette option, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv et ajoutez-y le contenu suivant :

```
autoload_for_url=yes
```

</details>

---

<details>
<summary>
auto_fallback_search

> Active ou désactive l’affichage de la boîte de recherche après l’échec du chargement entièrement automatique des danmaku

</summary>

### auto_fallback_search

#### Description

Lorsque cette option est activée et que le chargement entièrement automatique des danmaku avec `auto_load=yes` échoue pour toutes les correspondances, une boîte de recherche s’affiche afin que l’utilisateur puisse effectuer une recherche manuelle. Cette option est désactivée par défaut.

#### Utilisation

Pour activer cette option, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv et ajoutez-y le contenu suivant :

```
auto_fallback_search=yes
```

</details>

---

<details>
<summary>
autoload_local_danmaku

> Active ou désactive le chargement automatique des fichiers de danmaku au format XML situés dans le même dossier

</summary>

### autoload_local_danmaku

#### Description

Charge automatiquement le fichier de danmaku au format XML portant le même nom et situé dans le même dossier que le fichier lu.

#### Utilisation

Pour activer cette option, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv et ajoutez-y le contenu suivant :

```
autoload_local_danmaku=yes
```

</details>

---

<details>
<summary>
save_danmaku

> Active ou désactive l’enregistrement automatique des fichiers de danmaku (au format XML) dans le dossier de la vidéo

</summary>

### save_danmaku

#### Description

À la fermeture du fichier, enregistre automatiquement les danmaku au format XML dans un fichier portant le même nom que la vidéo correspondante. Par défaut, ce fichier est enregistré dans le dossier de la vidéo. Associée à l’[option autoload_local_danmaku](#autoload_local_danmaku), cette fonction permet d’enregistrer automatiquement les danmaku en local, puis de les charger automatiquement lors de la lecture suivante. Cette fonction est désactivée par défaut.

> **⚠️ REMARQUE !**
> 
> Lorsque l’[option autoload_local_danmaku](#autoload_local_danmaku) est activée, le fichier de danmaku au format XML portant le même nom et situé dans le même dossier que le fichier lu est chargé automatiquement, avec une priorité supérieure à toutes les autres fonctions de chargement automatique des danmaku. Si vous ne souhaitez pas charger à chaque lecture les danmaku précédemment enregistrés en local, désactivez l’[option autoload_local_danmaku](#autoload_local_danmaku). Vous pouvez également déplacer le fichier de danmaku vers un autre emplacement après son enregistrement, puis désactiver l’option `save_danmaku`.
> 
> L’option `save_danmaku` peut être activée ou désactivée en temps réel pendant l’exécution. Ajoutez le contenu suivant à `input.conf` afin de contrôler son activation au moyen d’un raccourci clavier :
> 
> ```
> key cycle-values script-opts uosc_danmaku-save_danmaku=yes uosc_danmaku-save_danmaku=no
> ```

#### Utilisation

Pour activer cette option, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv et indiquez le contenu suivant :

```
save_danmaku=yes
```

Pour enregistrer les fichiers dans un dossier donné, créez d’abord le dossier de destination, puis configurez `save_danmaku_path` et `save_danmaku_path_mode`. Le plugin ne crée pas les dossiers automatiquement.

Lorsqu’un média local est enregistré dans un dossier donné, le nom du fichier inclut celui du dossier parent de la vidéo afin de réduire les conflits entre les fichiers de danmaku de vidéos de même nom placées dans des dossiers différents. Par exemple, `动画/01.mkv` sera enregistré sous un nom tel que `动画_01.xml`. Pour un média en ligne enregistré dans un dossier donné, le titre du média reste utilisé comme nom de fichier.

Valeurs possibles de `save_danmaku_path_mode` :

- `local` : valeur par défaut ; seuls les médias locaux sont enregistrés dans `save_danmaku_path`, tandis que les médias en ligne ne sont toujours pas enregistrés
- `url` : seuls les médias en ligne sont enregistrés dans `save_danmaku_path`, tandis que les médias locaux restent enregistrés dans le dossier de la vidéo
- `all` : les médias locaux et en ligne sont tous enregistrés dans `save_danmaku_path`

Exemple pour enregistrer uniquement les danmaku des médias en ligne dans `~~/danmaku` :

```
save_danmaku=yes
save_danmaku_path=~~/danmaku
save_danmaku_path_mode=url
```

Exemple pour enregistrer les danmaku de tous les médias dans `~~/danmaku` :

```
save_danmaku=yes
save_danmaku_path=~~/danmaku
save_danmaku_path_mode=all
```

</details>

---

### Affichage des danmaku

(Pour personnaliser plus finement le style des danmaku, consultez [Personnalisation du style des danmaku](#configuration-personnalisée-du-style-des-danmaku).)

<!--  Options relatives à l’affichage des danmaku  -->

<details>
<summary>
opacity

> Personnalise l’opacité des danmaku

</summary>

### opacity

#### Description

Personnalise l’opacité des danmaku, de 0 (entièrement transparents) à 1 (opaques). Valeur par défaut : 0.7

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le répertoire `script-opts` du dossier de configuration de mpv, puis personnalisez son contenu comme suit :

```
opacity=0.7
```

</details>

---

<details>
<summary>
chConvert

> Active ou désactive la conversion entre chinois simplifié et traditionnel

</summary>

### chConvert

#### Description

Conversion entre chinois simplifié et traditionnel. 0 : aucune conversion ; 1 : conversion en chinois simplifié ; 2 : conversion en chinois traditionnel. Valeur par défaut : 0, aucune conversion ; les danmaku sont affichés dans leur graphie d’origine

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le répertoire `script-opts` du dossier de configuration de mpv, puis personnalisez son contenu comme suit :

```
chConvert=0
```

</details>

---

<details>
<summary>
merge_tolerance

> Active ou désactive la fusion des danmaku en double et définit la valeur de tolérance

</summary>

### merge_tolerance

#### Description

Définit la tolérance de l’intervalle temporel utilisé pour fusionner les danmaku en double, en secondes. Valeur par défaut : -1, ce qui désactive la fonctionnalité

Lorsque cette valeur est définie sur 0, les danmaku au contenu identique et apparaissant au même instant sont fusionnés. Lorsqu’elle est supérieure à 0, les danmaku au contenu identique sont fusionnés s’ils se trouvent dans l’intervalle de tolérance défini, en secondes

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le répertoire `script-opts` du dossier de configuration de mpv, puis personnalisez son contenu comme suit :

```
merge_tolerance=1
```

</details>

---

<details>
<summary>
merge_without_style

> Détermine si les différences de type et de couleur doivent être ignorées lors de la fusion des danmaku en double

</summary>

### merge_without_style

#### Description

S’utilise avec `merge_tolerance`. Valeur par défaut : `no` (désactivé)

Lorsque cette option est activée, les danmaku dont le texte est identique et qui se trouvent dans l’intervalle de tolérance défini par `merge_tolerance` sont fusionnés de force, même si leur type de positionnement diffère (en haut, en bas ou défilant, par exemple) ou si leur couleur est différente, quelle que soit l’ampleur de cette différence.
Lorsqu’elle est désactivée, les danmaku ne sont fusionnés que si leur contenu et leur type de positionnement sont identiques et si leur différence de couleur est imperceptible à l’œil nu (différence minime).

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le répertoire `script-opts` du dossier de configuration de mpv, puis personnalisez son contenu comme suit :

```
merge_without_style=yes
```

</details>

---

<details>
<summary>
merge_fontsize_growth

> Définit la vitesse à laquelle la taille de police des danmaku fusionnés augmente avec leur nombre

</summary>

### merge_fontsize_growth

#### Description

S’utilise avec `merge_tolerance`. La valeur par défaut est `8` et doit être un entier positif. En prenant `fontsize` comme taille de police de base et `n` comme nombre de danmaku fusionnés, la taille de police réelle est calculée ainsi :

```
min(merge_fontsize_max, fontsize + round(merge_fontsize_growth * ln(n)))
```

Avant l’arrondi, la fonction logarithmique est strictement croissante et strictement concave : l’agrandissement est donc marqué lorsque peu de danmaku sont fusionnés, puis l’augmentation de la taille de police apportée par chaque danmaku supplémentaire diminue progressivement. Après l’arrondi, la taille de police entière ne décroît jamais et reste limitée par `merge_fontsize_max`. Les danmaku utilisant une grande taille de police occupent sur l’axe y un intervalle continu correspondant à leur hauteur réelle ; si aucune position sans collision n’est disponible dans la zone d’affichage de l’écran, ils sont ignorés.

#### Utilisation

```
merge_fontsize_growth=8
```

</details>

---

<details>
<summary>
merge_fontsize_max

> Limite la taille de police maximale des danmaku fusionnés

</summary>

### merge_fontsize_max

#### Description

S’utilise avec `merge_fontsize_growth`. La valeur par défaut est `100`. Quel que soit le nombre de danmaku fusionnés, la taille de police finale ne dépassera pas cette valeur ; si celle-ci est inférieure à la taille de base `fontsize`, la taille de base sera utilisée.

#### Utilisation

```
merge_fontsize_max=100
```

</details>

---

<details>
<summary>
max_screen_danmaku

> Limite le nombre de danmaku affichés simultanément à l’écran

</summary>

### max_screen_danmaku

#### Description

Lorsque cette valeur est supérieure à 0, le script ignore certains danmaku pendant l’analyse afin que leur nombre affiché à l’écran ne dépasse à aucun moment la limite définie.

#### Utilisation

Créez un fichier `uosc_danmaku.conf` dans le répertoire `script-opts` et ajoutez-y le contenu suivant :

```
max_screen_danmaku=60
```

</details>

---

<details>
<summary>
vf_fps

> Active ou désactive l’utilisation du filtre vidéo fps pour améliorer la fluidité des danmaku (fréquence d’images)

</summary>

### vf_fps

#### Description

Indique s’il faut utiliser le filtre vidéo fps `@danmaku:fps=fps=60/1.001`, qui peut améliorer considérablement la fluidité des danmaku. Désactivé par défaut

Ce filtre vidéo est toutefois très exigeant en ressources ; ne l’activez qu’après vous être assuré que les performances de votre appareil sont suffisantes

Une fois l’option activée, elle ne prend effet que si la fréquence d’images de la vidéo est inférieure à 60 et si la fréquence de rafraîchissement de l’écran est supérieure ou égale à 60

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le répertoire `script-opts` du dossier de configuration de mpv, puis indiquez le contenu suivant :

```
vf_fps=yes
```

</details>

---

<details>
<summary>
fps

> Personnalise les paramètres du filtre fps en fonction de la fréquence de rafraîchissement de l’écran

</summary>

### fps

#### Description

Définit les paramètres du filtre fps à utiliser. Par exemple, si `fps` vaut `60/1.001`, le paramètre effectif du filtre vidéo sera `@danmaku:fps=fps=60/1.001`

Cette option permet d’adapter les paramètres du filtre vidéo à la fréquence de rafraîchissement de votre écran

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le répertoire `script-opts` du dossier de configuration de mpv, puis indiquez le contenu suivant :

```
fps=60/1.001
```

</details>

---

### Paramètres relatifs au service d’analyse des danmaku

<!--  Les options suivantes concernent le service d’analyse des danmaku  -->

<details>
<summary>
api_server

> Personnalise l’API des danmaku

</summary>

### api_server

#### Description

Permet de personnaliser l’adresse du service de l’API des danmaku. Par défaut, le service maintenu par le projet, `https://danmaku-api.152468.xyz`, est utilisé ; un proxy se charge de l’authentification auprès de l’API DanDanPlay, de sorte que les utilisateurs du module n’ont pas besoin de configurer de clé.

Il est possible d’indiquer une liste ordonnée de plusieurs `api_server`, séparés par des virgules (`ordonnée` signifie que les résultats de recherche associés au même ID d’épisode seront regroupés en une seule entrée selon l’ordre des serveurs dans `api_server`).

Chaque entrée peut comporter une note séparée par « | » ou « # », par exemple : « https://a.example.com|SecoursA » ou « https://b.example.com#SecoursB »

Lors d’une recherche d’épisode avec plusieurs `api_server`, vous pouvez utiliser la forme « nom de l’épisode@note du serveur » afin de limiter la recherche au seul `api_server` correspondant à cette note

> **⚠️REMARQUE !**
> 
> Assurez-vous que l’API du service personnalisé est compatible avec celle de DanDanPlay. Compatibilités connues : [misaka_danmu_server](https://github.com/l429609201/misaka_danmu_server), [danmu_api](https://github.com/huangxd-/danmu_api)
>
> Aucun AppId/AppSecret DanDanPlay ne doit être configuré lorsque vous accédez à DanDanPlay par l’intermédiaire de l’API proxy par défaut. Pour utiliser des identifiants AppId/AppSecret DanDanPlay obtenus personnellement, vous pouvez déployer vous-même un proxy côté serveur et faire pointer `api_server` vers celui-ci.

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le répertoire `script-opts` du dossier de configuration de mpv, puis personnalisez son contenu comme suit :

```
api_server=https://danmaku-api.152468.xyz
```

</details>

---

<details>
<summary>
fallback_server

> Personnalise l’adresse du serveur de secours utilisé pour récupérer les danmaku de Bilibili, iQIYI, Tencent Video et Youku

</summary>

### fallback_server

#### Description

Personnalise l’adresse du serveur de secours utilisé pour récupérer les danmaku de Bilibili, iQIYI, Tencent Video et Youku, principalement pour les contenus autres que les œuvres d’animation. Le serveur défini ici n’est utilisé pour l’analyse que si aucun des **`api_server`** configurés ni aucun des `analyseurs propres à chaque site` intégrés au module ne parvient à récupérer les danmaku correspondant à la source vidéo. Serveur disponible : https://dmku.hls.one

> **⚠️REMARQUE !**
>
> Le module intègre déjà, dans le répertoire `sites`, des analyseurs de danmaku dédiés aux principaux sites vidéo ([#377](https://github.com/Tony15246/uosc_danmaku/pull/377) [#380](https://github.com/Tony15246/uosc_danmaku/pull/380)). Le serveur de secours n’est utilisé que si aucun de ces analyseurs dédiés ne parvient à récupérer les danmaku du site
>
> Si cette option n’est pas définie, ` https://dmku.hls.one` est utilisé par défaut comme serveur de secours

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le répertoire `script-opts` du dossier de configuration de mpv, puis personnalisez son contenu comme suit :

```
fallback_server=https://dmku.hls.one
```

</details>

---

<details>
<summary>
tmdb_api_key

> Clé API TMDB personnalisée permettant d’obtenir les informations en chinois des œuvres qui ne sont pas des animes

</summary>

### tmdb_api_key

#### Description

Définit la clé API TMDB utilisée pour obtenir les informations en chinois des œuvres qui ne sont pas des animes (lorsque le contenu recherché n’est pas en chinois). Vous pouvez vous inscrire sur https://www.themoviedb.org, puis récupérer votre clé API TMDB personnelle dans les paramètres de votre compte.

> **⚠️REMARQUE !**
> 
> Si cette option n’est pas définie, la clé API demandée spécialement pour ce projet est utilisée par défaut. Par ailleurs, si vous personnalisez cette option, vous devez encoder en base64 la clé API obtenue.

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv, puis personnalisez-le comme suit :

```
tmdb_api_key=NmJmYjIxOTZkNzIyN2UyMTIzMGM3Y2YzZjQ4MDNkZGM=
```

</details>

---

### Configuration du plugin

<details>
<summary>
user_agent

> Personnaliser le User-Agent des requêtes

</summary>

### user_agent

#### Description

Personnalise le User-Agent utilisé par `curl` pour envoyer les requêtes réseau. La valeur par défaut est `mpv_danmaku/1.0`.

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv, puis personnalisez-le comme suit (la valeur ne peut pas être vide) :

> **⚠️REMARQUE !**
> 
> Lorsque vous utilisez le proxy d’API par défaut, il n’est pas nécessaire de modifier le User-Agent pour l’authentification auprès de Dandanplay. Si vous accédez directement à l’API officielle de Dandanplay ou à un autre service personnalisé, respectez les exigences de ce service concernant le User-Agent.
> 
> Pour augmenter le taux de réussite de la correspondance par hachage lors de la lecture d’une URL, vous pouvez définir cette option sur `mpv` ou sur le User-Agent d’un navigateur.

```
user_agent=mpv_danmaku/1.0
```

</details>

---

<details>
<summary>
proxy

> Personnaliser le proxy des requêtes

</summary>

### proxy

#### Description

Personnalise le proxy utilisé par `curl` pour envoyer les requêtes réseau. Il est désactivé par défaut.

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv, puis personnalisez-le comme suit :

```
proxy=127.0.0.1:7890
```

</details>

---

<details>
<summary>
message_x

> Personnaliser la position d’affichage des messages du plugin (axe x)

</summary>

### message_x

#### Description

Personnalise la position d’affichage des messages du plugin, en définissant leur distance sur l’axe x à partir du coin supérieur gauche de l’écran.

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv, puis personnalisez-le comme suit :

```
message_x=30
```

</details>

---

<details>
<summary>
message_y

> Personnaliser la position d’affichage des messages du plugin (axe y)

</summary>

### message_y

#### Description

Personnalise la position d’affichage des messages du plugin, en définissant leur distance sur l’axe y à partir du coin supérieur gauche de l’écran.

#### Utilisation

Pour utiliser cette option, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv, puis personnalisez-le comme suit :

```
message_y=30
```

</details>

---

<details>
<summary>
title_replace

> Personnaliser les règles de remplacement supplémentaires lors de l’analyse du titre de fichier

</summary>

### title_replace

Personnalise les règles de remplacement supplémentaires lors de l’analyse du titre. Le contenu est une chaîne JSON et le remplacement utilise la fonction `string.gsub` de Lua.

Attention ⚠️ : en raison des limitations de la version de Lua intégrée à mpv, les règles personnalisées prennent uniquement en charge les groupes de capture de la forme %n, comme dans l’exemple. Le remplacement direct de caractères n’est pas pris en charge.

Exemple d’utilisation :

```
title_replace=[{"rules":[{ "^〔(.-)〕": "%1"},{ "^.*《(.-)》": "%1" }]}]
```

</details>

---

<details>
<summary>
excluded_path

> Spécifier les chemins ou répertoires des lecteurs partagés (lecteurs montés) à ignorer lors de la correspondance par hachage

</summary>

### excluded_path

Spécifie les chemins ou répertoires des lecteurs partagés (lecteurs montés) à ignorer lors de la correspondance par hachage. Les chemins absolus et relatifs sont pris en charge ; séparez plusieurs chemins par des virgules.

Exemple d’utilisation :

```
excluded_path=["X:", "Z:", "F:/Download/", "Download"]
```

</details>

---

<details>
<summary>
history_path

> Spécifier le chemin du fichier d’historique des associations de danmaku

</summary>

### history_path

#### Description

Spécifie le chemin du fichier d’historique des associations de danmaku. Les chemins absolus et relatifs sont pris en charge. La valeur par défaut est `~~/danmaku-history.json`, c’est-à-dire la racine du répertoire de configuration de mpv.

#### Exemple d’utilisation

Pour configurer cette option, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv, puis ajoutez-y un contenu semblable au suivant :

> **⚠️IMPORTANT**
> Ne copiez pas directement cette configuration : il ne s’agit que d’un exemple et le chemin doit correspondre à un chemin existant. Cette option est facultative ; par défaut, le script place le fichier à la racine du répertoire de configuration de mpv.

```
history_path=/path/to/your/danmaku-history.json
```

</details>

---

### Configuration personnalisée du style des danmaku

La configuration par défaut est indiquée ci-dessous. Vous pouvez la modifier selon vos besoins afin de personnaliser le style des danmaku.

Pour configurer ces options, créez un fichier `uosc_danmaku.conf` dans le dossier `script-opts` du répertoire de configuration de mpv, puis ajoutez-y un contenu semblable au suivant :

```
#Durée d’affichage des danmaku défilants
scrolltime=15
#Durée d’affichage des danmaku fixes
fixtime=5
#Police (inutile d’entourer le nom de guillemets "")
fontname=sans-serif
#Taille
fontsize=50
#Ombre
shadow=0
#Gras
bold=yes
#Zone d’affichage de l’ensemble des danmaku (0.0-1.0)
displayarea=0.85
#Contour 0-4
outline=1
#Chemin du fichier de mots à bloquer dans les danmaku (black.txt) ; les chemins absolus et relatifs sont pris en charge. Séparez les entrées par des sauts de ligne
##La syntaxe des expressions régulières de Lua est prise en charge
blacklist_path=
```

## Propriétés personnalisées du plugin

- `user-data/uosc_danmaku/danmaku-delay`

    La propriété `user-data/uosc_danmaku/danmaku-delay` permet d’obtenir la valeur actuelle du décalage des danmaku. Pour un exemple concret, consultez [cette issue](https://github.com/Tony15246/uosc_danmaku/issues/77).

- `user-data/uosc_danmaku/has-danmaku`

    La propriété `user-data/uosc_danmaku/has-danmaku` permet d’obtenir une valeur booléenne indiquant si des danmaku sont actuellement affichés. Pour un exemple concret, consultez [cette PR](https://github.com/Tony15246/uosc_danmaku/pull/276).

- `user-data/uosc_danmaku/danmaku-switch-on`

    La propriété `user-data/uosc_danmaku/danmaku-switch-on` permet d’obtenir une valeur booléenne indiquant l’état actuel de l’interrupteur des danmaku. Pour un exemple concret, consultez [cette issue](https://github.com/Tony15246/uosc_danmaku/issues/362).

- `user-data/uosc_danmaku/danmaku-count`

    La propriété `user-data/uosc_danmaku/danmaku-count` permet d’obtenir le nombre total de danmaku présents dans le pool actuel.

## Questions fréquentes

### Comment corriger à la source les problèmes liés aux sources de danmaku provenant de Dandanplay

Tous les danmaku d’animes utilisés par ce plugin proviennent de l’[API Dandanplay](https://github.com/kaedei/dandanplay-libraryindex/blob/master/api/OpenPlatform.md). Vous pouvez donc rencontrer des problèmes tels que `certains animes n’ont pas de danmaku` ou `la chronologie des danmaku n’est pas synchronisée`. Vous pouvez les résoudre à l’aide des fonctions [Obtenir des danmaku depuis une source](#ajouter-de-nouveaux-danmaku-depuis-une-source-facultatif) et [Régler le décalage d’une source de danmaku](#réglage-du-décalage-des-sources-de-danmaku-facultatif) de ce plugin. Toutefois, si vous souhaitez contribuer aux sources afin de résoudre ces problèmes à la racine pour l’ensemble des utilisateurs, suivez le tutoriel ci-dessous :

1. Téléchargez l’[application Dandanplay pour PC](https://www.dandanplay.com).

2. Dans Dandanplay, `lisez n’importe quel fichier vidéo`, puis `associez-le à la bibliothèque de danmaku de l’anime que vous souhaitez corriger`.

3. Suivez ensuite le tutoriel détaillé ci-dessous pour modifier la source de danmaku et synchroniser ces changements pour tous les utilisateurs.

**Ajouter une source de danmaku à un anime**

Pour ajouter des danmaku à un anime, utilisez la fonction `Menu des paramètres vidéo` → `Liste des danmaku` → `Ajouter davantage de danmaku` afin d’ajouter les danmaku correspondants.

> [!NOTE]
> Pour que les modifications soient répercutées dans les danmaku de l’API (et donc de ce plugin), ajoutez trois fois le même lien, conformément au mécanisme de vote de Dandanplay.

**Régler le décalage d’une source de danmaku d’un anime**

Pour modifier le décalage d’une source de danmaku d’un anime, ouvrez `Menu des paramètres vidéo` → `Modifier les sources de danmaku`, puis copiez l’URL exacte de la source à modifier et supprimez-la. Utilisez ensuite la fonction `Menu des paramètres vidéo` → `Liste des danmaku` → `Ajouter davantage de danmaku` pour l’ajouter de nouveau. Lors de l’ajout, modifiez le `Décalage des danmaku` (en secondes) sous `Danmaku sélectionnés`, puis ajoutez à nouveau la source trois fois pour que les danmaku de l’API soient synchronisés.

Par ailleurs, les sources de danmaku de Dandanplay sont depuis toujours maintenues et associées manuellement. Merci à toutes les personnes qui contribuent de cette manière.

## Remerciements particuliers

Merci aux projets suivants, qui ont servi de référence pour l’implémentation ou fourni des dépendances externes à ce projet :

- API de danmaku : [Dandanplay](https://github.com/kaedei/dandanplay-libraryindex/blob/master/api/OpenPlatform.md)
- API de menus : [uosc](https://github.com/tomasklaen/uosc)
- Analyse et conversion des formats de danmaku : [DanmakuConvert](https://github.com/timerring/DanmakuConvert)
- Conversion entre chinois traditionnel et simplifié : [OpenCC](https://github.com/BYVoid/OpenCC)
- Implémentation native en Lua du calcul MD5 : https://github.com/rkscv/danmaku
- Implémentation native en Lua de la décompression ZIP : [lua-inflate](https://github.com/TohruMKDM/lua-inflate)
- Référence pour l’analyse des danmaku d’iQIYI, Youku, Tencent Video et Mango TV : https://github.com/lyz05/danmaku
- Référence pour la récupération des danmaku lors de la lecture en ligne sur Bilibili : [MPV-Play-BiliBili-Comments](https://github.com/itKelis/MPV-Play-BiliBili-Comments)
- Référence pour la récupération des danmaku lors de la lecture en ligne sur Bahamut : [MPV-Play-BAHA-Comments](https://github.com/s594569321/MPV-Play-BAHA-Comments)

## Projets associés

- [slqy123/uosc_danmaku](https://github.com/slqy123/uosc_danmaku) est un fork de ce projet qui permet d’envoyer des danmaku via l’API Dandanplay. Il n’a pas été fusionné en raison de problèmes de compatibilité entre les versions et de facilité d’utilisation. Consultez [#220](https://github.com/Tony15246/uosc_danmaku/pull/220) pour plus de détails.
- ~~[Loukyuu1120/uosc_danmaku](https://github.com/Loukyuu1120/uosc_danmaku) est un fork de ce projet qui permet de définir plusieurs `api_servers` personnalisés et propose un menu de sélection des sources de danmaku. Consultez [#282](https://github.com/Tony15246/uosc_danmaku/issues/282) pour plus de détails.~~ Ces fonctionnalités ont depuis été intégrées au dépôt principal.
