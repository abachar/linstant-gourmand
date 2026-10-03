# L'Instant Gourmand by Salma

Gestion des commandes, achats, stock et taxes d'une traiteuse (petites bouchées, sandwichs, quiches).

| Dossier | Contenu |
|---|---|
| [`server/`](server/README.md) | Application web Next.js + API JSON `/api/v1` + base PostgreSQL. **Source de vérité.** |
| [`apple/`](apple/README.md) | App iOS 26 native (SwiftUI, SwiftData) : hors ligne, synchronisation, Face ID |
| [`docs/`](docs/) | [Plan iOS](docs/ios-plan.md), [contrat de l'API](docs/api.md) |

Production : https://linstant-gourmand.crafters.dev/

## En bref

- Le **web** et l'**app iOS** partagent la même logique métier côté serveur (`server/src/features/*/api.server.ts`).
- L'app iOS fonctionne **hors ligne** : ses modifications partent dans une file d'envoi, synchronisée au retour
  du réseau. Une commande modifiée des deux côtés est signalée sur l'iPhone, qui choisit sa version, celle du
  serveur, ou corrige.
- Verrouillage optimiste (`version`) et suppression logique (`deleted_at`) sur ventes, achats et produits.
