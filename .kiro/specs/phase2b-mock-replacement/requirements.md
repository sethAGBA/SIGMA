# Requirements Document

> **Titre :** Phase 2b — Remplacement des mocks résiduels — SIGMA Micro-Finance

## Introduction

La Phase 2 a couvert 5 fichiers ciblés. La Phase 2b élimine les valeurs statiques restantes dans les modules Caisse, Épargne, Sécurité et filtres Prêts.

## Requirements

### Requirement 1: Agent dynamique — opérations caisse diverses

WHEN `CashMiscellaneousDialog` enregistre une opération, THE dialog SHALL remplir `agent_operation` avec `AuthService().currentUsername` (repli `'Inconnu'`).

### Requirement 2: Agent dynamique — transferts caisse

WHEN `CashTransferDialog` enregistre un transfert, THE dialog SHALL remplir `agent_operation` avec `AuthService().currentUsername` (repli `'Inconnu'`).

### Requirement 3: Agent dynamique — opérations épargne

WHEN `SavingsOperationDialog` enregistre une transaction, THE dialog SHALL remplir `agentOperation` avec `AuthService().currentUsername` (repli `'Inconnu'`).

### Requirement 4: Utilisateur dynamique — journal d'audit sécurité

WHEN `SecurityAuditPage` enregistre un log d'audit, THE page SHALL utiliser `AuthService().currentUsername` (repli `'Inconnu'`).

### Requirement 5: Filtres agents dynamiques — listes prêts

WHEN les pages `LoanListPage` et `LoanRequestListPage` affichent le filtre agent, THE pages SHALL charger les agents depuis `DatabaseService().getAgents()` au lieu de noms hardcodés.

### Requirement 6: Filtres agences dynamiques — listes prêts

WHEN les pages `LoanListPage` et `LoanRequestListPage` affichent le filtre agence, THE pages SHALL charger les agences depuis `DatabaseService().getAgencies()`.
