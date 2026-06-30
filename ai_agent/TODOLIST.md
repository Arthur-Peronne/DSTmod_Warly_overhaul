# TODO LIST — DST Mod Warly

## Phase 1 — Fondations

- [x] **1. Créer la structure du mod**
  - [x] `modinfo.lua`, `modmain.lua` minimal (print de debug), arborescence `scripts/components/` et `scripts/prefabs/`

- [x] **2. Patcher les stats de base de Warly**
  - [x] Hunger 200, supprimer hunger drain +20% — via `AddPrefabPostInit("warly", ...)` + `if inst.components.hunger then`
  - [x] Vider les items de départ vanilla (potatoes/garlic) — on remettra le crockpot à l'étape 13

- [x] **3. Supprimer les mécaniques vanilla**
  - [x] Retirer les recettes de spiced foods et les items (grindingmill, seasoningstation) de la liste Warly — via `GLOBAL.AllRecipes` (recettes : `portablespicer_item`, `portableblender_item`, `spicepack`)
  - [x] Supprimer le fast fire-cooking de Warly — via `RemoveTag("expertchef")` dans `AddPrefabPostInit`

---

## Phase 2 — Mémoire alimentaire FIFO

- [x] **4. `scripts/warly_config.lua`**
  - [x] Constantes : seuils jours (35, 70), valeurs N (2/3/4), malus (0.25 par occurrence)
  - [x] Liste des plats exclusifs (pour le bonus +15 faim plus tard)

- [x] **5. `scripts/components/warly_foodmemory.lua`**
  - [x] Queue FIFO de taille N, `RememberFood`, `GetOccurrences`, `GetMultiplier`
  - [x] N dynamique selon `TheWorld.state.cycles`
  - [x] `OnSave` / `OnLoad`

- [x] **6. Branchement sur Warly**
  - [x] `AddPrefabPostInit("warly", ...)` : patcher `foodmemory` vanilla en proxy (GetFoodMultiplier → 1, GetMemoryCount → notre queue, RememberFood → no-op)
  - [x] Brancher le multiplier via `eater.custom_stats_mod_fn`
  - [x] Speeches liés aux occurrences : override des SAME_OLD via `oneat` listener (SAME_OLD_1/2/4/5 → mult 0.75/0.5/0.25/0.0) — `GLOBAL.GetString` requis dans le sandbox mod

- [x] **7. Hook sur `Eater:Eat` au niveau instance**
  - [x] Si `GetMultiplier == 0` : retourner false sans consommer + message de refus
  - [x] Override `PrefersToEat` (pas `Eat`) + listener `wonteatfood` pour le speech SAME_OLD_5

- [ ] **7bis. Option: modification des multiplicateurs par l'utilisateur du mod**
  - [ ] Creer les options dans modinfo.lua
  - [ ] Brancher les options dans le code


---

## Phase 3 — Affichage HUD mémoire

- [x] **8. Widget HUD sous la jauge de faim**

  **8a. Valider la visibilité de base**
  - [x] Widget minimaliste : `Text("HUD OK")` rouge dans `AddClassPostConstruct` pour confirmer position + exécution du callback
  - [x] Vérifier que le widget apparaît bien sous le badge santé

  **8b. Sync serveur → client (données de la queue)**
  - [x] `net_string` côté serveur **à l'intérieur** du guard `if inst.components.eater` (GLOBAL.net_string requis)
  - [x] Mise à jour après chaque `RememberFood` dans `oneat`
  - [x] Envoi état initial via `DoStaticTaskInTime(0)` après `AddComponent`
  - [x] Receiver côté client dans le widget (`GLOBAL.net_string`)
  - [x] Validé : queue reçue correctement après chaque repas

  **8c. Affichage des slots**
  - [x] N slots avec fond `status_clear_bg`/`backing` + contour `status_meter`/`frame` + icône `Image`
  - [x] Rafraîchir sur `warlymemqueueupdate` (déféré `DoStaticTaskInTime`)
  - [x] Rafraîchir sur `cycleschanged`
  - [x] Cacher en mode fantôme (`SetGhostMode`)
  - [x] Compatibilité Combined Status : ancrage sur `heart_pos` avec offset fixe

  **8d. Option mod**
  - [x] Option position verticale HUD (`hud_y_offset`) dans `modinfo.lua` — dropdown 80→200, défaut 116
  - [x] Option ON/OFF dans `modinfo.lua` pour afficher/cacher le widget entièrement

- [x] **9. Option mémoire alimentaire**
  - [x] N= default (2,3 ou 4 selon avancement du jeu), ou 2,3 ou 4 fixe
---

## Phase 4 — Plats exclusifs

