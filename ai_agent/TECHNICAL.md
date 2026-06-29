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

---

## Séparation client/serveur DST — critique pour les widgets HUD

### Contexte général

En jeu DST (solo ou listen server), il y a **deux contextes Lua distincts** : serveur et client. Les mods s'exécutent dans les deux, mais les données ne sont pas automatiquement partagées.

### `AddClassPostConstruct` et les widgets

- `AddClassPostConstruct("widgets/statusdisplays", fn)` s'exécute dans le contexte **client**
- `self.owner` dans le widget = entité **client** de Warly
- L'entité client a les **replica components** (`health`, `hunger`, `sanity` via `.replica`) mais **PAS** les composants serveur (`eater`, `warly_foodmemory`...)
- `self.owner.components.warly_foodmemory` = **nil** depuis un widget

### `Ents` depuis le contexte client

- `Ents` en console LOCAL (client) = `ClientEnts` (entités client, PAS serveur)
- `GLOBAL.Ents` dans `AddClassPostConstruct` = idem
- `pairs(GLOBAL.Ents)` n'itère que les entités client → ne trouvera jamais `warly_foodmemory`

### Les deux entités Warly

Il existe **deux** entités Warly dans le jeu :

1. **Entité de sélection** : créée à l'écran de sélection, avant `TheWorld`. `inst.components.eater` est nil → guard `if inst.components.eater then` empêche d'ajouter `warly_foodmemory`. C'est cette entité que `self.owner.GUID` pointe côté client.
2. **Entité de monde** : créée à l'entrée dans le monde, avec `eater` et `warly_foodmemory`. C'est celle que `ThePlayer` en console REMOTE retourne.

**Diagnostic** :
```lua
-- LOCAL console (entité sélection, sans composant) :
print(Ents[ThePlayer.GUID].components.warly_foodmemory)  -- nil

-- REMOTE console (entité monde, avec composant) :
c_announce(tostring(ThePlayer.components.warly_foodmemory))  -- table: 0x...
```

### Events forwardés client ↔ serveur

Les events DST sont forwardés du serveur vers le client. Quand `Eater:Eat()` fire `oneat` sur l'entité serveur, l'entité client reçoit aussi l'event → `ListenForEvent("oneat", fn, self.owner)` se déclenche dans le widget.

**Danger** : ne jamais exécuter d'opérations widget (`KillAllChildren`, création de widgets...) directement dans un listener `oneat`. Cela s'exécute dans la pile de `Eater:Eat()` côté serveur → crash → déconnexion.

**Pattern correct** : toujours déférer avec `DoStaticTaskInTime` :
```lua
self.inst:ListenForEvent("oneat", function()
    self.inst:DoStaticTaskInTime(0, function()
        RefreshIcons()
    end)
end, self.owner)
```

### Synchroniser données serveur → widget client

Solution DST-standard : **`net_string`**.

```lua
-- Serveur (AddPrefabPostInit) :
inst._warly_mem_str = net_string(inst.GUID, "warly_mem_queue", "warlymemqueueupdate")
inst._warly_mem_str:set(table.concat(queue, ","))  -- après chaque RememberFood

-- Client (AddClassPostConstruct) :
local mem_net = net_string(self.owner.GUID, "warly_mem_queue", "warlymemqueueupdate")
local encoded = mem_net:value()  -- lire la valeur synchro
self.inst:ListenForEvent("warlymemqueueupdate", fn, self.owner)  -- écouter les updates
```

### `net_string` — variable réseau serveur → client

`net_string(guid, name, dirty_event)` crée une variable réseau synchronisée automatiquement du serveur vers le client. Elle doit être créée dans les deux contextes (serveur ET client) avec le même GUID et le même nom.

**Règles critiques :**

1. **`GLOBAL.net_string(...)` requis** dans le sandbox mod (comme `GLOBAL.GetString`) — `net_string` n'est pas importé automatiquement.

2. **Ne pas créer le net_string en dehors du guard `eater`** dans `AddPrefabPostInit`. Ce callback s'exécute sur le client ET le serveur. Si le net_string est créé avant le guard, il est enregistré côté client dans `AddPrefabPostInit` ET dans `AddClassPostConstruct` → crash C++ :
   ```
   Registering duplicate lua network variable XXXXXXXX in entity warly[GUID]
   Assert failure 'BREAKPT:' at Entity.cpp
   ```
   Ce crash est visible dans le **client log**, pas le server log.

   **Fix** : placer `inst._warly_mem_str = GLOBAL.net_string(...)` à l'intérieur du `if inst.components.eater then` — `eater` est un composant serveur uniquement, donc le net_string n'est créé côté serveur qu'une fois.

