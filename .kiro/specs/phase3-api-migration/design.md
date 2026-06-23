# Design Document — Phase 3 : Migration API complète

## Overview

La Phase 3 finalise la migration de SIGMA Micro-Finance vers l'architecture hybride API/SQLite
établie en Phase 0. Les modules Remboursements, Demandes de prêt, Détail prêt et Reporting
accèdent encore directement à `DatabaseService` ; cette phase les bascule sur leurs services API
dédiés, suivant le patron « Server is Truth » de `SavingsApiService`.

**Périmètre des changements :**

- 2 nouveaux services Flutter : `RepaymentApiService`, `LoanRequestApiService`
- 2 services existants étendus : `ReportingApiService`, `LoanApiService`
- 2 modèles helper : `RepaymentListResult`, `ReportingResult<T>`
- 6 endpoints backend FastAPI ajoutés (router `demandes_pret.py` nouveau + extensions)
- 11 écrans migrés (remplacement des appels `DatabaseService()` directs)
- Zéro régression sur les 105 tests existants

---

## Architecture

### Diagramme de flux global

```
┌───────────────────────────────────────────────────────────────────────┐
│  Flutter Desktop (macOS / Windows)                                    │
│                                                                       │
│  Écrans migrés                         Écrans locaux (inchangés)      │
│  ─────────────                         ──────────────────────────     │
│  DailyCollectionPage                   DataExportPage                 │
│  RepaymentFormDialog                   MessageTemplatesPage           │
│  RepaymentHistoryPage                  NotificationHistoryPage        │
│  LoanRequestListPage       ──────►     CustomReportPage               │
│  LoanRequestFormDialog     direct      SmsSendingPage                 │
│  LoanRequestDetailDialog   SQLite      LoanDetailDialog (scans)       │
│  LoanDetailDialog                                                     │
│  ExecutiveDashboardPage                                               │
│  DelinquentLoansListPage                                              │
│  DelinquentLoanDetailPage                                             │
│  RecoveryActionsPage                                                  │
│       │                                                               │
│       ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │  Couche services (lib/core/services/)                       │     │
│  │                                                             │     │
│  │  RepaymentApiService (NOUVEAU)                              │     │
│  │  LoanRequestApiService (NOUVEAU)                            │     │
│  │  LoanApiService (ÉTENDU)                                    │     │
│  │  ReportingApiService (ÉTENDU)                               │     │
│  │                                                             │     │
│  │  ┌─────────────────┐     ┌──────────────────────────────┐  │     │
│  │  │  isOnline=true  │     │  isOnline=false              │  │     │
│  │  │                 │     │                              │  │     │
│  │  │  ApiService()   │     │  DatabaseService() (SQLite)  │  │     │
│  │  │  HTTP/JSON      │     │  cache local                 │  │     │
│  │  │  + cache update │     │                              │  │     │
│  │  └─────────────────┘     └──────────────────────────────┘  │     │
│  │                                                             │     │
│  │  SyncService : isOnline / queueOperation()                  │     │
│  └─────────────────────────────────────────────────────────────┘     │
│                          │ HTTP/JSON (LAN)                            │
└──────────────────────────┼────────────────────────────────────────────┘
                           ▼
┌───────────────────────────────────────────────────────────────────────┐
│  PC Serveur LAN — FastAPI + PostgreSQL (sigma_db)                     │
│                                                                       │
│  Routers existants             Ajouts Phase 3                         │
│  ─────────────────             ──────────────                         │
│  /prets                        /demandes-pret (nouveau router)        │
│  /remboursements               GET  /remboursements/history           │
│  /reporting                    GET  /reporting/executive              │
│  /clients …                    GET  /reporting/delinquents            │
│                                GET  /reporting/delinquent/{id}        │
└───────────────────────────────────────────────────────────────────────┘
```

### Stratégie « Server is Truth » — rappel du patron

Tous les services suivent exactement ce patron (identique à `SavingsApiService`) :

