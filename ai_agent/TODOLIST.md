# TODO LIST — DST Mod Warly

## Phase 1 — Fondations

- [ ] **1. Créer la structure du mod**
  - [ ] `modinfo.lua`, `modmain.lua` minimal (print de debug), arborescence `scripts/components/` et `scripts/prefabs/`

- [ ] **2. Patcher les stats de base de Warly**
  - [ ] Hunger 200, supprimer hunger drain +20% — via `AddPrefabPostInit("warly", ...)`
  - [ ] Vider les items de départ vanilla (potatoes/garlic) — on les remettra à l'étape 13

- [ ] **3. Supprimer les mécaniques vanilla**
  - [ ] Retirer les recettes de spiced foods et les items (grindingmill, seasoningstation) de la liste Warly
  - [ ] Supprimer le fast fire-cooking de Warly

---

## Phase 2 — Mémoire alimentaire FIFO

- [ ] **4. `scripts/warly_config.lua`**
  - [ ] Constantes : seuils jours (35, 70), valeurs N (2/3/4), malus (0.25 par occurrence)
  - [ ] Liste des plats exclusifs (pour le bonus +15 faim plus tard)

- [ ] **5. `scripts/components/warly_foodmemory.lua`**
  - [ ] Queue FIFO de taille N, `RememberFood`, `GetOccurrences`, `GetMultiplier`
  - [ ] N dynamique selon `TheWorld.state.cycles`
  - [ ] `OnSave` / `OnLoad`

- [ ] **6. Branchement sur Warly**
  - [ ] `AddPrefabPostInit("warly", ...)` : remplacer le composant `foodmemory` vanilla par le nôtre
  - [ ] Brancher le multiplier via `eater.custom_stats_mod_fn`

---

## Phase 3 — Affichage HUD mémoire

- [ ] **7. Widget HUD sous la jauge de faim**
  - [ ] Affiche les N derniers repas (icônes ou noms) avec le multiplicateur résultant
  - [ ] Option ON/OFF dans les paramètres du mod (configurable dans `modinfo.lua`)

  > À mettre ici car c'est le principal outil de debug visuel de la mémoire — on en aura besoin pour valider toute la suite.

---

## Phase 4 — Refus de manger

- [ ] **8. Hook sur `Eater:Eat` au niveau instance**
  - [ ] Si `GetMultiplier == 0` : retourner false sans consommer + message de refus

---

## Phase 5 — Plats exclusifs

- [ ] **9. Modifier les plats vanilla existants** (via override dans modmain)
  - [ ] Implémenter la restriction "cuisinables par Warly uniquement" sur tous les plats exclusifs (tâches 9 et 10)
  - [ ] `moqueca` — ajuster recette et stats
  - [ ] `monstertartare` — ajuster stats (-20 HP / +75 faim / -20 sanity)
  - [ ] `glowberrymousse` — ajuster ingrédients (1 glowberry value + 1 fruit value), garder le `SpawnPrefab("wormlight_light_greater")` vanilla
  - [ ] `bonesoup` → bone bouillon — ajuster stats (+32 HP / +150 faim / +5 sanity)
  - [ ] `nightmarepie` → grim galette — changer ingrédients (2 nightmare fuels + 1 vegetable value), garder l'`oneatenfn` de swap HP↔Sanité
  - [ ] `frogfishbowl` → fish cordon bleu — garder `AddDebuff("buff_moistureimmunity")`, ajuster stats
  - [ ] `gazpacho` → asparagazpacho — garder les champs `temperature`/`temperatureduration`, ajuster recette

- [ ] **10. Créer les plats vraiment nouveaux** (patterns vanilla réutilisés)
  - [ ] `salted caramel crepes` — feeding, base `freshfruitcrepes` modifiée
  - [ ] `scary parmentier` — feeding, base `potatosouffle` modifiée
  - [ ] `spicy burger` — `temperature = HOT_FOOD_BONUS_TEMP` (pattern `dragonchilisalad`)
  - [ ] `sweet smoothie` — `AddDebuff("buff_workeffectiveness")` (pattern spice sucre/honey crystals)
  - [ ] `salted cod soup` — `AddDebuff` speed (à vérifier le prefab vanilla disponible)
  - [ ] `spiky salad` — `AddDebuff("buff_attack")` (pattern spice chili)
  - [ ] `roasted vegetables` — `AddDebuff("buff_playerabsorption")` (pattern spice garlic)
  - [ ] `volt goat chaud-froid` — `AddDebuff("buff_electricattack")` (pattern `voltgoatjelly`)

- [ ] **11. Bonus Warly sur ses plats exclusifs**
  - [ ] +15 faim : via `custom_stats_mod_fn` si le plat est dans la liste config
  - [ ] x1.5 durée des effets : intercepter `AddDebuff` pour allonger la durée, ou patcher le buff prefab à la volée au moment de l'`oneatenfn`

---

## Phase 6 — Items spéciaux

- [ ] **12. Chef Pouch**
  - [ ] Container 8 slots, spoilage x0.6, équipable uniquement par Warly

- [ ] **13. Portable Crock Pot**
  - [ ] Vérifier ce que vanilla fournit déjà (`portablecookpot_item`)
  - [ ] Ajuster coût (3 marbles / 6 coals / 6 twigs) et cook duration (60%)
  - [ ] Remettre dans les items de départ (remplace la liste vide de l'étape 2)

---

## Phase 7 — Options du mod

- [ ] **14. Trainee Warly**
  - [ ] N=2 fixe, Chef Pouch en départ, bloquer les 3 plats combat

- [ ] **15. Toggle plats mangeables par tous**
  - [ ] Retirer la restriction Wigfrid/Wurt sur les plats Veggie/Meat

---

## Phase 8 — Dialogues de Warly

- [ ] **16. Modifier les phrases de Warly**
  - [ ] Phrases sur les plats (plats exclusifs, plats vanilla, plats refusés)
  - [ ] Phrases sur les objets (Portable Crock Pot, Chef Pouch)
  - [ ] Phrases sur les situations / faim (mémoire alimentaire, refus de manger, faim critique)
