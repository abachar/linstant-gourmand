# Plan — App iOS + API

> Rédigé le 2026-10-03. Statut : **implémenté** (phases 0 à 5). Contrat d'API détaillé : [`api.md`](api.md).

## Objectif

- Une app **iOS 26 native** (SwiftUI) utilisable **hors ligne**, synchronisée avec le serveur dès que le réseau revient.
- Le **serveur Next.js reste** la seule source de vérité et continue de servir l'interface web.
- Une **vraie API JSON** (`/api/v1`) consommée par l'app iOS.
- **Logique métier au maximum côté serveur.** Duplication tolérée côté iOS : validation des formulaires, affichage du solde (`montant − acompte`).
- Les conflits (même commande modifiée sur le web et sur l'iPhone hors ligne) sont **signalés sur iOS**, qui choisit : garder sa version, prendre celle du serveur, ou corriger.
- Déverrouillage par **Face ID**.

Périmètre actuel : **un seul iPhone + le web**. Les conflits ne peuvent donc venir que d'une modification web faite pendant que l'iPhone est hors ligne.

## Décisions

| Sujet | Décision | Raison |
|---|---|---|
| Framework serveur | Rester sur Next.js, route handlers natifs | Le plus simple : un seul serveur, un seul déploiement |
| Unité de conflit | La commande entière (vente + lignes) | Correspond au besoin, et les lignes sont déjà remplacées en bloc |
| Détection des conflits | Verrouillage optimiste (colonne `version`) | Simple, fiable, pas de fusion automatique |
| Identifiants | UUID générés par le client | Création hors ligne sans aller-retour serveur, envois idempotents |
| Suppressions | Suppression logique (`deleted_at`) | Seul moyen de propager une suppression à un appareil hors ligne |
| Curseur de synchro | Séquence Postgres globale (`change_seq`) | Jamais l'horloge de l'iPhone |
| Stockage iOS | SwiftData + file d'envoi (outbox) | Natif iOS 26 |
| Contrat d'API | DTO `Codable` écrits à la main côté iOS | Peu d'entités ; génération OpenAPI à envisager plus tard si besoin |
| Migrations | drizzle-kit + conteneur `-migrate` à exécution unique, comme Kanstrimi | Modèle déjà éprouvé |

---

## Phase 0 — Réorganisation du dépôt

Même structure que Kanstrimi (`server/` + `apple/`) :

```
linstant_gourmand/
├── .github/workflows/        # CI : jobs server (et apple plus tard)
├── docs/
│   └── ios-plan.md
├── server/                   # ← tout le contenu actuel de la racine
│   │   ├── linstant-gourmand-migrate.container
│   │   └── linstant-gourmand.container
│   ├── drizzle/              # migrations SQL générées + meta/
│   ├── public/
│   ├── src/
│   │   ├── app/
│   │   │   ├── api/v1/…      # nouvelle API
│   │   │   └── …             # pages web existantes
│   │   ├── common/db/        # + migrate.ts
│   │   ├── components/
│   │   ├── features/
│   │   └── proxy.ts
│   ├── Containerfile         # ex-Dockerfile
│   ├── drizzle.config.ts
│   ├── package.json
│   └── …
├── apple/
│   ├── LinstantGourmand.xcodeproj
│   ├── LinstantGourmand/
│   │   ├── App/              # point d'entrée, écran de verrouillage
│   │   ├── Core/
│   │   │   ├── API/          # APIClient, DTO, erreurs
│   │   │   ├── Auth/         # Keychain, Face ID, tokens
│   │   │   ├── Persistence/  # modèles SwiftData
│   │   │   └── Sync/         # SyncEngine, Outbox, conflits
│   │   └── Features/         # Dashboard, Sales, Purchases, Products, Taxes, Clients, Conflicts
│   ├── LinstantGourmandTests/
│   └── README.md
├── README.md                 # vue d'ensemble, renvoie vers server/ et apple/
└── LICENSE.md
```

Étapes :
1. `git mv` de tout le projet Next.js vers `server/` (en conservant l'historique).
2. CI : `working-directory: server` et chemin du cache pnpm (`server/pnpm-lock.yaml`).
3. Renommer `Dockerfile` en `Containerfile` et `.dockerignore` en `.containerignore` (podman, comme Kanstrimi).
4. Découper le README : racine (vue d'ensemble), `server/README.md` (actuel), `apple/README.md`.
5. Les alias TypeScript (`@common`, `@features`…) sont relatifs à `server/`, donc rien à changer.

---

## Phase 1 — Base de données et migrations

### 1.1 Outillage

- Ajouter `drizzle-kit` (dev) et `server/drizzle.config.ts` (`out: "./drizzle"`).
- Scripts : `db:generate`, `db:migrate`, `db:studio`.
- `server/src/common/db/migrate.ts` : runner autonome copié de Kanstrimi (`server/src/db/migrate.ts`), adapté au driver `pg` (`drizzle-orm/node-postgres/migrator`). Il n'importe ni l'auth ni l'app et trouve `drizzle/` en remontant l'arborescence.
- **Build** : le mode standalone de Next.js n'embarque pas ce script. Il faut le bundler à part avec esbuild (`dist/migrate.js`) et copier `drizzle/` dans l'image runtime.

### 1.2 Baseline (base de prod existante)

La base de prod a déjà ses tables. `0000_baseline.sql` est générée à partir du schéma d'origine et rendue
**idempotente** (`CREATE … IF NOT EXISTS`) : sur la base existante elle n'a aucun effet et est simplement
enregistrée comme appliquée. Aucune manipulation manuelle de `drizzle.__drizzle_migrations`.

### 1.3 Migration `0001` — synchro

Sur `sales`, `purchases` et `products` :

| Colonne | Type | Rôle |
|---|---|---|
| `version` | `integer not null default 1` | Verrouillage optimiste, +1 à chaque écriture |
| `updated_at` | `timestamptz not null default now()` | Information (existe déjà sur `products`) |
| `deleted_at` | `timestamptz null` | Suppression logique |
| `change_seq` | `bigint not null default nextval('sync_seq')` | Curseur de synchro, réaffecté à chaque écriture |

- Séquence globale `sync_seq` + index sur `change_seq` de chaque table.
- Trigger `bump_sync_columns` (BEFORE UPDATE) : incrémente `version`, réaffecte `change_seq` et `updated_at`
  à chaque mise à jour. Aucun chemin d'écriture (web, API, renommage de client, suppression) ne peut l'oublier.
- `sale_items` n'a pas de version propre : toute modification d'une ligne incrémente la version de la vente.

Nouvelle table `api_sessions` (refresh tokens) :

| Colonne | Type |
|---|---|
| `id` | `uuid pk` |
| `token_hash` | `text unique` (SHA-256 du refresh token) |
| `device_name` | `text` |
| `created_at`, `last_used_at`, `expires_at` | `timestamptz` |
| `revoked_at` | `timestamptz null` |

### 1.4 Déploiement (quadlets)

Sur le serveur (non versionnés, comme Kanstrimi) : `linstant-gourmand-migrate.container` (oneshot,
`Exec=node dist/migrate.mjs`) et `linstant-gourmand.container` (`Requires=`/`After=` le service de migration,
`AutoUpdate=registry`). Image : `ghcr.io/abachar/linstant-gourmand:latest`, publiée par la CI. Le runner est bundlé
par esbuild (`pnpm build:migrate`) car le mode standalone de Next.js ne l'embarque pas.

---

## Phase 2 — Couche métier partagée (web + API)

Le web (Server Actions) et l'API appellent **les mêmes fonctions** de `features/<feature>/api.server.ts`. Toute règle métier y vit, nulle part ailleurs.

1. **Schémas Zod** par entité dans `features/<feature>/schemas.ts`, utilisés par les Server Actions **et** l'API. Les actions n'ont aujourd'hui aucune validation.
2. **Contrôle de version** dans `saveX` / `deleteX` : la ligne est lue `FOR UPDATE`, comparée à `baseVersion`
   (`common/sync`), puis mise à jour (le trigger incrémente la version). Écart → `ConflictError(current)`
   (version actuelle du serveur, éventuellement supprimée).
3. **Upsert idempotent** `saveX(id, baseVersion | null, data)` :
   - id inexistant et `baseVersion = null` → création avec l'id fourni ;
   - id existant et version correspondante → mise à jour ;
   - id existant, `baseVersion = null`, données identiques → ok (envoi rejoué) ;
   - sinon → conflit.
4. **Suppression logique** : `deleteX` renseigne `deleted_at`. Toutes les lectures (listes, dashboard, taxes, clients) filtrent `deleted_at IS NULL`.
5. **Clients** : `updateClient` incrémente `version` et `change_seq` de chaque vente touchée, pour que l'iPhone voie le changement (et détecte un conflit s'il a une modification en attente sur l'une d'elles).
6. Corriger au passage `app/sales/[id]/print/route.tsx` : une vente inexistante fait planter la route au lieu de renvoyer 404.

Tests Vitest : création, mise à jour, conflit, envoi rejoué, suppression puis modification, modification puis suppression.

---

## Phase 3 — API `/api/v1`

### Auth

- `proxy.ts` : pour `/api/v1/*`, vérifier `Authorization: Bearer <access>` et répondre **401 JSON** (pas de redirection). `/api/v1/auth/login` et `/api/v1/auth/refresh` sont publiques et limitées en débit (`rate-limiter-flexible`, déjà présent).
- **Access token** : JWT HS256 (même clé que le web), **15 min**.
- **Refresh token** : aléatoire 256 bits, **90 jours glissants**, **rotation** à chaque utilisation, stocké haché dans `api_sessions`, révocable.

### Endpoints

| Méthode | Route | Rôle | Hors ligne iOS |
|---|---|---|---|
| POST | `/auth/login` | `{email, password, deviceName}` → `{accessToken, refreshToken, expiresIn}` | — |
| POST | `/auth/refresh` | `{refreshToken}` → nouvelle paire | — |
| POST | `/auth/logout` | Révoque la session | — |
| GET | `/sync?cursor=<seq>` | Tout ce qui a changé depuis `cursor` (y compris supprimé) + nouveau curseur | — |
| PUT | `/sales/:id` | Upsert `{baseVersion, …, items[]}` | ✅ |
| DELETE | `/sales/:id?baseVersion=` | Suppression logique | ✅ |
| PUT / DELETE | `/purchases/:id` | Idem | ✅ |
| PUT / DELETE | `/products/:id` | Idem | ✅ |
| GET | `/sales/:id/pdf?type=quote\|invoice` | PDF devis/facture | ❌ |
| POST | `/purchases/import` | CSV Revolut (multipart) | ❌ |
| GET | `/clients` | Liste dérivée des ventes | lecture du cache |
| PUT | `/clients` | Renommer / changer l'adresse | ❌ |
| GET | `/dashboard?month=YYYY-MM` | Stats calculées sur le serveur | lecture du cache |
| GET | `/taxes?month=YYYY-MM` | Rapport fiscal | lecture du cache |

`GET /sync` :
```json
{
  "cursor": "1842",
  "hasMore": false,
  "sales":     [{ "id": "…", "version": 4, "deletedAt": null, "items": [ … ], … }],
  "purchases": [ … ],
  "products":  [ … ]
}
```
Pagination par lots (ex. 500) avec `hasMore`. `cursor` absent → synchro complète.

### Format des réponses

- Montants en **chaînes décimales** (`"125.50"`), dates en **ISO 8601 UTC**.
- Erreurs : `{ "error": { "code": "…", "message": "…", "fields": { … } } }`
  - `401 unauthorized`, `404 not_found`
  - `409 conflict` → réponse avec `"current": <entité serveur>` (ou `null` si purgée)
  - `422 validation` → `fields` issus de Zod

---

## Phase 4 — Adaptations web

- Formulaires d'édition (vente, achat, produit) : champ caché `version`, envoyé à l'action.
- Sur conflit : message « Cette commande a été modifiée ailleurs » avec un bouton de rechargement. Pas d'écran de fusion sur le web.
- Suppressions logiques (transparent pour l'utilisateur).

---

## Phase 5 — App iOS 26

### Socle

- SwiftUI, **iOS 26 minimum**, Swift 6 (concurrence stricte), Liquid Glass natif.
- Bundle id : `dev.crafters.linstantgourmand` (même convention que `dev.crafters.kanstrimi`).
- Distribution : **pas de compte Apple Developer payant**. Installation depuis Xcode avec l'équipe « Personal Team » (Apple ID gratuit) :
  - l'app **expire au bout de 7 jours** : il faut la réinstaller depuis Xcode (câble ou Wi-Fi). Les données locales et l'outbox sont conservées tant que le bundle id et l'équipe ne changent pas ;
  - pas de TestFlight, pas de notifications push, pas d'App Groups (donc pas de widget) ;
  - Face ID, Keychain, SwiftData et les **notifications locales** fonctionnent.
- API : `https://linstant-gourmand.crafters.dev/api/v1` (HTTPS, compatible App Transport Security).

### Face ID et sécurité

- Verrouillage au lancement et au retour d'arrière-plan. Déverrouillage via `LocalAuthentication` (`.deviceOwnerAuthentication` : Face ID, puis code de l'iPhone en repli). Déclarer `NSFaceIDUsageDescription` dans le fichier `Info.plist`.
- Fonctionne **hors ligne** : Face ID protège les données locales, indépendamment du serveur.
- **Refresh token** dans le Keychain avec `SecAccessControl` `.biometryCurrentSet` : lu uniquement après Face ID, et invalidé si les visages enregistrés changent. Access token en mémoire seulement.
- Store SwiftData en `FileProtectionType.complete` (chiffré tant que l'iPhone est verrouillé).
- Conséquence : **pas de synchro en arrière-plan en V1**, uniquement quand l'app est ouverte et déverrouillée.
- Mot de passe saisi une seule fois (première connexion ou session révoquée), ensuite Face ID uniquement.

### Stockage local (SwiftData)

- `Sale`, `SaleItem`, `Purchase`, `Product` : copie fidèle des DTO serveur, plus `version` et `syncState` (`synced`, `pending`, `conflict`, `rejected`).
- `CachedReport` : dernier dashboard et rapport de taxes reçus (JSON + date), affichés en lecture seule hors ligne avec la mention « à jour au … ».
- `SyncMeta` : dernier `cursor`.
- `PendingMutation` (outbox) : `id`, `entityType`, `entityId`, `op` (`upsert` / `delete`), `payload`, `baseVersion`, `createdAt`, `attempts`, `lastError`.
  - **Regroupement** : plusieurs modifications hors ligne de la même entité donnent **une seule** mutation (dernier contenu, `baseVersion` d'origine).

### Moteur de synchro

Déclencheurs : déverrouillage, retour du réseau (`NWPathMonitor`), après chaque modification locale (avec un délai d'attente), tirer pour rafraîchir.

1. **Push** : envoyer l'outbox dans l'ordre.
   - `2xx` → appliquer la réponse serveur (nouvelle version), retirer la mutation.
   - `409` → entité en `conflict`, conserver la mutation et la version serveur reçue.
   - `422` → entité en `rejected` avec les erreurs de champs.
   - erreur réseau / `5xx` → arrêt, nouvel essai plus tard (backoff).
2. **Pull** : `GET /sync?cursor=` jusqu'à `hasMore = false`.
   - Une entité avec une mutation en attente n'est **jamais écrasée** par le pull. Si sa version serveur dépasse `baseVersion`, elle passe en `conflict`.
3. Rafraîchir les caches dashboard/taxes si en ligne.

### Résolution des conflits

Badge « À traiter » dans la navigation, liste des entités en `conflict` / `rejected`, puis écran de comparaison champ par champ (ma version / serveur, différences surlignées) :

| Action | Effet |
|---|---|
| **Garder la mienne** | Renvoi avec `baseVersion = version serveur` (écrase le serveur) |
| **Prendre le serveur** | Abandon de la mutation, application de la version serveur |
| **Corriger** | Formulaire prérempli avec ma version et les valeurs serveur affichées, enregistrement avec `baseVersion = version serveur` |

Cas particuliers :
- Supprimée sur le serveur, modifiée sur l'iPhone → « Recréer » ou « Abandonner ».
- Modifiée sur le serveur, supprimée sur l'iPhone → « Supprimer quand même » ou « Garder la version serveur ».
- `rejected` (422) → « Corriger » uniquement.

### Fonctionnalités en ligne uniquement

PDF devis/facture (le dernier généré reste consultable en cache, partage via `ShareLink`), import CSV (`fileImporter`), édition des clients. Hors ligne, ces boutons sont désactivés avec une explication.

### Tests

- Moteur de synchro testé contre un faux `APIClient` : push ok, 409, 422, coupure réseau au milieu de l'outbox, pull sans écraser une modification en attente.
- Regroupement de l'outbox.

---

## Ordre de livraison

| # | Livrable | Dépend de |
|---|---|---|
| 0 | Réorganisation `server/` + `apple/`, CI verte | — |
| 1 | drizzle-kit, baseline, `migrate.ts`, Containerfile, quadlets | 0 |
| 2 | Migration `0001` + couche métier versionnée + Zod + tests | 1 |
| 3 | Adaptations web (version dans les formulaires, suppression logique) | 2 |
| 4 | API `/api/v1` (auth, sync, CRUD, PDF, rapports) + tests | 2 |
| 5a | iOS : socle, login, Face ID, lecture seule via `/sync` | 4 |
| 5b | iOS : édition hors ligne, outbox, push | 5a |
| 5c | iOS : écran de conflits, fonctionnalités en ligne uniquement | 5b |

Chaque étape est livrable seule : le web continue de fonctionner à chaque étape.

## Décisions V1 (2026-10-03)

- Prod : `https://linstant-gourmand.crafters.dev/`.
- Pas de compte Apple Developer : installation via Xcode, réinstallation tous les 7 jours (voir Phase 5).
- Pas de table `clients` en V1.
- Pas de notifications en V1.

## Évolutions possibles

- Compte Apple Developer (99 €/an) : supprime l'expiration à 7 jours, débloque TestFlight et les widgets.
- Notifications locales (rappel de livraison la veille) : possibles même sans compte payant.
- Table `clients` si les besoins évoluent (édition hors ligne des clients).