```
LECTURE :
  if isOnline → ApiService().get()  →  données serveur
                                     + _updateLocalCache() [fire-and-forget]
            fallback silencieux    →  DatabaseService() [SQLite]

ÉCRITURE :
  1. DatabaseService().insertXxx()  ← TOUJOURS en premier
  2. if isOnline → ApiService().post()
              ↳ échec → SyncService().queueOperation()
     else      → SyncService().queueOperation()
```

---

## Components and Interfaces

### 1. RepaymentApiService (NOUVEAU)

**Fichier :** `lib/core/services/repayment_api_service.dart`

**Patron :** singleton identique à `SavingsApiService`

```dart
class RepaymentApiService {
  static final RepaymentApiService _instance = RepaymentApiService._internal();
  factory RepaymentApiService() => _instance;
  RepaymentApiService._internal();

  /// Retourne les échéances en retard/dues aujourd'hui.
  /// Online  → GET /prets/collecte/jour + cache fire-and-forget
  /// Offline → DatabaseService().getPendingSchedules(retardOnly: retardOnly)
  /// Cache vide en offline → RepaymentListResult(items: [], isIncomplete: true)
  Future<RepaymentListResult> getPendingSchedules({bool retardOnly = false}) async { ... }

  /// Online  → GET /remboursements?pret_id={pretId} + cache fire-and-forget
  /// Offline → DatabaseService().getRepayments(pretId)
  Future<List<Repayment>> getRepayments(int pretId) async { ... }

  /// Online  → GET /remboursements/history
  /// Offline → DatabaseService().getGlobalRepaymentHistory()
  Future<List<Map<String, dynamic>>> getGlobalHistory() async { ... }

  /// Écriture hybride : SQLite d'abord, puis API ou queue.
  /// Exception SQLite → propagée (ne pas appeler ApiService).
  /// Exception HTTP après SQLite réussi → queueOperation + retour succès.
  Future<int> insertRepayment(Repayment r) async { ... }

  /// Toujours local — jamais d'appel HTTP, quel que soit isOnline.
  Future<Map<String, dynamic>> getCollectionStats() async {
    return DatabaseService().getCollectionStats();
  }

  // Méthode privée cache
  Future<void> _updateLocalCacheSchedules(List<RepaymentSchedule> items) async { ... }
  Future<void> _updateLocalCacheRepayments(List<Repayment> items) async { ... }
}
```

**Implémentation de référence — getPendingSchedules :**

```dart
Future<RepaymentListResult> getPendingSchedules({bool retardOnly = false}) async {
  if (await SyncService().isOnline) {
    try {
      final response = await ApiService().get('/prets/collecte/jour');
      final data = ApiService.decodeResponse(response);
      if (data != null) {
        final items = (data is List ? data : (data['items'] as List? ?? []));
        final schedules = items.map((e) => RepaymentSchedule.fromMap(e)).toList();
        _updateLocalCacheSchedules(schedules); // fire-and-forget
        return RepaymentListResult(items: schedules, isIncomplete: false);
      }
    } catch (_) {}
  }
  final local = await DatabaseService().getPendingSchedules(retardOnly: retardOnly);
  return RepaymentListResult(items: local, isIncomplete: local.isEmpty);
}
```

**Note :** Le paramètre `retardOnly` est appliqué côté SQLite en fallback. L'endpoint
`GET /prets/collecte/jour` retourne déjà les échéances impayées/en retard du jour.

---

### 2. LoanRequestApiService (NOUVEAU)

**Fichier :** `lib/core/services/loan_request_api_service.dart`

**Patron :** singleton identique à `SavingsApiService`

