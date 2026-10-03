# L'Instant Gourmand — app iOS

App SwiftUI native (iOS 26 minimum), utilisable hors ligne, synchronisée avec le serveur Next.js via l'API `/api/v1` ([contrat](../docs/api.md), [plan](../docs/ios-plan.md)).

## Ouvrir et lancer

1. Ouvrir `apple/LinstantGourmand.xcodeproj` dans Xcode.
2. Cible **LinstantGourmand** → onglet *Signing & Capabilities* → **Team** : choisir votre « Personal Team » (Apple ID gratuit). Le bundle id est `dev.crafters.linstantgourmand`.
3. Choisir le simulateur ou l'iPhone branché, puis **Run** (⌘R).

### Sur l'iPhone (compte gratuit)

- La première fois : *Réglages → Général → VPN et gestion de l'appareil* → faire confiance au développeur.
- **L'app expire au bout de 7 jours** : la relancer depuis Xcode (iPhone branché ou sur le même Wi-Fi). Les données locales et les modifications non envoyées sont conservées tant que le bundle id et l'équipe ne changent pas.

## Serveur utilisé

| Build | API |
|---|---|
| Debug sur simulateur | `http://localhost:3000/api/v1` (lancer `pnpm dev` dans `server/`) |
| Debug sur iPhone, Release | `https://linstant-gourmand.crafters.dev/api/v1` |

Pour forcer une autre URL : *Edit Scheme → Run → Arguments* → `-apiBaseURL http://192.168.1.10:3000/api/v1`.

## Face ID dans le simulateur

*Features → Face ID → Enrolled*, puis au moment du prompt *Features → Face ID → Matching Face* (ou *Non-matching Face*). Sans code ni Face ID configurés, le simulateur laisse passer le verrouillage.

## Fonctionnement

- **Verrouillage** au lancement et au retour d'arrière-plan (Face ID, repli sur le code). Le refresh token est dans le Keychain protégé par Face ID (`.biometryCurrentSet`), l'access token (15 min) seulement en mémoire. Le mot de passe n'est redemandé que si la session est révoquée ou expirée (90 jours sans ouvrir l'app).
- **Hors ligne** : ventes, achats et stock se créent, se modifient et se suppriment localement (SwiftData, fichiers chiffrés tant que l'iPhone est verrouillé). Les modifications attendent dans une file d'envoi, une seule par élément.
- **Synchronisation** : au déverrouillage, au retour du réseau, 2 s après une modification, en tirant une liste vers le bas, ou avec le bouton de la barre d'état au-dessus des onglets.
- **Conflits** : si une vente a été modifiée sur le web pendant que l'iPhone était hors ligne, elle passe « À traiter » (barre d'état et badge) avec une comparaison champ par champ : *Garder la mienne*, *Prendre le serveur* ou *Corriger*.
- **En ligne uniquement** : devis/factures PDF, import CSV Revolut, modification des clients, statistiques du tableau de bord et taxes (le dernier résultat reste consultable hors ligne).

## Structure

```
LinstantGourmand/
├── App/             point d'entrée, verrouillage, onglets, barre de synchro
├── Core/
│   ├── API/         client HTTP, DTO, erreurs
│   ├── Auth/        Keychain, Face ID, session
│   ├── Domain/      formulaires, règles métier dupliquées, comparaison des conflits
│   ├── Persistence/ modèles SwiftData
│   ├── Sync/        file d'envoi, moteur de synchro, réseau
│   └── UI/          composants partagés
└── Features/        Dashboard, Sales, Purchases, Products, Taxes, Clients, Conflicts, Auth
LinstantGourmandTests/  Swift Testing
```

## Tests

```bash
xcodebuild test -project LinstantGourmand.xcodeproj -scheme LinstantGourmand \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'
```

Test de bout en bout contre un serveur local (désactivé par défaut, crée puis supprime des données) :

```bash
TEST_RUNNER_LG_LIVE_API=1 TEST_RUNNER_LG_EMAIL=… TEST_RUNNER_LG_PASSWORD=… xcodebuild test … \
  -only-testing:LinstantGourmandTests/LiveAPITests
```

## Licence

[PolyForm Strict 1.0.0](../LICENSE.md) — voir le [README principal](../README.md#licence).
