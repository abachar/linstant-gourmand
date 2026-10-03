# Revue UX/UI de l'app iOS

Revue de toutes les interfaces de `apple/LinstantGourmand/` et proposition d'un système visuel iOS dérivé de l'app web (`server/`), en gardant le rendu natif Liquid Glass d'iOS 26.

**Principe** : on reprend du web la couleur, la hiérarchie typographique et la densité d'information ; on garde d'iOS la structure (TabView, NavigationStack, List/Form, toolbars, sheets, matériaux). Aucun changement de logique métier, de synchro ou d'API.

## 1. Constats

Gravité : **G1** bloquant ou trompeur, **G2** gêne réelle, **G3** finition.

### Transverse

| # | Constat | Gravité |
|---|---|---|
| T1 | Aucune identité de marque hors de la teinte : fonds gris système, pas de cartes, pas de hiérarchie des montants. L'app ressemble à un écran de réglages alors que le web est chaleureux et dense. | G2 |
| T2 | `#ec1337` utilisé tel quel comme teinte : contraste 4,45:1 sur blanc et 4,24:1 sur le fond sombre du web, sous le seuil AA (4,5:1) pour le texte normal. | G2 |
| T3 | Couleurs d'état codées en dur (`.red`, `.orange`, `.green`) : `.green`/`.orange` sur blanc sont sous 3:1 ; aucune cohérence avec `success`/`warning` du web. | G2 |
| T4 | `glassEffect` appliqué au contenu (calendrier, cartes de stats) : contraire aux règles Liquid Glass (le verre est réservé à la couche de navigation et aux contrôles flottants) et peu lisible sur fond clair. | G2 |
| T5 | États vides minimalistes (`ContentUnavailableView` sans action), chargement par `ProgressView` nu : pas de chemin vers l'action principale. | G3 |
| T6 | Montants sans chiffres tabulaires : les colonnes « dansent ». | G3 |

### Par écran

