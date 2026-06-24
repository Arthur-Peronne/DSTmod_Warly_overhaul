# Journal des sessions de travail

## Session 1 — 2026-06-21

### Ce qui a été fait

**Documentation :**
- Lu et analysé `Ressources/Initial project.odt` et `Ressources/Initial recipes table.ods`
- Créé `CONTENT.md` : spécifications complètes à jour (fusion des deux fichiers source + décisions confirmées)
- Créé `TODOLIST.md` : converti depuis `ai_agent/Todolist_DSTmodWarly.txt`, ajout Phase 8 (dialogues), ajout suppression fast fire-cooking et restriction "cuisinables par Warly uniquement"
- Reformaté `TECHNICAL.md` en markdown propre
- Allégé `CLAUDE.md` : suppression des redondances, pointeurs vers les 3 fichiers, auto-import TODOLIST.md

**Décisions de design confirmées :**
- Refus dur de manger à 0% (sans seuil d'urgence)
- Plats exclusifs cuisinables sur n'importe quel crock pot (pas uniquement le portable)
- Sweet smoothie : "x2 damage sur ressources" (pas "chopping efficiency")
- Volt goat : "-10% damage given + electric damage"
- Grim galette : catégorie "Status dishes (stats)", pas "Status éléments"
- Types Meat/Veggie/All intégrés dans CONTENT.md (manquaient dans CLAUDE.md original)

**Infrastructure :**
- Dépôt git créé, push sur GitHub (HTTPS + token stocké)
- `.gitignore` : `.~lock.*` + `/Ressources`
- Scripts vanilla DST déplacés dans `Ressources/dst_scripts/` (exclus du git)

**Phase 1.1 terminée :**
- `modinfo.lua` créé (api_version 10, dst_compatible, all_clients_require_mod true)
- `modmain.lua` minimal (print de debug)
- `scripts/components/` et `scripts/prefabs/` créés avec `.gitkeep`

### Points utiles pour la suite

- `all_clients_require_mod = true` est nécessaire car les clients doivent connaître les recettes et stats modifiées pour éviter les désynchronisations
- Les scripts vanilla DST sont consultables dans `Ressources/dst_scripts/` (non trackés git)
- Prochaine étape : **Phase 1.2** — patcher Hunger 200 et supprimer hunger drain via `AddPrefabPostInit("warly", ...)`

---

## Session 2 — 2026-06-23

### Ce qui a été fait

**Phase 1 complète et testée en jeu :**
- Stats Warly : hunger max 200, rate Wilson, inventaire de départ vide
- Tags supprimés : `expertchef` (fast fire-cooking), `professionalchef` (crafting épices)
- Recettes désactivées : `portablespicer_item`, `portableblender_item`, `spicepack` via `GLOBAL.AllRecipes`
- Setup workflow : copie directe (symlinks non supportés sur Linux), alias `sync-warly` avec rsync

**Infrastructure de test établie :**
- Console LOCAL : entité client, pas de composants gameplay, `print()` affiché à l'écran
- Console REMOTE : entité serveur, composants disponibles, utiliser `c_announce()` pour afficher à l'écran

### Leçons de debugging critiques (voir TECHNICAL.md pour le détail)

- `AddPrefabPostInit("warly", fn)` fire à la sélection du personnage (TheWorld nil) et **une seule fois** — ne pas retourner trop tôt
- Pattern correct : pas de guard pour `RemoveTag` et `starting_inventory`, guard `if inst.components.hunger then` pour les composants
- `AddComponentPostInit` fire avant la fin du prefab → le vanilla peut écraser les valeurs → préférer `AddPrefabPostInit` pour `SetMax`
- `GetValidRecipe()` n'existe pas → utiliser `GLOBAL.AllRecipes["nom"]`
- Noms exacts des recettes spices : `portableblender_item` (pas `portableblender`), `portablespicer_item`, `spicepack`

### Prochaine étape

**Phase 2** — Mémoire alimentaire FIFO :
1. `scripts/warly_config.lua` — constantes (seuils jours, valeurs N, malus, liste plats exclusifs)
2. `scripts/components/warly_foodmemory.lua` — queue FIFO, `RememberFood`, `GetOccurrences`, `GetMultiplier`, `OnSave`/`OnLoad`
3. Branchement sur Warly via `AddPrefabPostInit` + `eater.custom_stats_mod_fn`

---

## Session 3 — 2026-06-24

### Ce qui a été fait

**Phase 2 complète et testée en jeu :**

- `scripts/warly_config.lua` — constantes FIFO (seuils 35/70 jours, N 2/3/4, malus 0.25, liste 15 plats exclusifs avec noms vanilla pour les plats modifiés)
- `scripts/components/warly_foodmemory.lua` — queue FIFO avec `GetMemorySize` (dynamique via `TheWorld.state.cycles`), `RememberFood`, `GetOccurrences`, `GetMultiplier`, `OnSave`/`OnLoad`
- Branchement dans `modmain.lua` :
  - `foodmemory` vanilla patché en proxy (`GetFoodMultiplier → 1`, `GetMemoryCount → notre queue`, `RememberFood → no-op`) plutôt que supprimé — nécessaire pour que `wisecracker.lua` trouve le composant
  - `custom_stats_mod_fn` branché sur `warly_foodmemory:GetMultiplier`
  - `oneat` listener : enregistre le repas + override les speeches SAME_OLD

**Speeches liés aux occurrences :**
- Wisecracker réutilisé comme base (fire en premier), notre listener l'override
- Table de correspondance occ → SAME_OLD_1/2/4/5 (SAME_OLD_3 skippé volontairement)
- `GetOccurrences` lu **avant** `RememberFood` pour avoir le count pré-repas

### Leçons de debugging

- `GetString()` n'est pas disponible directement dans le sandbox mod → utiliser `GLOBAL.GetString()`
- Les `ListenForEvent` enregistrés dans `AddPrefabPostInit` firen **après** ceux enregistrés dans les composants vanilla (ordre d'enregistrement) → notre talker:Say() override naturellement wisecracker
- `wisecracker.lua` utilise `foodmemory:GetMemoryCount()` pour les speeches → si `foodmemory` est nil (supprimé), count=0 et Warly dit toujours TASTY

### Prochaine étape

**Phase 3** — Widget HUD sous la jauge de faim (affichage des N derniers repas + multiplicateur)
