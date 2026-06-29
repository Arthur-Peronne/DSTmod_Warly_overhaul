# Warly Mod — Spécifications complètes (version à jour)

## Stats de base

| Stat    | Valeur |
|---------|--------|
| Santé   | 150    |
| Faim    | 200    |
| Sanité  | 150    |

---

## Contraintes (Flaws)

### 1. Régime alimentaire
Warly ne peut manger que des plats de crock pot (vanilla + ses plats exclusifs). Comportement identique au Warly DST vanilla, non modifié.

### 2. Mémoire alimentaire — REWORK COMPLET
Remplacement du système vanilla (fenêtre temporelle) par une queue FIFO des N derniers repas.

**Taille de la queue selon la progression :**

| Jours     | Saisons          | N |
|-----------|------------------|---|
| 1 – 35    | Automne + Hiver  | 2 |
| 36 – 70   | Printemps + Été  | 3 |
| 71+       | Année 2+         | 4 |

**Malus :**
- Multiplicateurs fixes et configurables indépendamment dans les options du mod
- 4 occurrences = 0% → **Warly refuse de manger le plat** (refus dur, sans seuil d'urgence, même en cas de famine — intentionnel)
- Le malus s'applique à : faim, santé, sanité, et durée des buffs (réduction de la durée, pas de l'intensité)

**Multiplicateurs effectifs (valeurs par défaut, configurables) :**

| Occurrences dans la queue | Multiplicateur |
|---------------------------|----------------|
| 0                         | 100%           |
| 1                         | 75%            |
| 2                         | 50%            |
| 3                         | 25%            |
| 4                         | 0% (refus)     |

**Affichage :** rappel visuel sous la jauge de faim — option ON/OFF dans les paramètres du mod.

---

## Pouvoirs (Powers)

### 1. Objets spéciaux

**Portable Crock Pot**
- Coût de craft : 3 marbles / 6 coals / 6 twigs
- Vitesse de cuisson : 60% de la durée vanilla (plus rapide)
- Utilisable par tous pour cuisiner les recettes normales
- Les recettes exclusives Warly sont cuisinables sur n'importe quel crock pot (pas uniquement le portable)
- Construction / assemblage / démontage : uniquement par Warly

**Chef Pouch**
- Coût de craft : 1 bunny puff / 4 grass / 4 twigs
- 8 slots, multiplicateur de spoilage 0.6
- Construction et Équipable uniquement par Warly (check tag standard DST)

### 2. Objet de départ
- Portable Crock Pot uniquement (plus de potatoes / garlic)

### 3. Plats exclusifs (15 plats)

Cuisinables par Warly uniquement, sur n'importe quel crock pot.

**Légende colonnes :**
- **Type** : restriction diététique des personnages (Meat = Wurt ne peut pas manger, Veggie = Wigfrid ne peut pas manger, All = tout le monde peut manger)
- **Exclusions** : Non-edible = twigs/rot interdits comme filler dans la recette ; / = pas de restriction filler

---

#### A — Feeding dishes

| Plat                  | Ingrédients                                    | Exclusions  | Type  | HP  | Faim | Sanité |
|-----------------------|------------------------------------------------|-------------|-------|-----|------|--------|
| Moqueca               | 1 fish value + 1 onion + 1 tomato              | Non-edible  | Meat  | +60 | +90  | +33    |
| Salted caramel crepes | 1 dairy + 1 honey + 0.5 fruit value + 1 salt   | Non-edible  | Veggie| +50 | +50  | +50    |
| Bone bouillon         | 2 bone shards + 1 onion                        | Non-edible  | All   | +32 | +150 | +5     |
| Scary parmentier      | 1 pumpkin + 1 batilisk wing + 1 egg            | Non-edible  | Veggie| +5  | +90  | +5     |
| Monster tartare       | 2 monster meats                                | Non-edible  | Meat  | -20 | +75  | -20    |

---

#### B — Status dishes (éléments)

| Plat               | Ingrédients                       | Exclusions | Type  | HP  | Faim  | Sanité | Effet               | Durée  |
|--------------------|-----------------------------------|------------|-------|-----|-------|--------|---------------------|--------|
| Spicy burger       | 2 peppers + 1 meat value          | Non-edible | Meat  | +3  | +37.5 | +10    | +40°C               | 1 jour |
| Asparagazpacho     | 2 asparagus + 2 ices              | Non-edible | Veggie| +3  | +25   | +10    | -40°C               | 1 jour |
| Fish cordon bleu   | 2 frog legs + 1 fish value        | Non-edible | Meat  | +20 | +37.5 | -10    | Wetness immunity    | 1 jour |
| Glowberry mousse   | 1 glowberry value + 1 fruit value | Non-edible | Veggie| +3  | +25   | +10    | Émission de lumière (rayon torch / miner hat) | 1 jour |

