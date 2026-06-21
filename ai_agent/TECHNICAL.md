# Warly Mod — Référence technique

## Architecture prévue

```
modmain.lua                          ← point d'entrée
scripts/
  warly_config.lua                   ← constantes (N par seuil, malus, listes de plats)
  components/
    warly_foodmemory.lua             ← nouveau composant (remplace foodmemory pour Warly)
  prefabs/
    warly_dishes.lua                 ← 15 plats exclusifs
    warly_portablecrockpot.lua       ← portable crock pot modifié
    warly_chefpouch.lua              ← chef pouch
```

**Principe :** ne pas modifier les composants vanilla (`foodmemory.lua`, `eater.lua`) — créer des composants propres pour Warly et hooker les comportements existants.

---

## Analyse du code source DST

### 1. `scripts/components/foodmemory.lua`
- Système basé sur des timers (dict par prefab, expire après `WARLY_SAME_OLD_COOLDOWN` = 2 jours)
- Multiplicateurs vanilla : `{0.9, 0.8, 0.65, 0.5, 0.3}` — jamais 0, pas de refus réel
- → À remplacer entièrement par la queue FIFO

### 2. `scripts/components/eater.lua`
- Le multiplicateur foodmemory est appliqué aux 3 stats dans `Eater:Eat()`
- Hook utile : `eater.custom_stats_mod_fn(inst, hp, hunger, sanity, food, feeder)`
- Pas de logique de refus en vanilla → à implémenter via patch de `Eat()` sur l'instance

### 3. `scripts/prefabs/warly.lua`
- Seulement 45 lignes. Utilise `SetPrefersEatingTag("preparedfood")` pour la restriction crock pot
- Hunger vanilla = 250 (pas 200), hunger rate +20% (`WARLY_HUNGER_RATE_MODIFIER = 1.2`)

### 4. `scripts/preparedfoods_warly.lua`
- Plusieurs de nos 15 plats existent déjà : `moqueca`, `monstertartare`, `glowberrymousse`, `bonesoup` (→ bone bouillon), `nightmarepie` (→ grim galette), `frogfishbowl` (→ fish cordon bleu), `gazpacho` (→ asparagazpacho) → à modifier, pas à recréer
- Patterns de buffs déjà en place : `AddDebuff("buff_electricattack")`, `AddDebuff("buff_moistureimmunity")`, `SpawnPrefab("wormlight_light_greater")`, swap HP↔Sanité via `DoDelta`, champs `temperature` / `temperatureduration`

### 5. `scripts/spicedfoods.lua`
- Contient les buffs du système d'assaisonnement réutilisables :
  - `buff_workeffectiveness` (sucre/honey crystals → Sweet smoothie)
  - `buff_attack` (chili → Spiky salad)
  - `buff_playerabsorption` (garlic → Roasted vegetables)
- Ces prefabs de buff sont autonomes, utilisables même après suppression du système de spices
