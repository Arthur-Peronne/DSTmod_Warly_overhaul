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
