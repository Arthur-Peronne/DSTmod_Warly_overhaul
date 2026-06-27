# Warly Mod — Procédure de debug

## 1. Workflow : modifier → tester

```bash
sync-warly
```

Puis en jeu : `Ctrl+L` pour recharger le monde, ou relancer la session.

> **Rappel alias** (défini dans `~/.bashrc`) :
> ```bash
> alias sync-warly='rsync -av --exclude=".*" --exclude=".git" --exclude=".gitignore" \
>   --exclude="Ressources" --exclude="ai_agent" --exclude="CLAUDE.md" \
>   /home/arthur/Code/DSTmod_Warly/ \
>   "/home/arthur/.steam/steam/steamapps/common/Don't Starve Together/mods/WARLY_Overhaul/"'
> ```

---

## 2. Console en jeu

Ouvrir avec **`²`**.

| Mode | Quand l'utiliser | `print()` visible ? |
|------|-----------------|---------------------|
| **LOCAL** | Inspecter l'entité client, tags | À l'écran |
| **REMOTE** | Composants gameplay (hunger, foodmemory…) | Dans le server log |

→ En REMOTE, utiliser **`c_announce(tostring(val))`** pour afficher à l'écran.

---

## 3. Commandes utiles

### Stats du joueur

```lua
-- Remettre toutes les stats à 100%
ThePlayer.components.hunger:SetPercent(1)
ThePlayer.components.health:SetPercent(1)
ThePlayer.components.sanity:SetPercent(1)
```

### Inventaire

```lua
-- Donner N exemplaires d'un item
c_give("moqueca", 10)
c_give("bonesoup", 5)
-- etc. — utiliser le prefab name (nom vanilla)
```

### Temps / jours

```lua
-- Sauter N jours instantanément (propre, déclenche les transitions de saison)
c_skip(35)

-- Modifier directement le compteur de jours (pour tester GetMemorySize uniquement)
TheWorld.state.cycles = 36
```

---

## 4. Vérifier la mémoire alimentaire FIFO

```lua
-- Contenu de la queue (liste des N derniers plats)
c_announce(require("json").encode(ThePlayer.components.warly_foodmemory.queue))

-- Taille N actuelle selon le jour
c_announce(tostring(ThePlayer.components.warly_foodmemory:GetMemorySize()))

-- Occurrences d'un plat dans la queue
c_announce(tostring(ThePlayer.components.warly_foodmemory:GetOccurrences("moqueca")))

-- Multiplicateur effectif pour un plat
c_announce(tostring(ThePlayer.components.warly_foodmemory:GetMultiplier("moqueca")))

-- Vérifier que foodmemory vanilla est bien patchée (doit retourner 1)
local fm = ThePlayer.components.foodmemory
c_announce(fm ~= nil and tostring(fm:GetFoodMultiplier("moqueca")) or "foodmemory nil")
```

---

## 5. Vérifier les composants présents

```lua
-- foodmemory vanilla (doit exister mais être patchée, pas nil)
c_announce(tostring(ThePlayer.components.foodmemory))

-- Notre composant custom (ne doit pas être nil)
c_announce(tostring(ThePlayer.components.warly_foodmemory))

-- Vérifier un tag
c_announce(tostring(ThePlayer:HasTag("expertchef")))   -- doit être false
c_announce(tostring(ThePlayer:HasTag("masterchef")))   -- doit être true
```

---

## 6. Tester les multiplicateurs pas à pas

Protocole recommandé pour valider les stats :

1. `c_give("moqueca", 10)` — se donner des plats
2. Remettre les stats à 100% avant chaque repas
3. Manger un plat, noter les deltas
4. Vérifier avec `GetMultiplier` que la valeur correspond

Stats vanilla moqueca (référence avant Phase 5) :

| Stat | Brut | ×0.75 | ×0.50 | ×0.25 |
|------|------|-------|-------|-------|
| HP   | 60   | 45    | 30    | 15    |
| Faim | 112.5| ~84.4 | 56.25 | ~28.1 |
| Sanité | 33 | ~24.8 | 16.5  | ~8.25 |

### God mode

```lua
c_supergodmode()   -- toggle ON/OFF (même commande)
```