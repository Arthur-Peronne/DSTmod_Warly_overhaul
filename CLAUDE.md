# Warly Mod — Contexte projet

## Contexte

Mod Don't Starve Together pour reworker le personnage Warly. Développeur : background data scientist / physique computationnelle, connaît Python, apprend Lua pour ce projet. Objectif : rendre Warly plus viable en solo, avec une identité culinaire plus forte et cohérente.

## Directives agent (chargées automatiquement)

@ai_agent/AGENT.md

## Todolist (chargée automatiquement)

@ai_agent/TODOLIST.md

## Fichiers de référence

| Fichier | Contenu |
|---------|---------|
| [CONTENT.md](ai_agent/CONTENT.md) | Spécifications complètes du mod (stats, mécaniques, plats, options) |
| [TECHNICAL.md](ai_agent/TECHNICAL.md) | Architecture prévue + analyse du code source DST |
| [TODOLIST.md](ai_agent/TODOLIST.md) | Tâches d'implémentation par phase |
| [CONVERSATIONS.md](ai_agent/CONVERSATIONS.md) | Journal des sessions de travail |

## Principe architectural clé

Ne pas modifier les composants vanilla (`foodmemory.lua`, `eater.lua`) — créer des composants propres pour Warly et hooker les comportements existants.

## Références utiles

- Discussion forum Klei : https://forums.kleientertainment.com/forums/topic/124748-warly-rebalance-dst/
- Mod Shipwrecked Warly similaire : https://steamcommunity.com/sharedfiles/filedetails/?id=1360414089
- Thread technique durée des effets : https://forums.kleientertainment.com/forums/topic/132511-how-do-you-change-warlys-foods-temperature-duration/