```dart
class LoanRequestApiService {
  static final LoanRequestApiService _instance = LoanRequestApiService._internal();
  factory LoanRequestApiService() => _instance;
  LoanRequestApiService._internal();

  /// Online  → GET /demandes-pret?statut={status}
  /// Offline → DatabaseService().getLoanRequests(status: status)
  Future<List<LoanRequest>> getLoanRequests({String? status}) async { ... }

  /// SQLite d'abord, puis API ou queue.
  Future<int> createLoanRequest(LoanRequest r) async { ... }

  /// SQLite d'abord (update), puis PUT /demandes-pret/{id}/statut ou queue.
  Future<void> updateLoanRequestStatus(
    int id,
    LoanRequestStatus s, {
    String? motif,
  }) async { ... }

  /// Transaction atomique SQLite (db.transaction()) pour Loan + N RepaymentSchedules.
  /// Si transaction échoue → exception propagée, aucune écriture partielle.
  /// Si transaction réussit :
  ///   Online  → POST /demandes-pret/{requestId}/debloquer
  ///   Offline → queueOperation
  Future<void> disburseLoan(
    int requestId,
    Loan loan,
    List<RepaymentSchedule> schedules,
  ) async { ... }

  Future<void> _updateLocalCacheLoanRequests(List<LoanRequest> items) async { ... }
}
```

**Implémentation de référence — disburseLoan :**

```dart
Future<void> disburseLoan(
  int requestId,
  Loan loan,
  List<RepaymentSchedule> schedules,
) async {
  // 1. Transaction atomique SQLite — tout ou rien
  final db = await DatabaseService().database;
  int loanId;
  await db.transaction((txn) async {
    loanId = await txn.insert('prets', loan.toMap());
    for (final s in schedules) {
      await txn.insert('echeancier', s.copyWith(pretId: loanId).toMap());
    }
    await txn.update(
      'demandes_pret',
      {'statut': LoanRequestStatus.debloquee.name},
      where: 'id = ?',
      whereArgs: [requestId],
    );
  }); // Si exception ici → SQLite annule tout automatiquement

  // 2. Sync serveur
  final body = {'loan_id': loanId, 'request_id': requestId};
  if (await SyncService().isOnline) {
    try {
      await ApiService().post('/demandes-pret/$requestId/debloquer', body);
    } catch (_) {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/demandes-pret/$requestId/debloquer',
        body: body,
      );
    }
  } else {
    await SyncService().queueOperation(
      method: 'POST',
      path: '/demandes-pret/$requestId/debloquer',
      body: body,
    );
  }
}
```

---

### 3. ReportingApiService (ÉTENDU)

**Fichier :** `lib/core/services/reporting_api_service.dart` (existant)

Nouvelles méthodes à ajouter au service existant :

```dart
// Ajouts dans ReportingApiService :

/// Online  → GET /reporting/executive → ReportingResult(data, isOfflineFallback: false)
/// Offline → DatabaseService().getExecutiveStats() → ReportingResult(..., isOfflineFallback: true)
Future<ReportingResult<ExecutiveDashboardStats>> getExecutiveStats() async { ... }

/// Online  → GET /reporting/delinquents?par_category={parCategory}
/// Offline → DatabaseService().getDelinquentLoans()
Future<ReportingResult<List<DelinquentLoan>>> getDelinquentLoans({
  String? parCategory,
}) async { ... }

/// Online  → GET /reporting/delinquent/{id}
/// Offline → DatabaseService().getDelinquentLoanDetails(id)
Future<ReportingResult<DelinquentLoanDetail?>> getDelinquentLoanDetails(int id) async { ... }

/// Toujours local — jamais d'appel HTTP.
Future<ReportingResult<RecoveryStats>> getRecoveryStats() async {
  final data = await DatabaseService().getRecoveryStats();
  return ReportingResult(data: data, isOfflineFallback: true);
}

/// Toujours local — jamais d'appel HTTP.
Future<ReportingResult<List<Map<String, dynamic>>>> getGlobalRecoveryActionsHistory() async {
  final data = await DatabaseService().getGlobalRecoveryActionsHistory();
  return ReportingResult(data: data, isOfflineFallback: true);
}
```

**Règle isOfflineFallback :** `isOfflineFallback: false` uniquement si les données
proviennent effectivement du serveur (réponse HTTP 2xx valide). Tout autre cas
(offline, exception, null) → `isOfflineFallback: true`.

---

### 4. LoanApiService (ÉTENDU)

**Fichier :** `lib/core/services/loan_api_service.dart` (existant)

Méthodes à ajouter/remplacer dans le service existant :

