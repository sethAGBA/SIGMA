"""Domaine prêts et remboursements : demandes_pret, prets, echeanciers, garanties,
remboursements, actions_recouvrement

Revision ID: f6a7b8c9
Revises: e5f6a7b8
Create Date: 2024-01-01
"""

from alembic import op
import sqlalchemy as sa

revision = 'f6a7b8c9'
down_revision = 'e5f6a7b8'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # 1. demandes_pret                                                     #
    # ------------------------------------------------------------------ #
    op.create_table(
        'demandes_pret',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('client_id', sa.Integer(),
                  sa.ForeignKey('clients.id'), nullable=True),
        sa.Column('produit_id', sa.Integer(),
                  sa.ForeignKey('produits_financiers.id'), nullable=True),
        sa.Column('montant_demande', sa.Float(), nullable=True),
        sa.Column('duree_mois', sa.Integer(), nullable=True),
        sa.Column('frequence_remboursement', sa.String(), nullable=True),
        sa.Column('objet_pret', sa.Text(), nullable=True),
        sa.Column('mensualite', sa.Float(), nullable=True),
        sa.Column('total_a_rembourser', sa.Float(), nullable=True),
        sa.Column('cout_total_credit', sa.Float(), nullable=True),
        sa.Column('teg', sa.Float(), nullable=True),
        sa.Column('revenus_mensuels', sa.Float(), nullable=True),
        sa.Column('charges_mensuelles', sa.Float(), nullable=True),
        sa.Column('capacite_remboursement', sa.Float(), nullable=True),
        sa.Column('taux_effort', sa.Float(), nullable=True),
        sa.Column('autres_dettes', sa.Float(), nullable=True),
        sa.Column('reste_a_vivre', sa.Float(), nullable=True),
        sa.Column('type_garantie', sa.String(), nullable=True),
        sa.Column('description_garantie', sa.Text(), nullable=True),
        sa.Column('valeur_garantie', sa.Float(), nullable=True),
        sa.Column('caution_personnelle', sa.Text(), nullable=True),
        sa.Column('rapport_visite', sa.Text(), nullable=True),
        sa.Column('observations_visite', sa.Text(), nullable=True),
        sa.Column('photos_visite', sa.Text(), nullable=True),
        sa.Column('score_calcule', sa.Integer(), nullable=True),
        sa.Column('recommandation_systeme', sa.Text(), nullable=True),
        sa.Column('avis_agent', sa.Text(), nullable=True),
        sa.Column('avis_chef_agence', sa.Text(), nullable=True),
        sa.Column('avis_comite', sa.Text(), nullable=True),
        sa.Column('documents_dossier', sa.Text(), nullable=True),
        sa.Column('statut', sa.String(), nullable=True),
        sa.Column('date_creation', sa.DateTime(), nullable=True),
        sa.Column('date_modification', sa.DateTime(), nullable=True),
        sa.Column('motif_rejet', sa.Text(), nullable=True),
    )

    # ------------------------------------------------------------------ #
    # 2. prets                                                             #
    # ------------------------------------------------------------------ #
    op.create_table(
        'prets',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('demande_pret_id', sa.Integer(),
                  sa.ForeignKey('demandes_pret.id'), nullable=True),
        sa.Column('client_id', sa.Integer(),
                  sa.ForeignKey('clients.id'), nullable=True),
        sa.Column('produit_id', sa.Integer(),
                  sa.ForeignKey('produits_financiers.id'), nullable=True),
        sa.Column('groupe_id', sa.Integer(),
                  sa.ForeignKey('groupes_solidaires.id'), nullable=True),
        sa.Column('numero_pret', sa.String(), nullable=False),
        sa.Column('montant_initial', sa.Float(), nullable=True),
        sa.Column('solde_restant', sa.Float(), nullable=True),
        sa.Column('date_deblocage', sa.DateTime(), nullable=True),
        sa.Column('date_echeance_prochaine', sa.DateTime(), nullable=True),
        sa.Column('jours_retard', sa.Integer(), default=0),
        sa.Column('statut', sa.String(), nullable=True),
        sa.Column('agent_gestionnaire', sa.String(), nullable=True),
        sa.Column('agence_gestion', sa.String(), nullable=True),
    )
    op.create_index('ix_prets_numero_pret', 'prets', ['numero_pret'], unique=True)

    # ------------------------------------------------------------------ #
    # 3. echeanciers                                                       #
    # ------------------------------------------------------------------ #
    op.create_table(
        'echeanciers',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('pret_id', sa.Integer(),
                  sa.ForeignKey('prets.id', ondelete='CASCADE'), nullable=False),
        sa.Column('numero_echeance', sa.Integer(), nullable=False),
        sa.Column('date_prevue', sa.DateTime(), nullable=True),
        sa.Column('capital_du', sa.Float(), nullable=True),
        sa.Column('interets_dus', sa.Float(), nullable=True),
        sa.Column('frais_dus', sa.Float(), default=0.0),
        sa.Column('total_du', sa.Float(), nullable=True),
        sa.Column('capital_paye', sa.Float(), default=0.0),
        sa.Column('interets_payes', sa.Float(), default=0.0),
        sa.Column('frais_payes', sa.Float(), default=0.0),
        sa.Column('total_paye', sa.Float(), default=0.0),
        sa.Column('capital_restant', sa.Float(), nullable=True),
        sa.Column('statut', sa.String(), nullable=True),
        sa.Column('date_effectuee', sa.DateTime(), nullable=True),
    )

    # ------------------------------------------------------------------ #
    # 4. garanties                                                         #
    # ------------------------------------------------------------------ #
    op.create_table(
        'garanties',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('pret_id', sa.Integer(),
                  sa.ForeignKey('prets.id', ondelete='CASCADE'), nullable=True),
        sa.Column('type', sa.String(), nullable=False),
        sa.Column('valeur_estimee', sa.Float(), nullable=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('date_creation', sa.DateTime(), nullable=True),
    )

    # ------------------------------------------------------------------ #
    # 5. remboursements                                                    #
    # ------------------------------------------------------------------ #
    op.create_table(
        'remboursements',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('pret_id', sa.Integer(),
                  sa.ForeignKey('prets.id'), nullable=True),
        sa.Column('echeance_id', sa.Integer(),
                  sa.ForeignKey('echeanciers.id'), nullable=True),
        sa.Column('montant_total', sa.Float(), nullable=True),
        sa.Column('part_capital', sa.Float(), nullable=True),
        sa.Column('part_interets', sa.Float(), nullable=True),
        sa.Column('part_penalites', sa.Float(), default=0.0),
        sa.Column('date_paiement', sa.DateTime(), nullable=True),
        sa.Column('mode_paiement', sa.String(), nullable=True),
        sa.Column('numero_recu', sa.String(), nullable=False),
        sa.Column('agent_collecteur', sa.String(), nullable=True),
        sa.Column('commentaire', sa.Text(), nullable=True),
    )
    op.create_index('ix_remboursements_numero_recu', 'remboursements', ['numero_recu'], unique=True)

    # ------------------------------------------------------------------ #
    # 6. actions_recouvrement                                              #
    # ------------------------------------------------------------------ #
    op.create_table(
        'actions_recouvrement',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('pret_id', sa.Integer(),
                  sa.ForeignKey('prets.id'), nullable=False),
        sa.Column('date_action', sa.DateTime(), nullable=False),
        sa.Column('type_action', sa.String(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('agent_name', sa.String(), nullable=True),
        sa.Column('resultat', sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table('actions_recouvrement')
    op.drop_index('ix_remboursements_numero_recu', table_name='remboursements')
    op.drop_table('remboursements')
    op.drop_table('garanties')
    op.drop_table('echeanciers')
    op.drop_index('ix_prets_numero_pret', table_name='prets')
    op.drop_table('prets')
    op.drop_table('demandes_pret')
