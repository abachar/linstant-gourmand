# L'Instant Gourmand — serveur

> Application web + API `/api/v1` de l'app iOS ([`../docs/api.md`](../docs/api.md)). Vue d'ensemble : [`../README.md`](../README.md).

Site d'administration des commandes / achats pour traiteur spécialisé en petites bouchées, sandwichs et quiches pour événements professionnels et personnels.

## Fonctionnalités

- **Tableau de bord** — vue mensuelle des ventes avec calendrier interactif, synthèse du mois et de l'année en cours (ventes, dépenses, taxes)
- **Ventes** — création, consultation et modification des commandes clients (montant, acompte, solde, mode de paiement, adresse de livraison)
- **Achats** — suivi des dépenses avec import CSV depuis Revolut (déduplication automatique par hash)
- **Stock** — gestion des produits (quantités, dates de péremption)
- **Taxes** — rapport fiscal mensuel avec calcul automatique du taux (12,3 %) sur les paiements bancaires déclarables

## Stack technique

| Couche | Technologie |
|---|---|
| Runtime | Node.js 24 + [pnpm](https://pnpm.io) |
| Framework | [Next.js 16](https://nextjs.org) (App Router + Turbopack) |
| UI | [React 19](https://react.dev) + [Headless UI](https://headlessui.com) |
| ORM | [Drizzle ORM](https://orm.drizzle.team) + drizzle-kit (migrations) |
| Base de données | PostgreSQL |
| CSS | [Tailwind CSS 4](https://tailwindcss.com) |
| Validation | [Zod 4](https://zod.dev) |
| Auth | JWT ([jose](https://github.com/panva/jose)) + rate limiting ; API : access token + refresh token |
| Tests | [Vitest](https://vitest.dev) |
| Linter / Formatter | [Biome](https://biomejs.dev) |
| CI/CD | GitHub Actions + Podman (quadlets) |

## Prérequis

- Node.js ≥ 24
- pnpm
- PostgreSQL

## Installation

```bash
# Depuis le dossier server/
cd server

# Installer les dépendances
pnpm install

# Copier le fichier d'environnement
cp .env.example .env
```

Renseigner les variables dans `.env` :

```env
# URL de connexion PostgreSQL
DATABASE_URL=postgresql://DB_USERNAME:DB_PASSWORD@DB_HOST:DB_PORT/DB_NAME

# Email et mot de passe administrateur
# Générer le hash avec :
# node -e "const {scrypt,randomBytes}=require('crypto'),{promisify}=require('util'),s=promisify(scrypt),salt=randomBytes(16).toString('hex');s('YOUR_PASSWORD',salt,64).then(h=>console.log(salt+':'+h.toString('hex')))"
APP_ADMIN_EMAIL=root@admin.fr
APP_ADMIN_PASSWORD_HEX=YOUR_PASSWORD_HASHED

# Clé secrète de session (JWT HS256)
# Générer avec : pnpm dlx auth@latest secret
SESSION_SECRET_HEX=YOUR_GENERATED_SECRET
```

## Développement

```bash
pnpm db:migrate   # crée / met à jour le schéma
pnpm dev
```

L'application est disponible sur `http://localhost:3000`.

Après une modification de `src/common/db/schema.ts` : `pnpm db:generate --name <nom>`, relire le SQL généré
dans `drizzle/`, puis `pnpm db:migrate`. Les migrations sont versionnées et appliquées automatiquement en
production.

## Build & Production

```bash
# Construire l'application
pnpm build

# Démarrer en production
pnpm start
```

### Conteneur (Podman)

```bash
podman build -t linstant-gourmand -f Containerfile .
podman run --rm --env-file .env linstant-gourmand node dist/migrate.mjs   # migrations
podman run -p 3000:3000 --env-file .env linstant-gourmand
```

En production, l'image est construite par la CI (voir plus bas) puis déployée par deux quadlets Podman, présents
sur le serveur uniquement (non versionnés) : `linstant-gourmand-migrate.container` (oneshot,
`Exec=node dist/migrate.mjs`) et `linstant-gourmand.container` (application, avec
`Requires=`/`After=linstant-gourmand-migrate.service`).

### Sauvegarde / restauration

Les migrations ne s'annulent pas : sauvegarder avant un déploiement qui en contient une. Sur le serveur
(Fedora CoreOS), avec `DB` le nom du conteneur postgres :

```bash
podman exec "$DB" pg_dump -U <user> <base> | gzip > linstant_gourmand_db-$(date +%Y%m%d-%H%M%S).sql.gz
gunzip -c <fichier>.sql.gz | podman exec -i "$DB" psql -U <user> -d <base>   # dans une base vide, application arrêtée
```

Retour arrière : restaurer la sauvegarde et épingler l'image précédente (`ghcr.io/abachar/linstant-gourmand:sha-<commit>`).

## Scripts

| Commande | Description |
|---|---|
| `pnpm dev` | Serveur de développement (Turbopack) |
| `pnpm build` | Build de production |
| `pnpm start` | Démarrer en production |
| `pnpm test` | Lancer les tests (Vitest) — les tests d'API exigent `TEST_DATABASE_URL` (base **dédiée**, effacée à chaque lancement) |
| `pnpm typecheck` | Vérification TypeScript |
| `pnpm db:generate` | Générer une migration après modification du schéma |
| `pnpm db:migrate` | Appliquer les migrations |
| `pnpm db:studio` | Explorer la base (drizzle-kit studio) |
| `pnpm format` | Formater le code (Biome) |
| `pnpm lint` | Linter le code (Biome) |
| `pnpm check` | Vérification complète (format + lint) |

## Structure du projet

```
src/
├── app/                     # Routes Next.js (App Router)
│   ├── layout.tsx           # Layout racine
│   ├── page.tsx             # Tableau de bord
│   ├── api/v1/              # API JSON de l'app iOS (docs/api.md)
│   ├── providers.tsx        # React Query provider
│   ├── login/               # Page de connexion
│   ├── sales/               # Ventes
│   ├── purchases/           # Achats
│   ├── products/            # Stock
│   └── taxes/               # Rapport fiscal
├── features/
│   ├── auth/                # Authentification (JWT + rate limiting)
│   ├── dashboard/           # Tableau de bord
│   ├── sales/               # Ventes
│   ├── purchases/           # Achats (+ import CSV Revolut)
│   ├── products/            # Produits / stock
│   ├── clients/             # Clients (dérivés des ventes)
│   ├── sync/                # Flux de changements pour /api/v1/sync
│   ├── api/                 # Helpers HTTP de l'API (auth Bearer, erreurs)
│   └── taxes/               # Rapport fiscal
├── common/
│   ├── db/
│   │   ├── schema.ts        # Schéma Drizzle (sales, purchases, products, api_sessions)
│   │   ├── migrate.ts       # Runner de migrations autonome (bundle dist/migrate.mjs)
│   │   └── index.ts
│   ├── errors/              # ConflictError, NotFoundError, ForbiddenError, runAction
│   ├── sync/                # Règles de verrouillage optimiste
│   ├── validation/          # Helpers Zod (montants, dates)
│   └── format/              # Formateurs de dates et montants (français)
├── components/
│   ├── layouts/             # PageLayout, TopHeader, BottomNavigation
│   ├── ui/                  # Cards, EmptyState
│   ├── buttons/             # Boutons d'en-tête
│   └── defaults/            # Error & NotFound
└── proxy.ts                 # Protection des pages web (JWT) ; /api/* gère sa propre auth
drizzle/                     # Migrations SQL
test/                        # Tests d'intégration de l'API
```

Chaque feature suit la convention :

| Fichier | Rôle |
|---|---|
| `actions.ts` | Server Actions Next.js (appelables depuis le client) |
| `api.server.ts` | Logique métier et accès base de données, partagés par le web et l'API |
| `schemas.ts` | Validation Zod, partagée par le web et l'API |

Les modifications passent par un **verrouillage optimiste** (`version`) : une modification faite sur une
version périmée (ex. modifiée entre-temps sur l'iPhone) est refusée avec un message.

## Authentification

Accès protégé par mot de passe unique. La session est un JWT signé HS256, stocké dans un cookie `httpOnly` valable 7 jours. Un rate limiter (5 tentatives / 15 min par IP) protège contre le brute-force. Toutes les pages redirigent vers `/login` si la session est absente ou invalide.

L'API (`/api/v1`) utilise un access token JWT de 15 min et un refresh token de 90 jours par appareil
(table `api_sessions`, rotation à chaque utilisation, révocable).

## CI/CD

Le workflow GitHub Actions (`.github/workflows/build.yml`) exécute sur chaque push/PR vers `main` :

1. Vérification Biome (format + lint)
2. Vérification TypeScript
3. Tests Vitest (avec un service PostgreSQL pour les tests d'API)
4. Build Next.js
5. Build et push de l'image vers `ghcr.io/abachar/linstant-gourmand` (`latest` + `sha-…`, sur push `main` uniquement)

Le workflow ne se déclenche que si `server/` ou le workflow change (pas pour `apple/` ni `docs/`).