```dart
// Remplacer l'implémentation locale-only par la version hybride :

/// Online  → GET /prets/{pretId}/echeancier + cache fire-and-forget
/// Offline → DatabaseService().getRepaymentSchedules(pretId)
Future<List<RepaymentSchedule>> getRepaymentSchedules(int pretId) async { ... }

/// Délègue à RepaymentApiService pour cohérence — évite la duplication.
Future<List<Repayment>> getRepayments(int pretId) async {
  return RepaymentApiService().getRepayments(pretId);
}
```

**Note :** L'implémentation actuelle de `getRepaymentSchedules` et `getRepayments` dans
`LoanApiService` est purement locale. Phase 3 la remplace par la version hybride pour
`getRepaymentSchedules` et délègue `getRepayments` à `RepaymentApiService`.

---

### 5. Migrations des écrans

| Écran | Avant Phase 3 | Après Phase 3 |
|---|---|---|
| `DailyCollectionPage` | `DatabaseService().getPendingSchedules()` | `RepaymentApiService().getPendingSchedules()` |
| `DailyCollectionPage` | `DatabaseService().getCollectionStats()` | `RepaymentApiService().getCollectionStats()` |
| `RepaymentFormDialog` | `DatabaseService().insertRepayment()` | `RepaymentApiService().insertRepayment()` |
| `RepaymentHistoryPage` | `DatabaseService().getGlobalRepaymentHistory()` | `RepaymentApiService().getGlobalHistory()` |
| `LoanRequestListPage` | `DatabaseService().getLoanRequests()` | `LoanRequestApiService().getLoanRequests()` |
| `LoanRequestFormDialog` | `DatabaseService().insertLoanRequest()` | `LoanRequestApiService().createLoanRequest()` |
| `LoanRequestDetailDialog` | `DatabaseService().updateLoanRequestStatus()` | `LoanRequestApiService().updateLoanRequestStatus()` |
| `LoanRequestDetailDialog` | `DatabaseService().insertLoan()` + `insertRepaymentSchedule()` | `LoanRequestApiService().disburseLoan()` |
| `LoanDetailDialog` | `DatabaseService().getLoanById()` | `LoanApiService().getLoanById()` |
| `LoanDetailDialog` | `DatabaseService().getRepaymentSchedules()` | `LoanApiService().getRepaymentSchedules()` |
| `LoanDetailDialog` | `DatabaseService().getRepayments()` | `LoanApiService().getRepayments()` |
| `LoanDetailDialog` | `DatabaseService().getLoanContractScan()` etc. | **inchangé** (mode local acceptable) |
| `ExecutiveDashboardPage` | `DatabaseService().getExecutiveStats()` | `ReportingApiService().getExecutiveStats()` |
| `DelinquentLoansListPage` | `DatabaseService().getDelinquentLoans()` | `ReportingApiService().getDelinquentLoans()` |
| `DelinquentLoanDetailPage` | `DatabaseService()` | `ReportingApiService().getDelinquentLoanDetails()` |
| `RecoveryActionsPage` | `DatabaseService()` | `ReportingApiService().getDelinquentLoans()` + `.getRecoveryStats()` + `.getGlobalRecoveryActionsHistory()` |

### 6. Nouveaux endpoints backend FastAPI

#### 6.1 Router `demandes_pret.py` (nouveau fichier)

**Fichier :** `backend/app/routers/demandes_pret.py`

```python
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import Optional
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.pret import DemandePret, Pret, Echeancier
from app.schemas.pret import LoanRequestCreate, LoanRequestStatusUpdate, DisburseRequest

router = APIRouter(prefix="/demandes-pret", tags=["Demandes de prêt"])

@router.get("")
def list_demandes(
    statut: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
): ...

@router.post("", status_code=status.HTTP_201_CREATED)
def create_demande(
    data: LoanRequestCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
): ...
# Retourne : { "id": ..., "numero_demande": ..., "statut": ... }

@router.put("/{demande_id}/statut")
def update_statut(
    demande_id: int,
    data: LoanRequestStatusUpdate,  # { statut, motif_rejet? }
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
): ...

@router.post("/{demande_id}/debloquer", status_code=status.HTTP_201_CREATED)
async def debloquer_demande(
    demande_id: int,
    data: DisburseRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
): ...
# Opération atomique : crée Pret + Echeancier + met à jour statut demande
# Retourne : { "loan_id": ..., "numero_pret": ... }
# Déclenche AutomaticAccountingService.on_deblocage_pret()
```

