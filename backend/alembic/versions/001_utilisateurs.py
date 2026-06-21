"""Domaine utilisateurs : utilisateurs_systeme

Revision ID: a1b2c3d4
Revises: None
Create Date: 2024-01-01
"""

from alembic import op
import sqlalchemy as sa

revision = 'a1b2c3d4'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'utilisateurs_systeme',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('agent_id', sa.String(), nullable=False),
        sa.Column('username', sa.String(), nullable=False),
        sa.Column('password_hash', sa.String(), nullable=False),
        sa.Column('role', sa.String(), nullable=False),
        sa.Column('is_active', sa.Boolean(), default=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('permissions', sa.Text(), nullable=True),
        sa.Column('last_login', sa.DateTime(), nullable=True),
    )
    op.create_index('ix_utilisateurs_username', 'utilisateurs_systeme', ['username'], unique=True)


def downgrade() -> None:
    op.drop_index('ix_utilisateurs_username', table_name='utilisateurs_systeme')
    op.drop_table('utilisateurs_systeme')
