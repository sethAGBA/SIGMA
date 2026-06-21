// lib/core/services/bceao_export_service.dart
//
// Export des fichiers plats réglementaires BCEAO/Coban.
// Séparateur : `|`  |  Encodage : UTF-8 avec BOM
// Destination : {appDocDir}/exports/bceao/
//
// Exigences couvertes :
//   5.1 — CSV structurés avec séparateurs et colonnes réglementaires
//   5.2 — Encours crédit, dépôts et PAR

import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';

/// Service d'export des fichiers plats BCEAO.
///
/// Chaque méthode produit un fichier CSV dans `{appDocDir}/exports/bceao/`
/// avec le séparateur `|` et retourne le chemin absolu du fichier généré.
class BceaoExportService {
  final DatabaseService _db = DatabaseService();
  final _dateDisplay = DateFormat('dd/MM/yyyy');
  final _fileDate = DateFormat('yyyyMMdd');

  // ────────────────────────────────────────────────────────────────────────────
  // 1. Encours crédit
  // ────────────────────────────────────────────────────────────────────────────

  /// Exporte le portefeuille de prêts actifs.
  ///
  /// Colonnes BCEAO :
  /// NUM_PRET | NOM_CLIENT | PRENOM_CLIENT | PRODUIT | MONTANT_INITIAL |
  /// ENCOURS | DATE_DEBLOCAGE | DATE_ECHEANCE | JOURS_RETARD | STATUT
  Future<String> exportEncoursCreditCsv() async {
    final db = await _db.database;
    final legal = await _db.getLegalInformation();

    // Prêts actifs avec informations client
    final rows = await db.rawQuery('''
      SELECT
        p.numero_pret,
        c.nom            AS client_nom,
        c.prenoms        AS client_prenoms,
        pf.nom           AS produit_nom,
        p.montant_initial,
        p.solde_restant,
        p.date_deblocage,
        p.date_echeance_prochaine,
        p.jours_retard,
        p.statut
      FROM prets p
      LEFT JOIN clients c       ON c.id = p.client_id
      LEFT JOIN produits_financiers pf ON pf.id = p.produit_id
      WHERE p.statut NOT IN ('Remboursé', 'Annulé', 'Perdu')
      ORDER BY p.date_deblocage DESC
    ''');

    final buf = StringBuffer();
    _writeFileHeader(
      buf,
      label: 'ENCOURS_CREDIT',
      institution: legal.raisonSociale,
      agrement: legal.numeroAgrement,
    );

    buf.writeln(
      'NUM_PRET|NOM_CLIENT|PRENOM_CLIENT|PRODUIT|'
      'MONTANT_INITIAL|ENCOURS|DATE_DEBLOCAGE|'
      'DATE_ECHEANCE|JOURS_RETARD|STATUT',
    );

    for (final r in rows) {
      buf.writeln(
        '${_col(r["numero_pret"])}|'
        '${_col(r["client_nom"])}|'
        '${_col(r["client_prenoms"])}|'
        '${_col(r["produit_nom"])}|'
        '${_amount(r["montant_initial"])}|'
        '${_amount(r["solde_restant"])}|'
        '${_dateCol(r["date_deblocage"])}|'
        '${_dateCol(r["date_echeance_prochaine"])}|'
        '${r["jours_retard"] ?? 0}|'
        '${_col(r["statut"])}',
      );
    }

    _writeTotals(buf, rows, amountKeys: ['montant_initial', 'solde_restant']);

    final fileName =
        'encours_credit_${_fileDate.format(DateTime.now())}.csv';
    return _saveFile(fileName, buf.toString());
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 2. Dépôts épargne
  // ────────────────────────────────────────────────────────────────────────────

  /// Exporte les soldes des comptes épargne actifs.
  ///
  /// Colonnes BCEAO :
  /// NUM_COMPTE | NOM_CLIENT | PRENOM_CLIENT | TYPE_EPARGNE |
  /// SOLDE | INTERETS_ACQUIS | DATE_OUVERTURE | STATUT
  Future<String> exportDepotsCsv() async {
    final db = await _db.database;
    final legal = await _db.getLegalInformation();

    final rows = await db.rawQuery('''
      SELECT
        ce.numero_compte,
        c.nom            AS client_nom,
        c.prenoms        AS client_prenoms,
        pf.nom           AS type_epargne,
        ce.solde,
        ce.interets_acquis,
        ce.date_ouverture,
        ce.statut
      FROM comptes_epargne ce
      LEFT JOIN clients c       ON c.id = ce.client_id
      LEFT JOIN produits_financiers pf ON pf.id = ce.produit_id
      WHERE ce.statut = 'actif'
      ORDER BY ce.date_ouverture DESC
    ''');

    final buf = StringBuffer();
    _writeFileHeader(
      buf,
      label: 'DEPOTS_EPARGNE',
      institution: legal.raisonSociale,
      agrement: legal.numeroAgrement,
    );

    buf.writeln(
      'NUM_COMPTE|NOM_CLIENT|PRENOM_CLIENT|TYPE_EPARGNE|'
      'SOLDE|INTERETS_ACQUIS|DATE_OUVERTURE|STATUT',
    );

    for (final r in rows) {
      buf.writeln(
        '${_col(r["numero_compte"])}|'
        '${_col(r["client_nom"])}|'
        '${_col(r["client_prenoms"])}|'
        '${_col(r["type_epargne"])}|'
        '${_amount(r["solde"])}|'
        '${_amount(r["interets_acquis"])}|'
        '${_dateCol(r["date_ouverture"])}|'
        '${_col(r["statut"])}',
      );
    }

    _writeTotals(buf, rows, amountKeys: ['solde', 'interets_acquis']);

    final fileName = 'depots_${_fileDate.format(DateTime.now())}.csv';
    return _saveFile(fileName, buf.toString());
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 3. PAR — Portefeuille à Risque
  // ────────────────────────────────────────────────────────────────────────────

  /// Exporte les indicateurs PAR30 et PAR90 du portefeuille.
  ///
  /// Colonnes BCEAO (ligne récapitulative par tranche) :
  /// TRANCHE | NB_PRETS | ENCOURS | TAUX_PAR
  ///
  /// Suivi d'un détail par prêt en retard :
  /// NUM_PRET | NOM_CLIENT | PRENOM_CLIENT | ENCOURS | JOURS_RETARD | TRANCHE_PAR
  Future<String> exportParCsv() async {
    final db = await _db.database;
    final legal = await _db.getLegalInformation();

    // Résumé PAR par tranche
    final summary = await db.rawQuery('''
      SELECT
        COUNT(*) AS nb_prets,
        SUM(solde_restant) AS encours_total,
        SUM(CASE WHEN jours_retard = 0         THEN solde_restant ELSE 0 END) AS enc_sains,
        SUM(CASE WHEN jours_retard BETWEEN 1 AND 30  THEN solde_restant ELSE 0 END) AS enc_par1,
        SUM(CASE WHEN jours_retard BETWEEN 31 AND 90 THEN solde_restant ELSE 0 END) AS enc_par30,
        SUM(CASE WHEN jours_retard > 90              THEN solde_restant ELSE 0 END) AS enc_par90,
        COUNT(CASE WHEN jours_retard = 0         THEN 1 END) AS nb_sains,
        COUNT(CASE WHEN jours_retard BETWEEN 1 AND 30  THEN 1 END) AS nb_par1,
        COUNT(CASE WHEN jours_retard BETWEEN 31 AND 90 THEN 1 END) AS nb_par30,
        COUNT(CASE WHEN jours_retard > 90              THEN 1 END) AS nb_par90
      FROM prets
      WHERE statut NOT IN ('Remboursé', 'Annulé', 'Perdu')
    ''');

    // Détail des prêts en retard
    final detail = await db.rawQuery('''
      SELECT
        p.numero_pret,
        c.nom     AS client_nom,
        c.prenoms AS client_prenoms,
        p.solde_restant,
        p.jours_retard,
        CASE
          WHEN p.jours_retard BETWEEN 1 AND 30  THEN 'PAR1-30'
          WHEN p.jours_retard BETWEEN 31 AND 90 THEN 'PAR30-90'
          WHEN p.jours_retard > 90              THEN 'PAR90+'
          ELSE 'SAIN'
        END AS tranche_par
      FROM prets p
      LEFT JOIN clients c ON c.id = p.client_id
      WHERE p.statut NOT IN ('Remboursé', 'Annulé', 'Perdu')
        AND p.jours_retard > 0
      ORDER BY p.jours_retard DESC
    ''');

    final buf = StringBuffer();
    _writeFileHeader(
      buf,
      label: 'PAR_PORTEFEUILLE',
      institution: legal.raisonSociale,
      agrement: legal.numeroAgrement,
    );

    // ── Bloc récapitulatif ──────────────────────────────────────────────────
    buf.writeln('## RECAPITULATIF PAR TRANCHE');
    buf.writeln('TRANCHE|NB_PRETS|ENCOURS_FCFA|TAUX_PAR_%');

    if (summary.isNotEmpty) {
      final s = summary.first;
      final encTotal = (s['encours_total'] as num?)?.toDouble() ?? 0;

      void _writeParLine(
        String label,
        num? nb,
        num? enc,
        double total,
      ) {
        final encD = enc?.toDouble() ?? 0;
        final taux = total > 0 ? (encD / total) * 100 : 0;
        buf.writeln(
          '$label|${nb ?? 0}|${_amount(enc)}|'
          '${taux.toStringAsFixed(2)}',
        );
      }

      _writeParLine('SAINS',     s['nb_sains'] as num?,  s['enc_sains'] as num?,  encTotal);
      _writeParLine('PAR1-30',   s['nb_par1'] as num?,   s['enc_par1'] as num?,   encTotal);
      _writeParLine('PAR30-90',  s['nb_par30'] as num?,  s['enc_par30'] as num?,  encTotal);
      _writeParLine('PAR90+',    s['nb_par90'] as num?,  s['enc_par90'] as num?,  encTotal);
      buf.writeln(
        'TOTAL|${s['nb_prets']}|${_amount(s['encours_total'])}|100.00',
      );
    }

    // ── Bloc détail ─────────────────────────────────────────────────────────
    buf.writeln();
    buf.writeln('## DETAIL PRETS EN RETARD');
    buf.writeln(
      'NUM_PRET|NOM_CLIENT|PRENOM_CLIENT|ENCOURS|JOURS_RETARD|TRANCHE_PAR',
    );

    for (final r in detail) {
      buf.writeln(
        '${_col(r["numero_pret"])}|'
        '${_col(r["client_nom"])}|'
        '${_col(r["client_prenoms"])}|'
        '${_amount(r["solde_restant"])}|'
        '${r["jours_retard"] ?? 0}|'
        '${_col(r["tranche_par"])}',
      );
    }

    final fileName = 'par_${_fileDate.format(DateTime.now())}.csv';
    return _saveFile(fileName, buf.toString());
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Helpers privés
  // ────────────────────────────────────────────────────────────────────────────

  /// En-tête normalisé BCEAO (4 lignes méta + ligne vide).
  void _writeFileHeader(
    StringBuffer buf, {
    required String label,
    required String institution,
    required String agrement,
  }) {
    buf.writeln('RAPPORT_BCEAO|$label');
    buf.writeln(
      'INSTITUTION|${institution.isNotEmpty ? institution : "N/A"}',
    );
    buf.writeln('AGREMENT|${agrement.isNotEmpty ? agrement : "N/A"}');
    buf.writeln(
      'DATE_EXPORT|${_dateDisplay.format(DateTime.now())}',
    );
    buf.writeln();
  }

  /// Écrit une ligne de totaux pour les colonnes numériques indiquées.
  void _writeTotals(
    StringBuffer buf,
    List<Map<String, dynamic>> rows, {
    required List<String> amountKeys,
  }) {
    final totals = <String, double>{
      for (final k in amountKeys)
        k: rows.fold(
          0.0,
          (sum, r) => sum + ((r[k] as num?)?.toDouble() ?? 0),
        ),
    };

    buf.writeln();
    final totLine = amountKeys
        .map((k) => _amount(totals[k]))
        .join('|');
    buf.writeln('TOTAL|||${List.filled(amountKeys.length - 1, "").join("|")}$totLine');
  }

  /// Sauvegarde le contenu dans `{appDocDir}/exports/bceao/{fileName}`.
  Future<String> _saveFile(String fileName, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports/bceao');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final file = File('${exportDir.path}/$fileName');
    // UTF-8 avec BOM pour compatibilité outils BCEAO/Excel
    final bytes = utf8.encode('\uFEFF$content');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Normalise une valeur de colonne : null → vide, séparateur `|` échappé.
  String _col(dynamic value) {
    if (value == null) return '';
    return value.toString().replaceAll('|', '/');
  }

  /// Formate un montant FCFA sans décimales.
  String _amount(dynamic value) {
    if (value == null) return '0';
    final d = (value as num).toDouble();
    return d.toStringAsFixed(0);
  }

  /// Reformate une date ISO8601 en dd/MM/yyyy, ou retourne vide si null.
  String _dateCol(dynamic value) {
    if (value == null) return '';
    try {
      return _dateDisplay.format(DateTime.parse(value.toString()));
    } catch (_) {
      return value.toString();
    }
  }
}
