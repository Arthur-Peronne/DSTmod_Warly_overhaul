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

---

## Session 4 — 2026-06-27

### Ce qui a été fait

**Modifications des specs avant de continuer :**
- TODOLIST restructurée : refus de manger déplacé de Phase 4 → fin de Phase 2 (étape 7), HUD devient étape 8, phases renommées (5→4, 6→5, 7→6, 8→7)
- CONTENT.md : multiplicateurs passés de formule (-25% par occurrence) à **valeurs fixes configurables** ; option x1.5 durée des buffs ajoutée ; option "damage bonus additif/multiplicatif" supprimée
- `warly_config.lua` : `PENALTY_PER_OCCURRENCE = 0.25` → `MULTIPLIERS = { 0.75, 0.50, 0.25, 0.00 }` + `BUFF_DURATION_BONUS = 1.5`
- `warly_foodmemory.lua` : `GetMultiplier` mis à jour pour lire `WARLY_CONFIG.MULTIPLIERS[occ]` au lieu de calculer

**`ai_agent/DEBUG.md` créé** — procédure complète de debug : workflow sync-warly, commandes console, vérification de la food memory, protocole de test des multiplicateurs.

**Étape 7 — Refus de manger (Phase 2) :**
- Première tentative : override de `Eat()` → incorrect : l'animation d'eat et le son jouent déjà quand `Eat()` est appelé ; ACTIONFAIL déclenche "I cannot do that"
- Solution finale : override de `PrefersToEat()` — SGwilson vérifie cette méthode **avant** de lancer l'animation. Si false → `wonteatfood` pushé → `GoToState("refuseeat")` → animation et son corrects, pas d'ACTIONFAIL
- Speech de refus (SAME_OLD_5 = "Enough already!") géré via `ListenForEvent("wonteatfood")` avec guard `GetMultiplier == 0`

### Leçons de debugging

- `Eat()` est appelé pendant l'animation d'eat → trop tard pour changer l'animation ou empêcher le son
- `PrefersToEat()` est le bon point d'accroche pour le refus : intercepté par SGwilson AVANT toute animation
- `wonteatfood` event → `GoToState("refuseeat")` : mécanisme identique à Wigfrid refusant un plat non-diététique
- ACTIONFAIL ("I cannot do that") se déclenche quand `Eat()` retourne nil — évité en hookant `PrefersToEat` plutôt que `Eat`

### Prochaine étape

**Phase 3** — Widget HUD sous la jauge de faim (affichage des N derniers repas + multiplicateur)

---

## Session 5 — 2026-06-28

### Ce qui a été fait

**Phase 3 — Widget HUD (en cours, non terminée) :**

Deux bugs identifiés et corrigés dans le code initial :

1. **Crash serveur au manger** :
   - `oneat` fire dans la pile d'appel de `Eater:Eat()` côté serveur
   - Appeler `KillAllChildren()` + créer des widgets depuis cette pile plantait le serveur → déconnexion
   - Fix : envelopper `RefreshIcons()` dans `self.inst:DoStaticTaskInTime(0, fn)` dans le listener `oneat`

2. **Widget hors écran** :
   - `pos.x + 20` poussait le widget hors de l'écran (heart badge déjà proche du bord droit)
   - Fix : `pos.x` (même x que le badge santé)

**Découverte critique — séparation client/serveur DST :**
- `AddClassPostConstruct("widgets/statusdisplays", fn)` s'exécute dans le contexte **client**
- `self.owner` = entité **client** → `self.owner.components.warly_foodmemory` = **nil**
- `Ents` dans le contexte client = `ClientEnts` (entités client), PAS les entités serveur
- `GLOBAL.Ents` dans le widget = idem → `pairs(GLOBAL.Ents)` n'y trouve pas `warly_foodmemory`
- Il existe **deux** entités Warly : une de sélection (sans `eater`, sans composant) + une de monde (avec tout)
- `self.owner` pointe vers l'entité de sélection (sans composant)
- Les events SONT forwardés : `oneat` se déclenche sur l'entité client quand le serveur le fire

**Tentatives pour accéder aux données serveur :**
- `self.owner.components.warly_foodmemory` → nil
- `GLOBAL.Ents[self.owner.GUID]` → entité de sélection (sans composant)
- `pairs(GLOBAL.Ents)` → ne contient que les entités client
- `net_string` → tenté, résultat non confirmé