3. **Envoyer l'état initial** via `DoStaticTaskInTime(0)` après `AddComponent` pour les saves chargées (`OnLoad` a déjà peuplé la queue).

4. **Pattern complet** :
   ```lua
   -- Serveur (dans le guard eater) :
   inst._warly_mem_str = GLOBAL.net_string(inst.GUID, "warly_mem_queue", "warlymemqueueupdate")
   inst:DoStaticTaskInTime(0, function()
       inst._warly_mem_str:set(table.concat(inst.components.warly_foodmemory.queue, ","))
   end)
   -- Dans oneat, après RememberFood :
   inst._warly_mem_str:set(table.concat(i.components.warly_foodmemory.queue, ","))

   -- Client (dans AddClassPostConstruct) :
   local mem_net = GLOBAL.net_string(self.owner.GUID, "warly_mem_queue", "warlymemqueueupdate")
   -- Lire : mem_net:value() → "meatballs,wetgoop,..."
   -- Écouter : ListenForEvent("warlymemqueueupdate", fn, self.owner)
   ```

### `GetModConfigData` dans les callbacks différés

`GetModConfigData("option_name")` n'est **pas accessible** à l'intérieur d'un `DoStaticTaskInTime` ou d'un `ListenForEvent` — retourne `nil` dans ces contextes.

**Pattern correct** : lire la valeur au niveau du callback parent et capturer dans une variable locale :
```lua
AddClassPostConstruct("widgets/statusdisplays", function(self)
    local y_offset = GetModConfigData("hud_y_offset") or 116  -- ← ici

    self.inst:DoStaticTaskInTime(0, function()
        -- y_offset est accessible ici via closure
        self.warly_memory:SetPosition(x, heart_pos.y - y_offset, 0)
    end)
end)
```

### Assets UIAnim pour les badges de style DST

Le widget `Badge` vanilla (`scripts/widgets/badge.lua`) utilise :

| Couche        | Bank           | Build          | Animation |
|---------------|----------------|----------------|-----------|
| Fond neutre   | `status_clear_bg` | `status_clear_bg` | `backing` |
| Fond jauge    | `status_meter` | `status_meter` | `bg`      |
| Contour doré  | `status_meter` | `status_meter` | `frame`   |
| Jauge fill    | `status_meter` | `status_meter` | `anim`    |

**Attention** : `status_meter`/`bg` n'est PAS un fond neutre — c'est l'animation de jauge vide, qui affiche un rouge sombre par défaut. Pour un fond neutre, utiliser `status_clear_bg`/`backing`.

**Ordre des layers** (important) : le dernier enfant ajouté est rendu au premier plan. Pour que le contour soit visible par-dessus l'icône :
```lua
slot:AddChild(bg)    -- fond derrière
slot:AddChild(icon)  -- icône au milieu
slot:AddChild(frame) -- contour doré devant
```

### Positionnement HUD avec Combined Status

Combined Status repositionne les badges (`self.heart`, `self.brain`, `self.stomach`) dans le repère local de `statusdisplays`. Les positions de TECHNICAL.md ("brain inchangé") sont incorrectes — Combined Status déplace le brain badge dans sa ligne horizontale.

**Conséquence** : ancrer le widget sur `brain_pos.y` donne un résultat instable selon la configuration Combined Status.

**Pattern robuste** : ancrer sur `heart_pos` uniquement, avec un offset fixe :
```lua
self.inst:DoStaticTaskInTime(0, function()
    local heart_pos = self.heart:GetPosition()
    self.warly_memory:SetPosition(heart_pos.x + 10, heart_pos.y - y_offset, 0)
end)
```
Le badge santé est repositionné de façon cohérente par Combined Status (il suit toujours le bord droit des badges), ce qui donne un résultat visuellement stable dans les deux configurations.

### Méthode de debug : widget invisible

Toujours commencer par un élément évident avant d'ajouter de la complexité :

```lua
local Text = _require("widgets/text")
local label = container:AddChild(Text(GLOBAL.DEFAULTFONT, 20, "HUD OK"))
label:SetColour(1, 0, 0, 1)  -- rouge vif
```

Si le texte n'apparaît pas → problème de positionnement ou d'exécution du callback.
Si le texte apparaît → la base fonctionne, on peut ajouter UIAnim, Image, data.

### Positions de référence dans `statusdisplays`

| Badge | Vanilla (x, y) | Combined Status (x, y) |
|-------|---------------|------------------------|
| `self.stomach` (faim) | (-40, 20) | (-62, 35) |
| `self.brain` (sanité) | (0, -40) | inchangé |
| `self.heart` (santé) | (40, 20) | (62, 35) |
| `self.moisturemeter` | (0, -115) | inchangé |