#### 6.2 Endpoint `GET /remboursements/history`

**Fichier :** `backend/app/routers/remboursements.py` (ajout)

```python
@router.get("/history")
def get_global_history(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    """Historique global paginé de tous les remboursements."""
    offset = (page - 1) * limit
    items = db.query(Remboursement).order_by(
        Remboursement.date_paiement.desc()
    ).offset(offset).limit(limit).all()
    total = db.query(func.count(Remboursement.id)).scalar()
    return {"items": items, "total": total, "page": page, "limit": limit}
```

**Attention :** La route `/history` doit être déclarée **avant** `/{id}` dans le router
pour éviter que FastAPI interprète `history` comme un entier.

#### 6.3 Endpoints reporting (ajouts dans `reporting.py`)

```python
@router.get("/executive")
def get_executive_stats(db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Statistiques exécutives : encours, PAR, collecte, épargne, agents."""
    ...

@router.get("/delinquents")
def get_delinquent_loans(
    par_category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
): ...

@router.get("/delinquent/{loan_id}")
def get_delinquent_loan_detail(
    loan_id: int,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
): ...
```

---

## Data Models

### Modèles helper Flutter (nouveaux)

#### RepaymentListResult

```dart
// lib/models/repayment_list_result.dart

class RepaymentListResult {
  final List<RepaymentSchedule> items;
  /// true si les données sont incomplètes (offline + cache vide)
  final bool isIncomplete;

  const RepaymentListResult({
    required this.items,
    required this.isIncomplete,
  });
}
```

#### ReportingResult\<T\>

```dart
// lib/models/reporting_result.dart

class ReportingResult<T> {
  final T data;
  /// false uniquement si les données viennent du serveur (HTTP 2xx valide).
  /// true dans tous les autres cas (offline, exception, null, local-only).
  final bool isOfflineFallback;

  const ReportingResult({
    required this.data,
    required this.isOfflineFallback,
  });
}
```

### Modèles de données existants utilisés

| Modèle Dart | toMap() / fromMap() | Notes Phase 3 |
|---|---|---|
| `Repayment` | ✅ complet | Utilisé par `RepaymentApiService.insertRepayment()` |
| `RepaymentSchedule` | ✅ complet | Utilisé par `getPendingSchedules()`, `getRepaymentSchedules()` |
| `LoanRequest` | ✅ complet | Utilisé par `LoanRequestApiService` |
| `Loan` | ✅ existant | Utilisé par `disburseLoan()` |
| `ExecutiveDashboardStats` | À créer ou vérifier | Retourné par `getExecutiveStats()` |
| `DelinquentLoan` | À créer ou vérifier | Retourné par `getDelinquentLoans()` |
| `DelinquentLoanDetail` | À créer ou vérifier | Retourné par `getDelinquentLoanDetails()` |
| `RecoveryStats` | À vérifier | Retourné par `getRecoveryStats()` |

### Schémas Pydantic backend (nouveaux)

```python
# backend/app/schemas/pret.py — ajouts

class LoanRequestCreate(BaseModel):
    client_id: int
    produit_id: int
    montant_demande: float
    duree_mois: int
    frequence_remboursement: str
    objet_pret: str
    mensualite: float
    total_a_rembourser: float
    # ... autres champs de LoanRequest.toMap()

class LoanRequestStatusUpdate(BaseModel):
    statut: str
    motif_rejet: Optional[str] = None

class DisburseRequest(BaseModel):
    loan_id: int
    montant_initial: float
    taux_interet: float
    duree_mois: int
    # champs nécessaires pour recréer le prêt côté serveur
```

---

## Error Handling

### Hiérarchie de fallback — règles générales