**État actuel :**
- Widget réinitialisé en version minimale (`Text("HUD OK")` rouge) pour valider la visibilité de base avant de reconstruire

### Leçons de debugging

- `Ents` depuis le contexte client = `ClientEnts`, pas les entités serveur — vérifiable avec `print(Ents[ThePlayer.GUID].components.warly_foodmemory)` en LOCAL console (→ nil)
- La seule façon d'accéder aux données serveur depuis un widget = `net_string` DST ou event custom
- Pour débugger un widget qui n'apparaît pas : commencer par un `Text` bright pour confirmer position/visibilité avant toute complexité

### Prochaine étape

**Phase 3 — Widget HUD (suite) :**
1. Tester `Text("HUD OK")` pour confirmer visibilité et position du widget
2. Si visible : reconstruire avec UIAnim + icônes
3. Implémenter synchronisation serveur→client (à déterminer : `net_string` ou event custom)

---

## Session 6 — 2026-06-28 (suite)

### Ce qui a été fait

**Phase 3 — Widget HUD complété :**

**8b — Synchronisation net_string :**
- `GLOBAL.net_string(...)` requis (comme `GLOBAL.GetString`) — non importé dans le sandbox mod
- Bug crash C++ : `net_string` créé DEUX FOIS sur la même entité côté client (`AddPrefabPostInit` s'exécute sur client ET serveur + `AddClassPostConstruct` crée le même net_string → `Assert failure: duplicate lua network variable`)
- Fix : placer la création du net_string **à l'intérieur** du guard `if inst.components.eater then` (composant serveur uniquement) — le client ne crée pas le net_string dans `AddPrefabPostInit`
- État initial envoyé via `DoStaticTaskInTime(0)` après `AddComponent` pour les saves chargées
- Validation : `[Warly HUD] queue mise à jour : meatballs,wetgoop,wetgoop,meatballs` visible en console

**8c — Affichage des slots :**
- `status_meter`/`bg` montrait un fond rouge (jauge "vide") → remplacé par `status_clear_bg`/`backing` (fond neutre)
- `status_meter`/`frame` donne le contour doré identique aux badges vanilla
- Ordre des layers : `bg → icône → frame` (frame ajouté en DERNIER pour passer au premier plan)
- Échelles finales : `SLOT_SCALE = 0.55`, `ICON_SCALE = 0.35`, `STEP = 26`

**Positionnement — compatibilité Combined Status :**
- `brain_pos.y` retourne une valeur différente avec Combined Status (badge reposé dans la ligne horizontale) → offset instable
- Fix : ancrer sur `heart_pos` au lieu de `brain_pos` : `SetPosition(heart_pos.x + 10, heart_pos.y - y_offset, 0)`
- Heart badge est repositionné de façon cohérente par Combined Status → l'offset absolu donne un résultat stable dans les deux configurations
- Résultat validé : vanilla / vanilla+wetness / Combined Status / Combined Status+wetness ✓

**Option mod — position verticale :**
- `GetModConfigData("hud_y_offset")` non accessible dans `DoStaticTaskInTime` (contexte différé)
- Fix : lire la valeur au niveau du callback `AddClassPostConstruct` et capturer dans une variable locale (closure)
- Ajouté `configuration_options` dans `modinfo.lua` : option dropdown 80/100/116/140/160/200, défaut 116

### Leçons de debugging

- `GLOBAL.net_string` requis dans le sandbox mod (comme toutes les fonctions engine non importées)
- `net_string` dupliqué → crash C++ `Assert failure 'BREAKPT:' at Entity.cpp` visible dans le **client log** (pas le server log)
- `GetModConfigData` doit être appelé au niveau du callback parent, pas dans un `DoStaticTaskInTime` différé
- `status_meter`/`bg` ≠ fond neutre — c'est la jauge vidée (rouge sombre). Utiliser `status_clear_bg`/`backing` pour un fond neutre
- Combined Status repositionne le badge brain → ne pas ancrer le HUD sur `brain_pos`

### Prochaine étape

**Phase 4** — Plats exclusifs (modification plats vanilla existants + création nouveaux plats)

---

## Session 7 — 2026-06-29

### Ce qui a été fait

**Restructuration du design (modifications utilisateur) :**
- "Trainee Warly" supprimé — remplacé par des options individuelles configurables
- CONTENT.md et TODOLIST mis à jour : option taille mémoire (default/fixe 2-3-4), option Chef Pouch au départ (OFF par défaut), plats combat sans restriction
- Option "toggle plats mangeables par tous" déplacée en Phase 4 (testée avec les plats)

**Étape 9 — Option mémoire alimentaire :**
- `modinfo.lua` : ajout option `memory_size` (Default 2→3→4 / Fixed 2 / Fixed 3 / Fixed 4)
- `modmain.lua` : `GLOBAL.WARLY_MEMORY_SIZE_OPTION = GetModConfigData("memory_size")` en top level — expose l'option au composant via l'env global du jeu
- `warly_foodmemory.lua` : `GetMemorySize()` lit `WARLY_MEMORY_SIZE_OPTION` en priorité, court-circuite le calcul dynamique si valeur fixe
- Widget `RefreshIcons()` : `mem_size_opt` capturé en closure au niveau `AddClassPostConstruct` (même pattern que `y_offset`)

**Correctif oublié Phase 1 — Sanité max 150 :**
- `AddPrefabPostInit("warly", ...)` : ajout `if inst.components.sanity then inst.components.sanity:SetMax(150) end`

### Leçons de debugging

- `TheWorld.state.cycles = X` est assignable directement pour tester `GetMemorySize()`, mais ne déclenche pas `cycleschanged` — le widget ne se rafraîchit pas
- Il n'existe pas de `c_skip` négatif dans DST

### Prochaine étape

**Phase 4** — Étape 10 : restriction "Warly uniquement" sur les plats exclusifs, puis modification des plats vanilla existants

---

## Session 8 — 2026-06-29 (suite)

### Ce qui a été fait

**Analyse du mécanisme vanilla de restriction des plats Warly :**
- Les plats Warly vanilla sont enregistrés uniquement sur `portablecookpot` (pas `cookpot`)
- Seul Warly peut déployer le portablecookpot (`restrictedtag = "masterchef"` dans `portablecookpot.lua`)
- `masterchef` est utilisé pour les speeches (wisecracker), pas pour un filtre de cuisson
- Notre mod veut les plats sur n'importe quel crock pot → restriction explicite nécessaire

**Étape 10 — Restriction Warly uniquement (mécanisme) :**
- `cooker` dans `test(cooker, names, tags)` est une **string** (nom du prefab), pas une entité → pas d'accès à la position
- Solution : hook sur `Stewer:StartCooking(doer)` via `AddComponentPostInit("stewer", ...)` pour capturer le joueur dans `GLOBAL.WARLY_CURRENT_CHEF` avant que `CalculateRecipe` soit appelé
- `strict.lua` interdit d'assigner à une variable globale non déclarée depuis une fonction Lua → pré-déclarer avec `GLOBAL.WARLY_CURRENT_CHEF = nil` au top-level de modmain.lua
- Wrapper `warly_only(test_fn)` : lit `GLOBAL.WARLY_CURRENT_CHEF`, vérifie le tag `masterchef`, puis délègue

**Étape 10 — Moqueca (premier plat) :**
- Recette définie avec `warly_only` + stats modifiées (hunger 112.5 → 90)
- `GLOBAL.FOODTYPE` requis (pas exposé directement dans le sandbox, contrairement à `TUNING`)
- `AddCookerRecipe` est une fonction mod API directe (sans `GLOBAL.`)
- Bug icone : `AddCookerRecipe` enregistre le plat dans `mod.cookerrecipes` → `IsModCookingProduct` retourne `true` → le jeu cherche un build `"moqueca"` inexistant → pas d'icone
- Fix icone : assignation directe dans `cooking.recipes["cookpot"]["moqueca"] = recipe` via `_require("cooking")` — bypass du tracking mod
- Bug stats : les stats du prefab viennent de la closure dans `preparedfoods.lua` (lit `preparedfoods_warly.lua` vanilla) → `AddCookerRecipe` ne change pas les stats du prefab
- Fix stats : `AddPrefabPostInit("moqueca", function(inst) inst.components.edible.hungervalue = 90 end)`

### Leçons de debugging

- `strict.lua` : `__newindex` autorise les assignations depuis un "main chunk" mais bloque depuis les fonctions Lua → pré-déclarer les globaux de runtime au top-level de modmain.lua
- `FOODTYPE` → `GLOBAL.FOODTYPE` ; `AddCookerRecipe` → direct (mod API) ; `TUNING` → direct
- `IsModCookingProduct` : tout plat passé par `AddCookerRecipe` depuis un mod est considéré "mod food" → build lookup cassé pour les plats vanilla → utiliser `cooking.recipes[cooker][name] = recipe` à la place
- Les stats d'un prefab de nourriture (`edible.hungervalue` etc.) viennent d'une closure dans `preparedfoods.lua`, pas de la table recipe → seul `AddPrefabPostInit` peut les modifier

### Prochaine étape

**Phase 4 — Étape 10 (suite)** : appliquer le même pattern aux 6 plats vanilla restants (monstertartare, glowberrymousse, bonesoup, nightmarepie, frogfishbowl, gazpacho)

---

## Session 9 — 2026-06-30

### Ce qui a été fait

**Étape 10 — Plats vanilla restants (6/7 terminés) :**

Code fourni et testé pour :
- `bonesoup` — warly_only, stats identiques vanilla (+32/+150/+5), recette inchangée
- `monstertartare` — warly_only, hunger 62.5 → 75 (via `AddPrefabPostInit`)
- `nightmarepie` (grim galette) — warly_only, recette changée (2 nightmare fuels + `tags.veggie >= 1` au lieu de potato+onion), HP 1 → 5 (via `AddPrefabPostInit`)
- `frogfishbowl` (fish cordon bleu) — warly_only, priorité augmentée à 35 (conflict surf'n turf priority 30), durée `buff_moistureimmunity` day_time → TOTAL_DAY_TIME
- `gazpacho` (asparagazpacho) — warly_only, `temperatureduration` → TOTAL_DAY_TIME (via `AddPrefabPostInit`)
- `voltgoatjelly` (volt goat chaud-froid) — déplacé de l'étape 11 vers l'étape 10 car c'est un plat vanilla modifié, warly_only, recette changée (lightninggoathorn + 1 sweetener + 1 frozen au lieu de horn + 2 sweeteners), sanité 10 → 5 (via `AddPrefabPostInit`), durée `buff_electricattack` → TOTAL_DAY_TIME, effet -10% damage given supprimé de la spec

Reste : `glowberrymousse` (délibérément mis de côté — cas le plus complexe, décroissance lumière custom)

**Bugs corrigés durant les tests :**

1. **Durée des buffs ne changeait pas** (frogfishbowl, voltgoatjelly) : l'`oneatenfn` dans la table `cooking.recipes` n'est jamais appelé. Fix : `AddPrefabPostInit` sur le prefab food, en wrappant `edible.oneaten` (pas `edible.oneatenfn` — piège critique, voir TECHNICAL.md).

2. **Priorité frogfishbowl** : conflict avec `surfnturf` (priority 30). Fix : priority 35 sur frogfishbowl.

3. **Gazpacho — effet température** : `temperature`/`temperatureduration` dans la table de recette n'affectent pas le prefab. Fix : `AddPrefabPostInit("gazpacho", ...)` pour écrire directement sur `edible.temperaturedelta` et `edible.temperatureduration`.

### Leçons de debugging critiques (voir TECHNICAL.md)

- `edible.oneaten` est le vrai champ (via `SetOnEatenFn`), pas `edible.oneatenfn` — écrire sur `oneatenfn` ne fait rien
- Durées buffs vanilla = `day_time` (~5 min, juste la phase de jour). "1 jour" dans la spec = `TUNING.TOTAL_DAY_TIME` (~8 min, cycle complet)
- `EntityScript:AddDebuff` retourne `true`/`false`, pas l'entité buff → utiliser `debuffable:GetDebuff(name)` pour récupérer l'entité et modifier son timer

### Prochaine étape

**Phase 4 — Étape 10 (fin)** : `glowberrymousse` (recette simplifiée + hunger 37.5→25 + décroissance lumière custom côté client)
