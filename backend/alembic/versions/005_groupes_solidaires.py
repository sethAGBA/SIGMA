"""Domaine groupes solidaires : groupes_solidaires, groupe_membres

Revision ID: e5f6a7b8
Revises: d4e5f6a7
Create Date: 2024-01-01
"""

from alembic import op
import sqlalchemy as sa

revision = 'e5f6a7b8'
down_revision = 'd4e5f6a7'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'groupes_solidaires',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('code', sa.String(), nullable=False),
        sa.Column('nom', sa.String(), nullable=False),
        sa.Column('responsable_id', sa.Integer(), sa.ForeignKey('clients.id'), nullable=True),
        sa.Column('tresorier_id', sa.Integer(), sa.ForeignKey('clients.id'), nullable=True),
        sa.Column('date_creation', sa.DateTime(), nullable=True),
        sa.Column('statut', sa.String(), default='Actif'),
        sa.Column('description', sa.Text(), nullable=True),
    )
    op.create_index('ix_groupes_solidaires_code', 'groupes_solidaires', ['code'], unique=True)

    op.create_table(
        'groupe_membres',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('groupe_id', sa.Integer(), sa.ForeignKey('groupes_solidaires.id'), nullable=False),
        sa.Column('client_id', sa.Integer(), sa.ForeignKey('clients.id'), nullable=False),
        sa.Column('role', sa.String(), nullable=True),
        sa.Column('date_adhesion', sa.DateTime(), nullable=True),
    )
    op.create_index('ix_groupe_membres_groupe_client', 'groupe_membres', ['groupe_id', 'client_id'], unique=True)


def downgrade() -> None:
    op.drop_index('ix_groupe_membres_groupe_client', table_name='groupe_membres')
    op.drop_table('groupe_membres')
    op.drop_index('ix_groupes_solidaires_code', table_name='groupes_solidaires')
    op.drop_table('groupes_solidaires')