| Écran | Constats | Gravité |
|---|---|---|
| **Connexion** | Form générique « Connexion » sans marque ; pas d'enchaînement e-mail → mot de passe au clavier ; bouton en ligne de Form peu visible. | G2 |
| **Verrouillage** | Cadenas système + titre : correct mais anonyme ; erreur en `.secondary` peu visible ; aucun rappel de l'identité. | G3 |
| **Barre de synchro** | Icône « à jour » grise : on ne distingue pas « à jour » de « hors ligne » d'un coup d'œil ; bouton de synchro sous 44 pt ; libellé VoiceOver éclaté en 3 éléments. | G2 |
| **Tableau de bord** | Stats en 2 rangées de 3 petites tuiles (`subheadline`) sur verre : montants peu lisibles, pas de bénéfice net (le web l'affiche) ; calendrier sans titre, aujourd'hui marqué par la seule couleur du chiffre ; cellules de 40 pt (< 44) ; chargement = spinner nu ; libellé d'onglet « Tableau de bord » trop long pour 5 onglets. | G2 |
| **Feuille du jour** | Liste correcte ; titre seul, aucun total du jour. | G3 |
| **Ventes (liste)** | Ligne dense en texte : pas d'acompte/reste visibles alors que c'est l'info clé du web (qui doit encore payer quoi) ; montant au même poids que le nom ; état vide sans bouton « Créer une vente ». | G2 |
| **Fiche vente** | Tout en `LabeledContent` : le montant et le reste à payer n'ont aucune hiérarchie ; paiement en texte « 120,00 € · Bancaire » ; bandeau de conflit en simple ligne orange ; boutons PDF sans distinction. | G2 |
| **Formulaire vente** | Total des articles dans un footer de section (peu visible, `headline` gris) ; mode de paiement en `Picker` menu (2 valeurs : un segmenté est plus direct) ; solde non mis en valeur ; ligne d'article : prix, « € » et stepper serrés, total de ligne en `caption` gris. | G2 |
| **Achats** | Picker d'année en ligne de liste (menu) ; total annuel en `ValueRow` ; achats importés marqués d'un cadenas (sens ambigu : « verrouillé » plutôt que « importé ») ; toucher un achat importé ne fait rien sans indication. | G2 |
| **Stock** | Pas de statut lisible (« Rupture / Stock faible / En stock » du web) ; couleurs système sous AA ; pas de compteur de produits. | G2 |
| **Formulaire produit/achat** | Corrects, natifs ; seulement les couleurs d'erreur. | G3 |
| **Taxes** | 4 `ValueRow` par mois : aucune hiérarchie, 12 sections × 4 lignes = très long ; picker d'année en ligne de liste ; chargement spinner nu. | G2 |
| **Clients** | **Erreur de chargement jamais affichée** (`error` est rempli mais pas lu) ; total pas mis en valeur (accent sur le web) ; pas de recherche alors que la liste peut être longue ; lignes désactivées hors ligne sans explication par ligne. | G1 (erreur muette) / G2 |
| **À traiter (liste)** | Lignes texte sans icône de type ni statut (conflit vs refus). | G3 |
| **Conflit (détail)** | Différences signalées uniquement par une couleur de fond orange à 15 % (invisible en sombre, inaccessible VoiceOver) ; actions en lignes de liste sans hiérarchie (l'action recommandée n'est pas mise en avant). | G2 |

## 2. Système visuel iOS

### Couleurs (asset catalog, variantes clair/sombre)

Dérivées des tokens de `server/src/app/globals.css`, ajustées pour l'AA (4,5:1 texte normal) en clair **et** en sombre. Les fonds de page sont teintés comme le web ; les barres restent en verre (aucun fond posé sous les barres).

| Asset | Clair | Sombre | Origine web | Contraste vérifié |
|---|---|---|---|---|
| `AccentColor` | `#DC1235` | `#FF3B5C` | `primary #ec1337` | 5,0:1 sur blanc ; 5,4:1 sur `#121011`, 4,9:1 sur `#1E1A1B`. Texte blanc sur l'accent : 5,0:1 (clair), 3,5:1 (sombre, réservé au texte ≥ 17 pt semibold = « grand texte » AA). |
| `LGBackground` | `#F8F6F6` | `#121011` | `background-light` / `background-dark` | — |
| `LGSurface` | `#FFFFFF` | `#1E1A1B` | `white` / `surface-dark` | — |
| `LGSurfaceMuted` | `#F4F1F1` | `#161314` | `slate-50` / `black/20` (tuiles dans les cartes) | — |
| `LGBorder` | `#E7E2E3` | `#2D2426` | `slate-200` / `border-dark` | décoratif |
| `LGTextMuted` | `#596577` | `#C9929B` | `slate-500` / `#c9929b` | 5,6:1 sur `#F8F6F6` ; 7,2:1 sur `#121011` |
| `LGSuccess` | `#047857` | `#0BDA92` | `success #0bda92` (le vert web n'atteint que 1,8:1 sur blanc) | 5,5:1 / 9,4:1 |
| `LGWarning` | `#B45309` | `#FF9F43` | `warning #ff9f43` (2,0:1 sur blanc sur le web) | 5,0:1 / 8,5:1 |
| `LGInfo` | `#2563EB` | `#60A5FA` | `blue-600` / `blue-400` (paiement bancaire) | 5,2:1 / 7:1 |

Le rouge d'erreur/danger = `AccentColor` (même rouge que la marque, comme le web). Les fonds teintés (« Reste », badge « Ce mois ») = couleur à 12 % (clair) / 20 % (sombre) via `Theme.tint(_:)`.

### Typographie : SF Pro, calée sur le web (Plus Jakarta Sans écartée)

**Choix : SF Pro (police système) avec des poids et des styles Dynamic Type calés sur la hiérarchie du web.**

Pourquoi pas Plus Jakarta Sans embarquée :
- les barres de navigation, la tab bar, les menus, les alertes et les `Form` restent en SF Pro (Liquid Glass) : on aurait deux polices à l'écran, ce qui fait « web dans une app » ;
- Dynamic Type et l'accessibilité (texte en gras, tailles AX) sont gérés nativement par SF ; avec une police custom, chaque `Font.custom(_:size:relativeTo:)` doit être maintenu ;
- l'identité de l'app web tient surtout à sa couleur, à ses montants en gras/black et à ses sur-titres en capitales espacées, que SF Pro reproduit fidèlement ;
- pas de fichier de police, pas de licence à suivre dans le bundle.

| Rôle | Web | iOS |
|---|---|---|
| Titre d'écran | `text-lg bold` dans un header | large title natif |
| Titre de bloc (« Finances », « Planning des commandes ») | `text-lg font-bold` | `.title3.bold()` |
| Nom sur une carte | `text-lg font-bold` | `.headline.weight(.bold)` |
| Montant principal d'une carte | `text-xl font-black` | `.title3.weight(.heavy)` + chiffres tabulaires |
| Montant héros (fiche, stats) | `text-2xl font-black` / `bold` | `.title.weight(.heavy)` / `.title2.bold()` |
| Sur-titre (« ACOMPTE », « ARTICLES ») | `text-[10–11px] uppercase font-bold tracking-wider` | `.caption2.weight(.bold)`, majuscules, tracking 0,6 |
| Méta (date, adresse) | `text-xs/sm` `#c9929b` | `.subheadline` / `.footnote` + `LGTextMuted` |

Tous les montants : `.monospacedDigit()`. Aucune taille fixe en points : tout passe par les styles de texte (Dynamic Type).

### Espacements, rayons, cartes, matériaux

- Grille de 4 pt : `xs 4`, `s 8`, `m 12`, `l 16`, `xl 24`. Marge d'écran 16, padding de carte 16, espace entre cartes 12.
- Rayons continus : carte 16 (web `rounded-xl` = 12 px, arrondi un peu plus pour s'accorder aux coins concentriques d'iOS 26), tuile 12, chips en capsule.
- **Cartes** : fond `LGSurface`, bordure 1 px `LGBorder`, pas d'ombre (iOS). Dans les `List`, la carte est la ligne elle-même (`listRowBackground` + `listRowSpacing`), ce qui garde swipe, sélection et VoiceOver natifs.
- **Fonds** : `LGBackground` sous les `List`/`Form`/`ScrollView` (`scrollContentBackground(.hidden)`). Les barres restent celles du système (verre + effet de bord de défilement) : jamais de `toolbarBackground` opaque, pas de tab bar personnalisée.
- **Verre** : uniquement sur la couche de contrôle — boutons de toolbar (natif), barre de synchro (`tabViewBottomAccessory`, natif), boutons de navigation du calendrier (`.buttonStyle(.glass)`), bouton Face ID et bouton de connexion (`.glassProminent`). Retiré du contenu (calendrier, stats).

### Icônes (lucide → SF Symbols)

| lucide (web) | SF Symbol |
|---|---|
| LayoutDashboard | `square.grid.2x2` |
| ShoppingBag | `bag` |
| ShoppingBasket | `basket` |
| Refrigerator | `refrigerator` |
| ChartPie | `chart.pie` |
| Users | `person.2` |
| Plus | `plus` |
| Pencil / Trash2 | `pencil` / `trash` |
| Clock / MapPin | `clock` / `mappin.and.ellipse` |
| FileText | `doc.text` |
| CreditCard / HandCoins | `creditcard` / `banknote` |
| CloudDownload | `icloud.and.arrow.down` |
| ChevronLeft / ChevronRight | `chevron.left` / `chevron.right` |
| CircleX / Check | `xmark.circle.fill` / `checkmark` |

### Composants partagés (`Core/UI/`)

- `Theme.swift` : couleurs, espacements, rayons, `Theme.tint(_:)`, modificateurs `.screenBackground()`, `.card()`, `.cardRow()`, `.overline()`, `Font` d'usage (`amountHero`, `amountCard`…).
- `DesignSystem.swift` : `SectionTitle`, `AmountTile`, `PaymentTiles`, `StatusPill`, `EmptyState`, `FilterChips`, `InfoBanner`, `BrandAvatar`, `LoadingCards`.

## 3. Améliorations par écran (priorisées)

**P1** = identité et lisibilité des chiffres ; **P2** = confort ; **P3** = finition.

| Écran | Améliorations | Priorité |
|---|---|---|
| Global | Asset catalog + `Theme` ; fond `LGBackground` partout ; couleurs d'état via tokens ; `SyncBadge`, `FormErrors`, `OfflineNotice` sur tokens. | P1 |
| Tableau de bord | Carte « Planning des commandes » (titre + mois en accent + boutons verre ‹ › ; bouton « Aujourd'hui » hors mois courant) ; aujourd'hui = pastille pleine accent, texte blanc ; jours avec ventes en gras + jusqu'à 3 points ; cellules ≥ 44 pt ; bloc « Finances » + badge « Ce mois » ; grille 2×2 CA / Dépenses / Bénéfice net / Taxe avec valeur du mois en gros et « Année : … » ; chargement en squelette ; onglet renommé « Accueil » (titre de l'écran inchangé). | P1 |
| Feuille du jour | Total du jour en en-tête ; lignes = `SaleRow`. | P3 |
| Ventes | Lignes-cartes : date (horloge) + nom en gras + montant heavy, adresse, notes (2 lignes), tuiles Acompte / Reste (accent) / Total ; filtre de période en chips (comme les années) ; état vide avec « Créer une vente » ; bouton + proéminent. | P1 |
| Fiche vente | Carte d'en-tête (nom, date, montant héros, adresse, notes) ; section Articles en sur-titre ; `PaymentTiles` ; bandeau de conflit `InfoBanner` warning ; boutons Devis/Facture en ligne avec `doc.text` ; Supprimer en bas. | P1 |
| Formulaire vente | Ligne « Total » en gras dans la section Articles ; ligne d'article : description, puis prix + « € » + stepper + total de ligne en gras ; mode de paiement en segmenté ; solde en accent ; nom client marqué obligatoire. | P2 |
| Achats | Chips d'année (`safeAreaBar`) ; carte de synthèse « Total {année} » + nombre d'achats ; ligne : date semibold + montant bold, description muted + icône `icloud.and.arrow.down` pour les importés + indication VoiceOver « non modifiable » ; état vide avec action. | P1 |
| Stock | En-tête « STOCK ACTUEL · N produits » ; ligne : nom bold + quantité colorée, « Modifié le » + « Date limite » colorée, `StatusPill` Rupture / Stock faible / En stock (couleur **et** texte). | P1 |
| Taxes | Chips d'année ; une carte par mois : mois + total heavy, 3 tuiles Bancaire (info) / Espèces (success) / TVA 12,3 % (accent) ; squelette au chargement ; carte de synthèse annuelle (somme des mois affichés, calcul d'affichage). | P1 |
| Clients | Erreur de chargement affichée (`InfoBanner`) ; total en accent bold ; recherche locale `.searchable` ; lignes-cartes. | P1 (erreur) / P2 |
| À traiter | Icône du type (bag/basket/refrigerator) + `StatusPill` « Conflit » (warning) / « Refusé » (danger). | P2 |
| Conflit | Différences : fond warning + icône `exclamationmark.triangle.fill` + libellé VoiceOver « différent » ; action recommandée en `.borderedProminent`, les autres en `.bordered`, boutons pleine largeur. | P2 |
| Barre de synchro | Icône « à jour » en success ; erreur en warning ; bouton de synchro 44 pt ; libellé VoiceOver combiné. | P2 |
| Connexion | En-tête de marque (avatar cerclé d'accent, « L'Instant Gourmand », « Accédez à votre espace d'administration » en accent) ; e-mail → mot de passe au clavier (`.submitLabel`) ; bouton `.glassProminent` pleine largeur ; erreur en `InfoBanner`. | P2 |
| Verrouillage | Avatar cerclé d'accent + titre + sous-titre ; erreur lisible ; fond `LGBackground`. | P3 |

### Garde-fous

- Liquid Glass : pas de fond opaque sous les barres, pas de tab bar personnalisée, `glassEffect` seulement sur des contrôles.
- Accessibilité : Dynamic Type (styles de texte uniquement), AA en clair et sombre (tableau ci-dessus), états signalés par texte **et** couleur, VoiceOver (éléments combinés, libellés des montants), cibles ≥ 44 pt.
- Aucun changement de logique métier, de synchro ou d'API ; aucun test supprimé ni affaibli.

## 4. Implémenté / écarts / reste à faire

### Implémenté

- **Système** : 8 colorsets `LG*` + `AccentColor` adaptatif, image `Avatar` (300×300, copiée de `server/public/images/salma.jpeg`), `Core/UI/Theme.swift` (couleurs, espacements, rayons, polices, `.screenBackground()`, `.card()`, `.cardRow()`, `.overline()`), `Core/UI/DesignSystem.swift` (`SectionTitle`, `AmountTile`, `PaymentTiles`, `StatusPill`, `EmptyState`, `FilterChips`, `InfoBanner`, `BrandAvatar`, `LoadingCards`). `SyncBadge`, `OfflineNotice`, `FormErrors` sur tokens.
- **Écrans** : toutes les améliorations P1 à P3 du tableau ci-dessus, sur les 14 fichiers de vues. Le filtre des ventes et les chips d'année (achats, taxes) sont en première ligne de liste.
- **Logique** : aucun fichier de `Core/API`, `Core/Sync`, `Core/Domain`, `Core/Persistence`, `Core/Auth`, `AppServices.swift`, des tests ni de `server/` modifié. Calculs ajoutés, tous d'affichage : bénéfice net, total du jour, totaux annuels des taxes, compteurs, recherche locale des clients.
- **Vérification** : `xcodebuild build` OK sans warning dans nos fichiers ; `xcodebuild test` OK, 30 tests réussis + 1 ignoré (`LiveAPITests`, désactivé par défaut), identique à l'état de départ.

### Écarts par rapport à la proposition

- Les lignes de `Form` (formulaires, fiche vente) gardent le fond de cellule système : seul le fond de page est teinté. Plus natif, et l'écart avec `LGSurface` est imperceptible.
- `Theme.tint` passe par `UIColor` pour obtenir 12 % en clair et 20 % en sombre ; non vérifié à l'écran sur les tuiles (seuls les écrans de connexion ont été capturés, clair et sombre).
- « Vente supprimée » et « Résolu » restent des `ContentUnavailableView` (états de fin, pas des listes vides).
- Corrigé à la revue : couleur des sur-titres des tuiles (le libellé « Reste » restait gris), en-tête du calendrier (titre, mois et boutons sur deux lignes, « Aujourd'hui » n'hérite plus de la forme circulaire), boutons d'action des conflits vraiment pleine largeur.

### Reste à faire

- Vérifier sur iPhone, clair et sombre, avec de vraies données (voir la liste de tests dans le rapport).
- Option : ouvrir l'adresse de livraison dans Plans depuis la fiche vente.
- Option : `tabBarMinimizeBehavior(.onScrollDown)` avec une version compacte de la barre de synchro.

### Retours après le premier essai sur iPhone

- **Crash** à l'ouverture du formulaire de vente (+ et Modifier) : `Theme.tint` passait par un `UIColor` dynamique dont la closure, isolée au `MainActor`, était résolue hors du thread principal. Remplacé par un `ShapeStyle` SwiftUI (`TintStyle`).
- **Barre de synchro** : la synchro est automatique, la barre n'apparaît plus que si quelque chose ne va pas (hors ligne, échec, conflits), sur une ligne discrète, sans bouton de synchro (`tabViewBottomAccessory(isEnabled:)`, iOS 26.1).
- Boutons ‹ › du calendrier à 32 pt comme sur le web (zone de toucher 44 pt) ; plus de chevron sur les ventes ; suppression par balayage sur les ventes ; tuiles de paiement et de taxes à hauteur égale ; filtres (périodes des ventes et années, tous en chips comme sur le web) remis en première ligne de liste : dans une `safeAreaBar`, l'effet de bord flou recouvrait 40 % de l'écran ; icône d'import Revolut avec la flèche vers le haut.
