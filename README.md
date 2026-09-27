# mpv-config — fork français et personnalisé

Ce dépôt est un fork de [dyphire/mpv-config](https://github.com/dyphire/mpv-config), adapté pour proposer une configuration mpv francophone, cohérente et exclusivement destinée à Linux.

Il ne s’agit pas d’un miroir ni d’une traduction figée à l’identique. Le projet source sert de base technique et continue d’alimenter ce fork, mais les mises à jour sont intégrées de manière sélective. Les valeurs par défaut, les raccourcis, les scripts retenus et certains choix d’interface peuvent donc volontairement diverger de l’amont.

## Objectifs

- fournir des commentaires, menus, messages OSD et documentations en français ;
- conserver les scripts, correctifs et améliorations utiles publiés par le projet source ;
- proposer des réglages par défaut adaptés à Linux plutôt que de conserver tous les choix historiques orientés Windows ;
- privilégier les sous-titres français, puis anglais ;
- conserver une configuration directement utilisable, tout en restant facile à personnaliser ;
- documenter les divergences importantes avec le projet amont.

## Philosophie du fork

Les mises à jour de [dyphire/mpv-config](https://github.com/dyphire/mpv-config) ne sont pas recopiées aveuglément. À chaque synchronisation :

1. les nouveaux scripts, correctifs et options utiles sont examinés ;
2. les changements incompatibles avec Linux ou avec les choix de ce fork sont adaptés ;
3. les textes destinés à l’utilisateur sont traduits en français ;
4. les réglages personnalisés sont conservés lorsqu’ils restent pertinents ;
5. la configuration est vérifiée avec une version réelle de mpv avant validation.

Cette approche signifie que deux versions contemporaines des dépôts amont et français peuvent avoir des comportements par défaut différents. C’est intentionnel.

## Principales différences actuelles

- API graphique Vulkan ;
- sortie audio ALSA ;
- socket IPC Linux dans `/tmp/mpvsocket` ;
- taille initiale de fenêtre limitée à 70 % de l’écran ;
- chargement automatique des pistes audio et des sous-titres externes ;
- recherche des pistes audio dans `audio` et `audios` ;
- recherche des sous-titres dans `sub`, `subs` et `subtitles` ;
- priorité aux sous-titres français, puis anglais ;
- rendu des polices par Fontconfig et police `Noto Sans` ;
- menus uosc, messages et principaux commentaires traduits en français ;
- raccourcis clavier et souris adaptés à un clavier AZERTY sous Linux ;
- suppression des scripts Windows, des services chinois, de la WebUI, de TorrServer et des anciens composants archivés.

La configuration détaillée et les explications de chaque option se trouvent dans `mpv.conf`, `input.conf`, `inputevent_key.conf` et le dossier `script-opts`.

## Installation

### Linux

Sauvegardez d’abord votre configuration actuelle, puis placez le contenu du dépôt dans :

```text
~/.config/mpv/
```

Exemple de sauvegarde :

```sh
cp -a ~/.config/mpv ~/.config/mpv.backup
```

### Autres systèmes

Ce fork ne cherche plus à prendre en charge Windows. Pour ce système, utilisez de préférence le projet source.

## État du travail

La francisation couvre la configuration principale, les menus, de nombreux scripts et leurs options. Certains éléments restent volontairement dans leur langue d’origine lorsqu’ils constituent :

- des fichiers de traduction pour d’autres langues ;
- des expressions régulières servant à détecter des titres ou des chapitres ;
- des données de conversion linguistique ;
- des noms propres, des identifiants d’API ou des chaînes nécessaires à un service tiers ;
- du contenu juridique provenant d’une licence.

## Changements prévus

- poursuivre la relecture des traductions françaises ;
- intégrer régulièrement les changements pertinents du dépôt source ;
- consigner plus clairement les divergences fonctionnelles avec l’amont ;
- vérifier la compatibilité avec les nouvelles versions de mpv, uosc et des scripts inclus ;
- préparer, lorsque l’ensemble sera suffisamment stable, des versions faciles à installer et à mettre à jour.

## Projet source et références

- projet source : [dyphire/mpv-config](https://github.com/dyphire/mpv-config) ;
- lecteur mpv : [mpv-player/mpv](https://github.com/mpv-player/mpv) ;
- installation de mpv : [mpv.io/installation](https://mpv.io/installation) ;
- manuel officiel : [mpv.io/manual](https://mpv.io/manual/master/) ;
- interface uosc : [tomasklaen/uosc](https://github.com/tomasklaen/uosc).

Merci aux auteurs et contributeurs du projet source ainsi qu’aux développeurs des scripts et nuanceurs inclus dans cette configuration.
