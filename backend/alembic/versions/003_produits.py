"""Domaine produits : produits_financiers

Revision ID: c3d4e5f6
Revises: b2c3d4e5
Create Date: 2024-01-01
"""

from alembic import op
import sqlalchemy as sa

revision = 'c3d4e5f6'
down_revision = 'b2c3d4e5'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'produits_financiers',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('nom', sa.String(), nullable=False),
        sa.Column('code', sa.String(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('type', sa.String(), nullable=False),
        sa.Column('taux_interet', sa.Float(), nullable=True),
        sa.Column('credit_category', sa.String(), nullable=True),
        sa.Column('montant_min', sa.Float(), nullable=True),
        sa.Column('montant_max', sa.Float(), nullable=True),
        sa.Column('duree_min_mois', sa.Integer(), nullable=True),
        sa.Column('duree_max_mois', sa.Integer(), nullable=True),
        sa.Column('mode_calcul_interet', sa.String(), nullable=True),
        sa.Column('frequence_remboursement', sa.String(), nullable=True),
        sa.Column('conditions_eligibilite', sa.Text(), nullable=True),
        sa.Column('documents_requis', sa.Text(), nullable=True),
        sa.Column('frais_commissions', sa.Text(), nullable=True),
        sa.Column('assurances_obligatoires', sa.Text(), nullable=True),
        sa.Column('differe_possible', sa.Boolean(), default=False),
        sa.Column('secteurs_eligibles', sa.Text(), nullable=True),
        sa.Column('materiel_financable', sa.Text(), nullable=True),
        sa.Column('accompagnement_technique', sa.Text(), nullable=True),
        sa.Column('garantie_sur_equipement', sa.Text(), nullable=True),
        sa.Column('procedure_acceleree', sa.Boolean(), default=False),
        sa.Column('caution_solidaire_requise', sa.Boolean(), default=False),
        sa.Column('savings_category', sa.String(), nullable=True),
        sa.Column('solde_minimum', sa.Float(), nullable=True),
        sa.Column('versement_minimum', sa.Float(), nullable=True),
    )
    op.create_index('ix_produits_financiers_code', 'produits_financiers', ['code'], unique=True)


def downgrade() -> None:
    op.drop_index('ix_produits_financiers_code', table_name='produits_financiers')
    op.drop_table('produits_financiers')