```
1. isOnline = false           → DatabaseService() directement, aucun try/catch HTTP
2. isOnline = true
   → ApiService().get()
   → réponse 2xx + data != null  → données serveur + cache fire-and-forget
   → réponse null / non-2xx      → catch _ → DatabaseService() (fallback silencieux)
   → exception réseau            → catch _ → DatabaseService() (fallback silencieux)
```

Aucune exception ne doit traverser la frontière service → écran pour les lectures.

### Cas particuliers

| Situation | Comportement |
|---|---|
| `insertRepayment()` : SQLite échoue | Exception propagée à l'écran (données non sauvegardées) |
| `insertRepayment()` : SQLite OK, HTTP échoue | `queueOperation()` + retour succès |
| `disburseLoan()` : `db.transaction()` échoue | Exception propagée, 0 ligne écrite, pas d'appel HTTP |
| `disburseLoan()` : SQLite OK, HTTP échoue | `queueOperation()` + retour succès |
| `getCollectionStats()` : toujours | DatabaseService(), jamais d'exception HTTP possible |
| Cache fire-and-forget échoue | Exception ignorée silencieusement, valeur de retour inchangée |
| `ReportingApiService` : API échoue | Fallback SQLite + `isOfflineFallback: true` |
| `isOfflineFallback: true` + données vides | Liste vide retournée, jamais null, jamais exception |

### Indicateurs UI offline

- `LoanDetailDialog` : badge/icône non-bloquant si données depuis cache
- `ExecutiveDashboardPage` : bandeau "Données calculées localement" si `isOfflineFallback: true`
- `LoanRequestListPage` : message subtil si offline + cache non vide
- `DailyCollectionPage` : message "Aucune donnée disponible" si offline + cache vide
- `LoanRequestDetailDialog` : erreur explicite si `disburseLoan()` échoue côté SQLite

---

## Correctness Properties

*Une propriété est une caractéristique ou un comportement qui doit rester vrai pour toutes
les exécutions valides du système — une affirmation formelle sur ce que le système doit
faire. Les propriétés servent de pont entre les spécifications lisibles par l'humain et
les garanties de correction vérifiables automatiquement.*

---

### Property 1: Isolation lecture offline — aucun appel HTTP

*Pour tout service parmi `{RepaymentApiService, LoanRequestApiService, ReportingApiService,
LoanApiService}` et pour toute méthode de lecture, quand `SyncService().isOnline` retourne
`false`, aucun appel à `ApiService().get()` ne doit être émis — les données retournées
proviennent exclusivement de `DatabaseService()`.*

**Validates: Requirements 1.3, 2.3, 6.3, 6.8, 10.3**

---

### Property 2: SQLite-first écriture — DB appelée avant HTTP

*Pour tout service parmi `{RepaymentApiService, LoanRequestApiService}`, toute méthode
d'écriture (`insertRepayment`, `createLoanRequest`, `updateLoanRequestStatus`) et tout
payload valide, `DatabaseService().insertXxx()` ou `updateXxx()` est appelé et retourné
avec succès avant tout appel à `ApiService().post()` ou `put()`, quel que soit l'état
de la connexion.*

**Validates: Requirements 1.7, 2.4, 2.7, 10.3**

---

### Property 3: Atomicité disburseLoan — échec SQLite → 0 ligne créée

*Pour tout appel à `LoanRequestApiService.disburseLoan(requestId, loan, schedules)` où
`db.transaction()` lève une exception à n'importe quelle étape, après l'exception :
(a) la table `prets` ne contient aucune nouvelle ligne liée à cette tentative,
(b) la table `echeancier` ne contient aucune nouvelle ligne liée à cette tentative,
(c) aucun appel à `ApiService().post()` ni `SyncService().queueOperation()` n'a été émis.*

**Validates: Requirements 2.9, 2.12, 4.8**

---

### Property 4: Round-trip sérialisation — fromMap(toMap()) ≡ objet original

