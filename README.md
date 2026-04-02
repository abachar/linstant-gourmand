# L'Instant Gourmand by Salma

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
| Framework | [Next.js 15](https://nextjs.org) (App Router + Turbopack) |
| UI | [React 19](https://react.dev) + [Headless UI](https://headlessui.com) |
| ORM | [Drizzle ORM](https://orm.drizzle.team) |
| Base de données | PostgreSQL |
| CSS | [Tailwind CSS 4](https://tailwindcss.com) |
| Validation | [Zod 4](https://zod.dev) |
| Auth | JWT ([jose](https://github.com/panva/jose)) + rate limiting |
| Tests | [Vitest](https://vitest.dev) |
| Linter / Formatter | [Biome](https://biomejs.dev) |
| CI/CD | GitHub Actions + Docker (GHCR) |

## Prérequis

- Node.js ≥ 24
- pnpm
- PostgreSQL

## Installation

```bash
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
pnpm dev
```

L'application est disponible sur `http://localhost:3000`.

## Build & Production

```bash
# Construire l'application
pnpm build

# Démarrer en production
pnpm start
```

### Docker

```bash
docker build -t linstant-gourmand .
docker run -p 3000:3000 --env-file .env linstant-gourmand
```

## Scripts

| Commande | Description |
|---|---|
| `pnpm dev` | Serveur de développement (Turbopack) |
| `pnpm build` | Build de production |
| `pnpm start` | Démarrer en production |
| `pnpm test` | Lancer les tests (Vitest) |
| `pnpm format` | Formater le code (Biome) |
| `pnpm lint` | Linter le code (Biome) |
| `pnpm check` | Vérification complète (format + lint) |

## Structure du projet

```
src/
├── app/                     # Routes Next.js (App Router)
│   ├── layout.tsx           # Layout racine
│   ├── page.tsx             # Tableau de bord
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
│   └── taxes/               # Rapport fiscal
├── common/
│   ├── db/
│   │   ├── schema.ts        # Schéma Drizzle (sales, purchases, products)
│   │   └── index.ts
│   └── format/              # Formateurs de dates et montants (français)
├── components/
│   ├── layouts/             # PageLayout, TopHeader, BottomNavigation
│   ├── ui/                  # Cards, EmptyState
│   ├── buttons/             # Boutons d'en-tête
│   └── defaults/            # Error & NotFound
└── middleware.ts             # Protection des routes (JWT)
```

Chaque feature suit la convention :

| Fichier | Rôle |
|---|---|
| `actions.ts` | Server Actions Next.js (appelables depuis le client) |
| `api.server.ts` | Accès direct à la base de données (serveur uniquement) |

## Authentification

Accès protégé par mot de passe unique. La session est un JWT signé HS256, stocké dans un cookie `httpOnly` valable 7 jours. Un rate limiter (5 tentatives / 15 min par IP) protège contre le brute-force. Toutes les routes redirigent vers `/login` si la session est absente ou invalide.

## CI/CD

Le workflow GitHub Actions (`.github/workflows/build.yml`) exécute sur chaque push/PR vers `main` :

1. Vérification Biome (format + lint)
2. Tests Vitest
3. Build et push de l'image Docker vers GitHub Container Registry (sur push `main` uniquement)