Pour positionner sous le badge santé sans déborder à droite : `(pos.x, pos.y - 50)` est un bon point de départ.

---

## Leçons apprises en Phase 4 (plats exclusifs)

### Restriction "Warly uniquement" via le stewer

Le paramètre `cooker` dans `test(cooker, names, tags)` est une **string** (nom du prefab du crock pot, ex : `"cookpot"`), pas l'entité. Il est impossible d'appeler des méthodes dessus.

Source : `stewer.lua` ligne 147 :
```lua
self.product, cooktime = cooking.CalculateRecipe(self.inst.prefab, self.ingredient_prefabs)
```

**Pattern correct** : hook sur `Stewer:StartCooking(doer)` pour capturer le joueur dans un global avant que `CalculateRecipe` soit appelé :

```lua
-- Pré-déclarer au top-level (strict.lua interdit l'assignation depuis une fn Lua)
GLOBAL.WARLY_CURRENT_CHEF = nil

AddComponentPostInit("stewer", function(self)
    local orig = self.StartCooking
    self.StartCooking = function(stewer, doer, ...)
        GLOBAL.WARLY_CURRENT_CHEF = doer
        orig(stewer, doer, ...)
        GLOBAL.WARLY_CURRENT_CHEF = nil
    end
end)

local function warly_only(test_fn)
    return function(cooker, names, tags)
        local chef = GLOBAL.WARLY_CURRENT_CHEF
        if chef == nil or not chef:HasTag("masterchef") then return false end
        return test_fn(cooker, names, tags)
    end
end
```

### `strict.lua` — assignation de globaux depuis les fonctions Lua

`strict.lua` autorise l'assignation à des globaux non déclarés uniquement depuis un **main chunk** (`debug.getinfo(2,"S").what == "main"`). Depuis une fonction Lua (`"Lua"`), l'assignation à un global non déclaré lève une erreur.

**Règle** : tout global écrit à runtime depuis une fonction doit être pré-déclaré au top-level de modmain.lua :
```lua
GLOBAL.WARLY_CURRENT_CHEF = nil   -- top-level = OK
-- plus tard dans une fonction :
GLOBAL.WARLY_CURRENT_CHEF = doer  -- OK car déclaré
```

### Globals exposés dans le sandbox mod (Phase 4)

| Accès | Exemples |
|-------|---------|
| Direct (mod API) | `AddCookerRecipe`, `AddPrefabPostInit`, `AddComponentPostInit` |
| Via `GLOBAL.` | `FOODTYPE`, `net_string`, `GetString` |
| Direct (tables) | `TUNING`, `STRINGS`, `AllRecipes` |

### Enregistrement de recettes sur le crock pot — bypass du tracking mod

`AddCookerRecipe(cooker, recipe)` enregistre le plat dans `mod.cookerrecipes`. Ensuite, `IsModCookingProduct` retourne `true`, et `SetProductSymbol` (dans `portablecookpot.lua`) cherche un build animé nommé d'après le plat plutôt que `"cook_pot_food"` → icone manquante pour les plats vanilla.

**Pattern correct** pour modifier ou ajouter une recette vanilla sans casser l'icone :
```lua
local cooking = _require("cooking")
cooking.recipes["cookpot"] = cooking.recipes["cookpot"] or {}
cooking.recipes["cookpot"]["moqueca"] = recipe       -- nouveau
cooking.recipes["portablecookpot"]["moqueca"] = recipe  -- remplacement vanilla
```

`_require("cooking")` retourne le module en cache. L'assignation directe bypass le tracking mod → `IsModCookingProduct` retourne `false` → build `"cook_pot_food"` → icone correcte.

### Stats des prefabs de nourriture — `AddPrefabPostInit` obligatoire

Les stats (`health`, `hunger`, `sanity`) des plats crock pot sont définies dans une **closure** générée par `MakePreparedFood(data)` dans `prefabs/preparedfoods.lua` :

```lua
-- preparedfoods.lua
for k, v in pairs(require("preparedfoods_warly")) do
    table.insert(prefs, MakePreparedFood(v))  -- closure capture v.hunger, v.health...
end
```

`require("preparedfoods_warly")` lit le fichier **vanilla** directement. Modifier la table recipe via `cooking.recipes` ne change pas les stats du prefab.

**Pattern correct** pour modifier les stats d'un plat vanilla :
```lua
AddPrefabPostInit("moqueca", function(inst)
    if inst.components.edible then
        inst.components.edible.hungervalue = 90
        -- inst.components.edible.healthvalue = X
        -- inst.components.edible.sanityvalue = X
    end
end)
```