*Pour tout objet valide parmi `{Repayment, RepaymentSchedule, LoanRequest}`, appeler
`fromMap(obj.toMap())` doit produire un objet dont tous les champs sont égaux champ par
champ à ceux de l'objet original (équivalence structurelle, pas identité référentielle).*

**Validates: Requirements 9.4**

---

### Property 5: Fallback silencieux — exception API → pas d'exception vers l'écran

*Pour tout service parmi `{RepaymentApiService, LoanRequestApiService, ReportingApiService,
LoanApiService}`, toute méthode de lecture et toute réponse API simulée (null, code 4xx,
code 5xx, timeout, exception réseau), la méthode ne doit pas lever d'exception vers
l'appelant — elle doit retourner les données du cache SQLite (liste vide si cache vide).*

**Validates: Requirements 1.11, 2.13, 6.10**

---

### Property 6: getCollectionStats() — jamais d'appel HTTP

*Pour tout état de connectivité (`isOnline = true` ou `false`), l'appel à
`RepaymentApiService().getCollectionStats()` ne doit émettre aucun appel à
`ApiService().get()` ou `post()` — la méthode délègue exclusivement à
`DatabaseService().getCollectionStats()`.*

**Validates: Requirements 1.12**

---

### Property 7: isOfflineFallback=false seulement si données du serveur

*Pour tout appel à une méthode de `ReportingApiService` retournant un `ReportingResult<T>`,
`isOfflineFallback` est `false` si et seulement si la réponse HTTP était une réponse 2xx
valide avec `data != null`. Dans tous les autres cas (offline, exception, null, méthodes
local-only comme `getRecoveryStats`), `isOfflineFallback` doit être `true`.*

**Validates: Requirements 6.10, 6.11**

---

### Property 8: Singleton — factory retourne toujours la même instance

*Pour tout service parmi `{RepaymentApiService, LoanRequestApiService}`, appeler la
factory un nombre quelconque N de fois (N ≥ 2) depuis n'importe quel contexte doit
retourner la même instance en mémoire (identité référentielle `identical(a, b) = true`).*

**Validates: Requirements 1.1, 2.1, 10.1, 10.2**

---

### Property 9: Cache fire-and-forget — exception ignorée, valeur de retour inchangée

*Pour tout service et toute méthode de lecture, si `_updateLocalCacheXxx()` lève une
exception pendant la mise à jour en arrière-plan, la valeur déjà retournée à l'appelant
doit être identique à ce qu'elle aurait été sans l'exception (les données serveur ne sont
pas perdues).*

**Validates: Requirements 1.2, 10.4**

---

## Testing Strategy

### Approche double

**Tests unitaires** : exemples concrets, cas limites, comportements déterministes.
**Tests de propriétés (PBT)** : invariants universels vérifiés sur 100+ inputs générés aléatoirement.
Les deux approches sont complémentaires ; les tests de propriétés ne remplacent pas les tests unitaires.

### Bibliothèque PBT recommandée

