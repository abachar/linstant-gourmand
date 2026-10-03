# API `/api/v1`

Base : `https://linstant-gourmand.crafters.dev/api/v1` (dev : `http://localhost:3000/api/v1`).

- JSON, clés en camelCase.
- **Montants** : chaînes décimales à 2 chiffres (`"125.50"`). Les entrées acceptent aussi un nombre.
- **Dates** : ISO 8601 UTC (`"2026-10-03T10:00:00.000Z"`).
- **Identifiants** : UUID (minuscules), générés par le client pour les créations.
- Toutes les routes sauf `/auth/login` et `/auth/refresh` exigent `Authorization: Bearer <accessToken>`.

## Erreurs

```json
{ "error": { "code": "conflict", "message": "…", "fields": { "items.0.quantity": "…" } }, "current": { … } }
```

| HTTP | `code` | Quand | Extra |
|---|---|---|---|
| 400 | `bad_request` | JSON illisible, paramètre invalide | |
| 401 | `unauthorized` | Access token absent, invalide ou expiré → rafraîchir puis rejouer | |
| 401 | `invalid_credentials` | Login refusé | |
| 401 | `invalid_refresh_token` | Refresh token inconnu, expiré ou révoqué → redemander le mot de passe | |
| 403 | `forbidden` | Ex. modifier/supprimer un achat importé | |
| 404 | `not_found` | | |
| 409 | `conflict` | `baseVersion` ≠ version serveur, ou entité supprimée sur le serveur | `current` : entité serveur (ou `null`) |
| 422 | `validation` | Données invalides | `fields` : chemin → message |
| 429 | `rate_limited` | Trop de tentatives de login | |

## Auth

### `POST /auth/login`
```json
{ "email": "…", "password": "…", "deviceName": "iPhone de Salma" }
```
→ `200`
```json
{
  "accessToken": "…", "accessTokenExpiresAt": "…",
  "refreshToken": "…", "refreshTokenExpiresAt": "…"
}
```
Access token : 15 min. Refresh token : 90 jours, glissant.

### `POST /auth/refresh`
`{ "refreshToken": "…" }` → `200`, même réponse que le login. **Rotation** : le refresh token reçu remplace l'ancien. L'ancien reste accepté 5 min (au cas où la réponse se perd).

### `POST /auth/logout`
`{ "refreshToken": "…" }` → `204`. Révoque la session de l'appareil.

## Entités

### Sale
```json
{
  "id": "uuid", "version": 3,
  "clientName": "Dupont", "deliveryDatetime": "…", "deliveryAddress": "…" | null, "description": "…" | null,
  "amount": "120.00", "deposit": "40.00", "depositPaymentMethod": "Bank" | "Cash",
  "remaining": "80.00", "remainingPaymentMethod": "Bank" | "Cash",
  "items": [ { "description": "Mini-quiches", "unitPrice": "1.50", "quantity": 80 } ],
  "createdAt": "…", "updatedAt": "…", "deletedAt": null
}
```
Règles (validées par le serveur, dupliquées dans les formulaires) :
- `clientName` non vide, `deliveryDatetime` valide.
- `amount = deposit + remaining`, montants ≥ 0.
- Si `items` n'est pas vide : `amount = Σ unitPrice × quantity`, `description` non vide, `quantity ≥ 1`.
- Proposition par défaut du formulaire : `remaining = min(amount, ceil(amount × 0.7 / 10) × 10)`, `deposit = amount − remaining`.

### Purchase
```json
{ "id": "uuid", "version": 1, "date": "…", "amount": "35.20", "description": "…" | null,
  "isImported": false, "createdAt": "…", "updatedAt": "…", "deletedAt": null }
```
Un achat importé (`isImported: true`) ne peut être ni modifié ni supprimé (`403`). `amount` peut être négatif (remboursement).

### Product
```json
{ "id": "uuid", "version": 1, "productName": "Beurre", "quantity": 4,
  "expirationDate": "…" | null, "updatedAt": "…", "deletedAt": null }
```
`productName` non vide, `quantity` entier ≥ 0.

## Écriture (verrouillage optimiste)

| Méthode | Route | Corps | Réponse |
|---|---|---|---|
| PUT | `/sales/:id` | `SaleInput` | `200` Sale |
| DELETE | `/sales/:id?baseVersion=N` | | `200` Sale (avec `deletedAt`) |
| PUT | `/purchases/:id` | `{ baseVersion, date, amount, description }` | `200` Purchase |
| DELETE | `/purchases/:id?baseVersion=N` | | `200` Purchase |
| PUT | `/products/:id` | `{ baseVersion, productName, quantity, expirationDate }` | `200` Product |
| DELETE | `/products/:id?baseVersion=N` | | `200` Product |

`SaleInput` = champs éditables de Sale + `baseVersion`.

`PUT` crée ou met à jour selon l'état serveur :

| État serveur | `baseVersion` | Résultat |
|---|---|---|
| id inconnu | `null` | création (`version: 1`) |
| id inconnu | N | `409`, `current: null` |
| existe, version 1, non supprimé | `null` | mise à jour (renvoi d'une création dont la réponse s'est perdue) |
| existe | `null` (autre cas) | `409` |
| existe, supprimé | N | `409`, `current` supprimé |
| existe, version = N | N | mise à jour, `version` + 1 |
| existe, version ≠ N | N | `409` |

`DELETE` : version égale → suppression logique ; déjà supprimé → `200` (idempotent) ; version différente → `409` ; id inconnu → `404`.

Pour **écraser** le serveur après un conflit : rejouer avec `baseVersion = current.version`.

## Synchronisation

### `GET /sync?cursor=<int>&limit=<int>`
`cursor` absent ou `0` : synchronisation complète (sans les entités supprimées). `limit` : 500 par défaut, 1000 max.

```json
{ "cursor": 1842, "hasMore": false, "sales": [ … ], "purchases": [ … ], "products": [ … ] }
```
Contient toutes les entités modifiées (y compris supprimées, `deletedAt` renseigné) depuis `cursor`. Rappeler avec le nouveau `cursor` tant que `hasMore` vaut `true`.

## Lecture seule / en ligne uniquement

| Méthode | Route | Réponse |
|---|---|---|
| GET | `/dashboard?month=YYYY-MM` | `{ month, currentMonthSales, currentMonthExpenses, currentMonthTax, currentYearSales, currentYearExpenses, currentYearTax }` (nombres) |
| GET | `/taxes?year=YYYY` | `{ selectedYear, availableYears: [2026, …], monthlyItems: [{ month, monthLabel, totalAmount, bankTotalAmount, cashTotalAmount, taxAmount }] }` |
| GET | `/clients` | `[{ clientName, deliveryAddress, orderCount, totalAmount }]` |
| PUT | `/clients` | `{ oldClientName, oldDeliveryAddress, newClientName, newDeliveryAddress }` → `204` |
| GET | `/sales/:id/pdf?type=quote\|invoice` | `application/pdf` |
| POST | `/purchases/import` | corps `text/csv` (export Revolut) → `{ "inserted": 12 }` |
