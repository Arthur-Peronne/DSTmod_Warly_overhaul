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

### Refus de manger : `PrefersToEat` vs `Eat`

**Ne pas** hooker `Eat()` pour refuser un aliment. `Eat()` est appelé **pendant** l'animation d'eat (depuis `ACTIONS.EAT.fn`) — à ce stade l'animation a déjà démarré et le son joue. Retourner nil depuis `Eat()` arrête la consommation mais laisse l'animation se terminer, puis déclenche ACTIONFAIL ("I cannot do that").

**Pattern correct** : hooker `PrefersToEat()`. SGwilson l'appelle dans son ActionHandler **avant** de décider quelle animation lancer :

```lua
-- SGwilson.lua ligne 1168
if not inst.components.eater:PrefersToEat(obj) then
    inst:PushEvent("wonteatfood", { food = obj })
    return  -- jamais d'animation d'eat
end
```

→ `PrefersToEat` retourne false → `wonteatfood` pushé → `GoToState("refuseeat")` → animation de refus correcte, pas de son, pas d'ACTIONFAIL.

Pour le speech de refus : écouter l'event `"wonteatfood"` avec un guard sur `GetMultiplier == 0` (pour ne parler que lors d'un refus mémoire, pas d'un refus diète).

### `GetString` et le sandbox mod

`GetString(inst, key1, key2)` est une fonction du moteur DST qui cherche les strings de personnage dans `STRINGS.CHARACTERS`. Elle n'est **pas importée automatiquement** dans le sandbox de `modmain.lua`.

→ Dans les closures de `modmain.lua` (callbacks `AddPrefabPostInit`, listeners `ListenForEvent`...), utiliser **`GLOBAL.GetString(...)`** et non `GetString(...)`.

Les tables globales simples comme `TUNING`, `STRINGS`, `FOODTYPE` sont accessibles directement. Les fonctions comme `GetString` nécessitent le préfixe `GLOBAL.`.

### `require("warly_config")` dans les composants custom

Quand DST charge un composant via `inst:AddComponent("warly_foodmemory")`, il exécute `scripts/components/warly_foodmemory.lua` dans l'**environnement global du jeu** (pas le sandbox mod). Un `require("warly_config")` dans ce fichier cherche `scripts/warly_config.lua` dans le dossier mod et l'exécute dans l'env global du jeu. `WARLY_CONFIG = { ... }` défini sans `local` devient alors un global jeu accessible depuis partout.

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

### 6. `scripts/components/wisecracker.lua`
- Composant qui gère **tous les dialogues automatiques** de Warly (et des autres personnages)
- Branche un listener `oneat` qui choisit le speech selon l'état du plat :
  - `foodmemory:GetMemoryCount(prefab) > 0` → `SAME_OLD_N` (N = count, min(5, count))
  - sinon + `masterchef` tag → `TASTY` (masterfood), `PREPARED`, `RAW`, `DRIED`, ou `COOKED`
- Si `foodmemory` est nil (composant supprimé), count vaut toujours 0 → Warly dit toujours TASTY/PREPARED, jamais SAME_OLD
- **Pattern proxy** : plutôt que supprimer `foodmemory`, patcher ses méthodes directement sur l'instance pour rediriger vers notre composant :
  ```lua
  inst.components.foodmemory.GetMemoryCount = function(self, prefab)
      return inst.components.warly_foodmemory:GetOccurrences(prefab)
  end
  inst.components.foodmemory.GetFoodMultiplier = function(self, prefab) return 1 end
  inst.components.foodmemory.RememberFood = function(self, prefab) end
  ```
- **Ordre des listeners `oneat`** : wisecracker s'enregistre pendant `master_postinit`, notre listener dans `AddPrefabPostInit` → notre listener fire **après** wisecracker → `talker:Say()` dans notre listener écrase naturellement le speech de wisecracker

### 7. `scripts/spicedfoods.lua`
- Contient les buffs du système d'assaisonnement réutilisables :
  - `buff_workeffectiveness` (sucre/honey crystals → Sweet smoothie)
  - `buff_attack` (chili → Spiky salad)
  - `buff_playerabsorption` (garlic → Roasted vegetables)
- Ces prefabs de buff sont autonomes, utilisables même après suppression du système de spices