- **Dart/Flutter** : [`dart_quickcheck`](https://pub.dev/packages/dart_quickcheck) (ou `propcheck`)
- Chaque test de propriété : **minimum 100 itérations** (`numRuns: 100`)
- Tag de traçabilité : `// Feature: phase3-api-migration, Property N: <texte>`

### Tests unitaires — services

Chaque service est testé avec des mocks `mockito` pour `SyncService`, `ApiService`,
`DatabaseService` :

```dart
// Exemple — RepaymentApiService
group('RepaymentApiService', () {
  test('lecture online → ApiService appelé, cache mis à jour', () async { ... });
  test('lecture offline → DatabaseService appelé, aucun HTTP', () async { ... });
  test('insertRepayment → SQLite avant HTTP', () async { ... });
  test('insertRepayment : HTTP échoue après SQLite → queueOperation + succès', () async { ... });
  test('getCollectionStats → jamais HTTP, isOnline quelconque', () async { ... });
  test('offline + cache vide → RepaymentListResult(isIncomplete: true)', () async { ... });
});

group('LoanRequestApiService', () {
  test('disburseLoan : transaction SQLite réussit → Loan + N schedules insérés', () async { ... });
  test('disburseLoan : transaction SQLite échoue → 0 ligne, exception, pas de HTTP', () async { ... });
  test('disburseLoan : SQLite OK + offline → queueOperation appelé', () async { ... });
});
```

### Tests de propriétés — implémentation

```dart
// Property 4 : Round-trip sérialisation
testWidgets('P4: Repayment fromMap(toMap()) round-trip', (tester) async {
  // Feature: phase3-api-migration, Property 4: fromMap(toMap()) ≡ original
  await quickCheck(numRuns: 100, (Repayment r) {
    final restored = Repayment.fromMap(r.toMap());
    expect(restored.pretId, equals(r.pretId));
    expect(restored.montantTotal, equals(r.montantTotal));
    expect(restored.modePaiement, equals(r.modePaiement));
    // ... tous les champs
  });
});

// Property 1 : Isolation offline
testWidgets('P1: aucun appel HTTP quand isOnline=false', (tester) async {
  // Feature: phase3-api-migration, Property 1: isolation lecture offline
  await quickCheck(numRuns: 100, (List<RepaymentSchedule> localData) async {
    when(mockSync.isOnline).thenAnswer((_) async => false);
    when(mockDb.getPendingSchedules()).thenAnswer((_) async => localData);
    await RepaymentApiService().getPendingSchedules();
    verifyNever(mockApi.get(any));
  });
});

// Property 3 : Atomicité disburseLoan
testWidgets('P3: SQLite transaction failure → 0 rows', (tester) async {
  // Feature: phase3-api-migration, Property 3: atomicité disburseLoan
  await quickCheck(numRuns: 100, (Loan loan, List<RepaymentSchedule> schedules) async {
    // Forcer db.transaction() à lever une exception
    when(mockDb.database).thenThrow(DatabaseException('forced'));
    expect(
      () => LoanRequestApiService().disburseLoan(1, loan, schedules),
      throwsA(isA<DatabaseException>()),
    );
    verifyNever(mockApi.post(any, any));
    verifyNever(mockSync.queueOperation(...));
  });
});
```

### Tests backend (pytest)

```python
# backend/tests/test_demandes_pret.py — tests d'intégration

def test_get_demandes_requires_auth(client):
    response = client.get("/demandes-pret")
    assert response.status_code == 401

def test_create_demande_returns_201(auth_client, loan_request_payload):
    response = auth_client.post("/demandes-pret", json=loan_request_payload)
    assert response.status_code == 201
    assert "id" in response.json()
    assert "statut" in response.json()

def test_debloquer_creates_pret_and_echeancier(auth_client, approved_request):
    response = auth_client.post(f"/demandes-pret/{approved_request.id}/debloquer", json={...})
    assert response.status_code == 201
    assert "loan_id" in response.json()

def test_history_pagination(auth_client):
    response = auth_client.get("/remboursements/history?page=1&limit=10")
    assert response.status_code == 200
    data = response.json()
    assert "items" in data
    assert len(data["items"]) <= 10
```

### Couverture minimale requise

| Module | Tests unitaires | Tests PBT | Non-régression |
|---|---|---|---|
| `RepaymentApiService` | ≥ 6 | Properties 1, 4, 5, 6, 9 | 105 tests passants |
| `LoanRequestApiService` | ≥ 5 | Properties 2, 3, 4, 5, 8 | idem |
| `ReportingApiService` extensions | ≥ 4 | Properties 5, 7 | idem |
| `LoanApiService` extensions | ≥ 2 | Property 1 | idem |
| Backend endpoints | ≥ 3 par endpoint | N/A | N/A |

### Commandes

```bash
# Flutter — tests unitaires + PBT (mode single-run, pas watch)
flutter test test/services/repayment_api_service_test.dart
flutter test test/services/loan_request_api_service_test.dart
flutter test test/services/reporting_api_service_test.dart

# Analyse statique — zéro erreur/warning requis
flutter analyze

# Backend
pytest backend/tests/test_demandes_pret.py -v
pytest backend/tests/test_remboursements.py -v
pytest backend/tests/test_reporting.py -v
```
