"""Domaine comptabilité : comptes_comptables, journaux, ecritures, lignes_ecriture

Revision ID: c9d0e1f2
Revises: b8c9d0e1
Create Date: 2024-01-01
"""

from alembic import op
import sqlalchemy as sa

revision = 'c9d0e1f2'
down_revision = 'b8c9d0e1'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # 1. comptes_comptables                                                #
    # ------------------------------------------------------------------ #
    op.create_table(
        'comptes_comptables',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('numero', sa.String(), nullable=False),
        sa.Column('libelle', sa.String(), nullable=False),
        sa.Column('classe', sa.Integer(), nullable=False),
        sa.Column('type', sa.String(), nullable=False),  # ACTIF, PASSIF, CHARGE, PRODUIT
        sa.Column('parent_account', sa.String(), nullable=True),
        sa.Column('is_title', sa.Boolean(), default=False),
    )
    op.create_index(
        'ix_comptes_comptables_numero',
        'comptes_comptables',
        ['numero'],
        unique=True,
    )

    # ------------------------------------------------------------------ #
    # 2. journaux                                                          #
    # ------------------------------------------------------------------ #
    op.create_table(
        'journaux',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('code', sa.String(), nullable=False),
        sa.Column('libelle', sa.String(), nullable=False),
    )
    op.create_index(
        'ix_journaux_code',
        'journaux',
        ['code'],
        unique=True,
    )

    # ------------------------------------------------------------------ #
    # 3. ecritures                                                         #
    # ------------------------------------------------------------------ #
    op.create_table(
        'ecritures',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('date_comptable', sa.DateTime(), nullable=False),
        sa.Column('journal_code', sa.String(), nullable=True),
        sa.Column('numero_piece', sa.String(), nullable=True),
        sa.Column('libelle', sa.Text(), nullable=True),
        sa.Column('agent_saisie', sa.String(), nullable=True),
        sa.Column('statut', sa.String(), default='BROUILLON'),  # BROUILLON, VALIDE
        sa.Column('date_saisie', sa.DateTime(), nullable=True),
        sa.Column('piece_jointe', sa.String(), nullable=True),
    )

    # ------------------------------------------------------------------ #
    # 4. lignes_ecriture  (FK interne → ecritures.id)                     #
    # ------------------------------------------------------------------ #
    op.create_table(
        'lignes_ecriture',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            'ecriture_id',
            sa.Integer(),
            sa.ForeignKey('ecritures.id', ondelete='CASCADE'),
            nullable=True,
        ),
        sa.Column('compte_numero', sa.String(), nullable=True),
        sa.Column('libelle_ligne', sa.Text(), nullable=True),
        sa.Column('debit', sa.Float(), default=0.0),
        sa.Column('credit', sa.Float(), default=0.0),
        sa.Column('ref_externe', sa.String(), nullable=True),
        sa.Column('tiers', sa.String(), nullable=True),
        sa.Column('ref_analytique', sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table('lignes_ecriture')
    op.drop_table('ecritures')
    op.drop_index('ix_journaux_code', table_name='journaux')
    op.drop_table('journaux')
    op.drop_index('ix_comptes_comptables_numero', table_name='comptes_comptables')
    op.drop_table('comptes_comptables')