- [ ] **10. Modifier les plats vanilla existants** (via override dans modmain)
  - [x] Implémenter la restriction "cuisinables par Warly uniquement" sur tous les plats exclusifs (tâches 9 et 10)
  - [x] `moqueca` — ajuster recette et stats
  - [x] `monstertartare` — hunger 62.5 → 75 (via `AddPrefabPostInit`)
  - [ ] `glowberrymousse` — ajuster ingrédients (1 glowberry value + 1 fruit value), garder le `SpawnPrefab("wormlight_light_greater")` vanilla
    - Décroissance lumière custom : 0–90% durée → rayon constant 100%, 90–100% durée → décroissance linéaire 100%→0%
    - Implémentation : `AddPrefabPostInit("wormlight_light_fx_greater", ...)` côté client (le rayon est géré client-side dans `OnUpdateLight`)
  - [x] `bonesoup` → bone bouillon — stats identiques vanilla, warly_only + cookpot
  - [x] `nightmarepie` → grim galette — recette : 2 nightmare fuels + `tags.veggie >= 1` (plus de potato/onion requis), HP 1 → 5 (via `AddPrefabPostInit`)
  - [x] `frogfishbowl` → fish cordon bleu — priority 35 (> surfnturf 30), durée `buff_moistureimmunity` day_time → TOTAL_DAY_TIME (via `AddPrefabPostInit` + `edible.oneaten` wrapper + `debuffable:GetDebuff` + `timer:SetTimeLeft`)
  - [x] `gazpacho` → asparagazpacho — `edible.temperatureduration` → TOTAL_DAY_TIME (via `AddPrefabPostInit`)
  - [x] `voltgoatjelly` → volt goat chaud-froid — recette : horn + 1 sweetener + 1 frozen, sanité 10 → 5, durée `buff_electricattack` → TOTAL_DAY_TIME (même pattern que frogfishbowl)

- [ ] **11. Créer les plats vraiment nouveaux** (patterns vanilla réutilisés)
  - [ ] `salted caramel crepes` — feeding, base `freshfruitcrepes` modifiée, icône `freshfruitcrepes` 
  - [ ] `scary parmentier` — feeding, base `potatosouffle` modifiée, icône `potatosouffle`
  - [ ] `spicy burger` — `temperature = HOT_FOOD_BONUS_TEMP` (pattern `dragonchilisalad`), icône "Steamed ham sandwich" (TO BE GIVEN)
  - [ ] `sweet smoothie` — `AddDebuff("buff_workeffectiveness")` (pattern spice sucre/honey crystals), icône "Iced Tea" (TO BE GIVEN)
  - [ ] `salted cod soup` — `AddDebuff` speed (à vérifier le prefab vanilla disponible), icône "Tropical bouillabaisse" (TO BE GIVEN)
  - [ ] `spiky purée` — `AddDebuff("buff_attack")` (pattern spice chili), icône "Ceviche" (TO BE GIVEN)
  - [ ] `roasted vegetables` — `AddDebuff("buff_playerabsorption")` (pattern spice garlic), icône "Feijoada" (TO BE GIVEN)

- [ ] **12. Bonus Warly sur ses plats exclusifs**
  - [ ] +15 faim : via `custom_stats_mod_fn` si le plat est dans la liste config
  - [ ] x1.5 durée des effets : via `AddPrefabPostInit` sur chaque plat — wrapper `edible.oneaten` (pas `oneatenfn` !) → `debuffable:GetDebuff(name)` → `timer:SetTimeLeft("buffover", duration * 1.5)` (pattern établi en étape 10 pour frogfishbowl et voltgoatjelly)

- [ ] **13. Toggle plats mangeables par tous**
  - [ ] Retirer la restriction Wigfrid/Wurt sur les plats Veggie/Meat
---

## Phase 5 — Items spéciaux

- [ ] **14. Chef Pouch**
  - [ ] Container 8 slots, spoilage x0.6, équipable uniquement par Warly
  - [ ] Option Chef Pouch en objet de départ

- [ ] **15. Portable Crock Pot**
  - [ ] Vérifier ce que vanilla fournit déjà (`portablecookpot_item`)
  - [ ] Ajuster coût (3 marbles / 6 coals / 6 twigs) et cook duration (60%)
  - [ ] Remettre dans les items de départ (remplace la liste vide de l'étape 2)

---

## Phase 6 — Dialogues de Warly

- [ ] **16. Modifier les phrases de Warly**
  - [x] ~~Phrases sur les plats vanilla~~ (SAME_OLD liés aux occurrences — fait en Phase 2)
  - [ ] Phrases sur les plats exclusifs (speech positif à la première dégustation)
  - [ ] Phrases sur les plats refusés (message spécifique au refus dur — Phase 2 étape 7)
  - [ ] Phrases sur les objets (Portable Crock Pot, Chef Pouch)
  - [ ] Phrases sur les situations / faim (faim critique)
