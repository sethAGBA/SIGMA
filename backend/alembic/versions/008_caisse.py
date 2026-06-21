"""Domaine caisse : operations_caisse, clotures_caisse

Revision ID: b8c9d0e1
Revises: a7b8c9d0
Create Date: 2024-01-01
"""

from alembic import op
import sqlalchemy as sa

revision = 'b8c9d0e1'
down_revision = 'a7b8c9d0'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # 1. operations_caisse                                                 #
    # ------------------------------------------------------------------ #
    op.create_table(
        'operations_caisse',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('agence_id', sa.String(), nullable=True),
        sa.Column('type_operation', sa.String(), nullable=True),  # ENTREE, SORTIE
        sa.Column('categorie', sa.String(), nullable=True),
        sa.Column('montant', sa.Float(), nullable=True),
        sa.Column('devise', sa.String(), nullable=True),
        sa.Column('mode_paiement', sa.String(), nullable=True),
        sa.Column('libelle', sa.String(), nullable=True),
        sa.Column('reference_externe', sa.String(), nullable=True),
        sa.Column('agent_operation', sa.String(), nullable=True),
        sa.Column('date_operation', sa.DateTime(), nullable=True),
    )

    # ------------------------------------------------------------------ #
    # 2. clotures_caisse                                                   #
    # ------------------------------------------------------------------ #
    op.create_table(
        'clotures_caisse',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('date_cloture', sa.DateTime(), nullable=False),
        sa.Column('agent_cloture', sa.String(), nullable=False),
        sa.Column('solde_initial', sa.Float(), nullable=True),
        sa.Column('total_entrees', sa.Float(), nullable=True),
        sa.Column('total_sorties', sa.Float(), nullable=True),
        sa.Column('solde_theorique', sa.Float(), nullable=True),
        sa.Column('solde_physique', sa.Float(), nullable=True),
        sa.Column('ecart', sa.Float(), nullable=True),
        sa.Column('observations', sa.Text(), nullable=True),
        sa.Column('billetage', sa.Text(), nullable=True),  # JSON des coupures physiques
    )


def downgrade() -> None:
    op.drop_table('clotures_caisse')
    op.drop_table('operations_caisse')