---

#### C — Status dishes (stats)

| Plat        | Ingrédients                        | Exclusions | Type | HP | Faim | Sanité | Effet                     | Durée |
|-------------|------------------------------------|------------|------|----|------|--------|---------------------------|-------|
| Grim galette| 2 nightmare fuels + 1 vegetable value | /       | All  | +5 | +25  | +5     | Swap HP ↔ Sanité (instantané) | /  |

---

#### D — Bonus dishes (utility)

| Plat           | Ingrédients                      | Exclusions | Type  | HP  | Faim  | Sanité | Effet                        | Durée  |
|----------------|----------------------------------|------------|-------|-----|-------|--------|------------------------------|--------|
| Sweet smoothie | 2 honeys + 2 ices                | Non-edible | Veggie| +5  | +15   | +10    | x2 damage sur ressources (arbres / rochers / structures) | 1 jour |
| Salted cod soup| 2 salt crystals + 1 fish value   | Non-edible | Meat  | +15 | +37.5 | +5     | +10% movement speed          | 1 jour |

---

#### E — Bonus dishes (combat)

| Plat                  | Ingrédients                         | Exclusions | Type  | HP  | Faim  | Sanité | Effet                             | Durée  |
|-----------------------|-------------------------------------|------------|-------|-----|-------|--------|-----------------------------------|--------|
| Spiky salad           | 3 cactus + 1 pomegranate            | Non-edible | Veggie| -3  | +25   | +10    | +20% damage given                 | 1 jour |
| Roasted vegetables    | 2 garlics + 1 vegetable value       | Non-edible | Veggie| +15 | +25   | +5     | -20% damage taken                 | 1 jour |
| Volt goat chaud-froid | 1 volt goat horn + 1 honey + 1 ice  | /          | All   | +3  | +37.5 | +5     | -10% damage given + electric damage | 1 jour |

---

### 4. Effets spéciaux des plats exclusifs pour Warly

- **Durée des effets x1.5** pour Warly uniquement (s'applique aux Status éléments et Bonus dishes)
- **Plat préféré** : chaque plat exclusif donne +15 faim bonus à la consommation
- Ces deux bonus sont **cumulatifs avec le système de mémoire** (ils s'appliquent avant le malus)

---

## Suppressions par rapport au Warly vanilla

| Supprimé |
|----------|
| +20% hunger drain |
| Système de mémoire basé sur le temps (2 jours) |
| Fast fire-cooking |
| Objets de départ : 2 potatoes + 1 garlic |
| Portable grinding mill |
| Portable seasoning station |
| Assaisonnements : garlic powder, honey crystals, chili flakes, seasoning salt |

---

## Options du mod

### Position verticale du HUD mémoire (`hud_y_offset`)
Décalage vertical de la colonne de slots par rapport au badge santé. Utile quand d'autres mods (Combined Status avec beaucoup d'options) ajoutent des éléments qui entrent en conflit avec la position par défaut.
Options : 80 / 100 / 116 (défaut) / 140 / 160 / 200.

### Plats mangeables par tous (toggle ON/OFF)
Permet à Wigfrid de manger les plats Veggie et à Wurt de manger les plats Meat/Fish.
Les restrictions "Non-edible" (ingrédients) ne sont pas affectées par ce toggle.

### Durée des effets x1.5 (toggle ON/OFF)
Active ou désactive le bonus de durée x1.5 sur les buffs des plats exclusifs pour Warly.
Valeur par défaut : ON.

### Taille de la mémoire alimentaire (4 valeurs configurables)
Si default, on continue comme le mod habituel (2 au départ, puis 3 jour 36, puis 4 jour 71). Sinon, valeur fixe tout au long du jeu.
Valeurs par défaut : default, 2, 3, 4

### Multiplicateurs de mémoire (4 valeurs configurables)
Chaque multiplicateur (1re, 2e, 3e, 4e occurrence) est réglable indépendamment.
Valeurs par défaut : 0.75 / 0.50 / 0.25 / 0.00.

### Chef Pouch au départ (toggle ON/OFF)
Par defaut OFF 

---

## Divergences vanilla → mod

| Stat / Mécanisme | Vanilla          | Mod                     |
|------------------|------------------|-------------------------|
| Hunger           | 250              | 200                     |
| Hunger rate      | +20%             | Supprimé                |
| Mémoire          | Timer 2 jours    | FIFO N repas            |
| Refus manger     | Non (min 30%)    | Oui, à 4 occurrences    |
| Multiplicateurs  | {.9,.8,.65,.5,.3}| {1, .75, .50, .25, 0}   |
