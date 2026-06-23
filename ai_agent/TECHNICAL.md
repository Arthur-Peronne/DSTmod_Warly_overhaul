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

## Leçons apprises en Phase 1 (debugging)

### Timing de `AddPrefabPostInit`

`AddPrefabPostInit("warly", fn)` est appelé dès la **sélection du personnage**, avant que `TheWorld` existe. Ce n'est pas un bug — c'est le comportement normal de DST.

**Conséquence critique :** le callback ne se déclenche qu'une seule fois à la création de l'entité. Si on retourne trop tôt (guard `if not TheWorld then return end`), le code ne s'exécutera jamais, même en jeu.

**Pattern correct :**
```lua
AddPrefabPostInit("warly", function(inst)
    -- Sans guard : fonctionne même sans TheWorld
    inst.starting_inventory = {}
    inst:RemoveTag("expertchef")
    inst:RemoveTag("professionalchef")

    -- Avec guard component (composants server-side seulement)
    if inst.components.hunger then
        inst.components.hunger:SetMax(200)
        inst.components.hunger:SetRate(TUNING.WILSON_HUNGER_RATE)
    end
end)
```

### `AddComponentPostInit` vs `AddPrefabPostInit` pour les stats

`AddComponentPostInit("hunger", fn)` se déclenche quand le composant est **créé** (pendant l'exécution de `warly.lua`). Le reste de `warly.lua` continue ensuite et peut **écraser** les valeurs définies dans le ComponentPostInit.

→ Pour modifier `hunger:SetMax()` : utiliser **`AddPrefabPostInit`**, qui s'exécute après toute l'initialisation vanilla.  
→ `AddComponentPostInit` est utile uniquement si la valeur n'est pas réécrite par le prefab ensuite.

### `starting_inventory` et `RemoveTag` sans `TheWorld`

Ces deux opérations ne nécessitent pas `TheWorld` — elles modifient directement la table Lua de l'entité. Elles peuvent (et doivent) être appelées sans guard.

### Accès aux recettes depuis `modmain.lua`

- `GetValidRecipe()` **n'existe pas** dans l'environnement mod → crash
- Accès correct : `GLOBAL.AllRecipes["nom_de_la_recette"]`
- Les recettes sont chargées avant les mods → `AllRecipes` est bien peuplé

**Recettes spices à désactiver (masterchef) :**
```lua
-- portablecookpot_item = à garder !
"portablespicer_item"   -- spice grinder
"portableblender_item"  -- blender (attention : _item, pas portableblender)
"spicepack"             -- sac à dos pour épices
```

### Debug console en jeu

| Mode | `ThePlayer` | Composants | Output `print()` |
|------|------------|-----------|-----------------|
| LOCAL | Entité client | Pas de composants gameplay (hunger = nil) | Affiché à l'écran |
| REMOTE | Entité serveur | Composants disponibles | Va dans le server log |

→ En REMOTE, utiliser **`c_announce(tostring(val))`** pour voir le résultat à l'écran.  
→ Tags visibles en LOCAL ≠ tags serveur — toujours vérifier en REMOTE pour le gameplay.

### Symlinks DST sur Linux

DST sur Linux **ne suit pas les symlinks** pour les mods. Solution : copie directe avec `rsync`.

```bash
# Alias dans ~/.bashrc
alias sync-warly='rsync -av --exclude=".*" --exclude=".git" --exclude=".gitignore" \
  --exclude="Ressources" --exclude="ai_agent" --exclude="CLAUDE.md" \
  /home/arthur/Code/DSTmod_Warly/ \
  "/home/arthur/.steam/steam/steamapps/common/Don'\''t Starve Together/mods/WARLY_Overhaul/"'
```

Workflow : modifier le code → `sync-warly` → recharger le monde (`Ctrl+L` ou relance).

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

### 5. `scripts/prefabs/spicepack.lua`
- Sac à dos craftable de Warly pour transporter ses épices (slot BODY, container 2×3)
- Tag `foodpreserver` — ralentit la dégradation alimentaire
- Build `swap_chefpack` — même visuel que notre futur Chef Pouch
- → Ce prefab est la base à étudier pour implémenter le Chef Pouch (tâche 12)

### 6. `scripts/spicedfoods.lua`
- Contient les buffs du système d'assaisonnement réutilisables :
  - `buff_workeffectiveness` (sucre/honey crystals → Sweet smoothie)
  - `buff_attack` (chili → Spiky salad)
  - `buff_playerabsorption` (garlic → Roasted vegetables)
- Ces prefabs de buff sont autonomes, utilisables même après suppression du système de spices
