### Ce dossier contient les fichiers de configuration des scripts mpv

En règle générale, le fichier de configuration porte le même nom que le script auquel il se rapporte ; attention, les `-` présents dans le nom du script doivent par défaut être convertis en `_`. En pratique, c'est le choix du développeur du script qui fait foi.

Ne jamais « embellir » la mise en forme d'un fichier de configuration (par exemple en ajoutant des espaces inutiles) ; ne jamais écrire de commentaire à la suite d'une option (un commentaire doit occuper sa propre ligne).

Les scripts et leurs fichiers de configuration peuvent ne pas gérer les fins de ligne CRLF de Windows (essayez de les convertir en LF).

Toutes les situations décrites ci-dessus risquent, lorsque vous modifiez ces fichiers vous-même, de rendre (partiellement) inopérant le fichier de configuration.

Voici les fichiers de configuration utilisés par les scripts intégrés à mpv :

```
console.conf
osc.conf
stats.conf
ytdl_hook.conf
```

