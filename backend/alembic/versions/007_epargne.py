"""Domaine épargne : comptes_epargne, transactions_epargne

Revision ID: a7b8c9d0
Revises: f6a7b8c9
Create Date: 2024-01-01
"""

from alembic import op
import sqlalchemy as sa

revision = 'a7b8c9d0'
down_revision = 'f6a7b8c9'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # 1. comptes_epargne                                                   #
    # ------------------------------------------------------------------ #
    op.create_table(
        'comptes_epargne',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('client_id', sa.Integer(),
                  sa.ForeignKey('clients.id'), nullable=True),
        sa.Column('produit_id', sa.Integer(),
                  sa.ForeignKey('produits_financiers.id'), nullable=True),
        sa.Column('numero_compte', sa.String(), nullable=False),
        sa.Column('solde', sa.Float(), default=0.0),
        sa.Column('interets_acquis', sa.Float(), default=0.0),
        sa.Column('statut', sa.String(), nullable=True),
        sa.Column('date_ouverture', sa.DateTime(), nullable=True),
        sa.Column('taux_interet_applique', sa.Float(), nullable=True),
    )
    op.create_index('ix_comptes_epargne_numero_compte', 'comptes_epargne', ['numero_compte'], unique=True)

    # ------------------------------------------------------------------ #
    # 2. transactions_epargne                                              #
    # ------------------------------------------------------------------ #
    op.create_table(
        'transactions_epargne',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('compte_id', sa.Integer(),
                  sa.ForeignKey('comptes_epargne.id'), nullable=True),
        sa.Column('type_operation', sa.String(), nullable=True),
        sa.Column('montant', sa.Float(), nullable=True),
        sa.Column('solde_apres', sa.Float(), nullable=True),
        sa.Column('agent_operation', sa.String(), nullable=True),
        sa.Column('date_operation', sa.DateTime(), nullable=True),
        sa.Column('numero_piece', sa.String(), nullable=True),
        sa.Column('commentaire', sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table('transactions_epargne')
    op.drop_index('ix_comptes_epargne_numero_compte', table_name='comptes_epargne')
    op.drop_table('comptes_epargne')
