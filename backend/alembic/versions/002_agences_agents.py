"""Domaine agences et agents : agencies, agents

Revision ID: b2c3d4e5
Revises: a1b2c3d4
Create Date: 2024-01-01
"""

from alembic import op
import sqlalchemy as sa

revision = 'b2c3d4e5'
down_revision = 'a1b2c3d4'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'agencies',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('code', sa.String(), nullable=False),
        sa.Column('address', sa.String(), nullable=True),
        sa.Column('phone', sa.String(), nullable=True),
        sa.Column('email', sa.String(), nullable=True),
        sa.Column('latitude', sa.Float(), nullable=True),
        sa.Column('longitude', sa.Float(), nullable=True),
        sa.Column('coverage_area', sa.String(), nullable=True),
        sa.Column('opening_date', sa.DateTime(), nullable=True),
        sa.Column('is_active', sa.Boolean(), default=True),
    )
    op.create_index('ix_agencies_code', 'agencies', ['code'], unique=True)

    op.create_table(
        'agents',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('first_name', sa.String(), nullable=False),
        sa.Column('last_name', sa.String(), nullable=False),
        sa.Column('email', sa.String(), nullable=True),
        sa.Column('phone', sa.String(), nullable=True),
        sa.Column('role', sa.String(), nullable=False),
        sa.Column('agency_id', sa.String(), sa.ForeignKey('agencies.id'), nullable=True),
        sa.Column('is_active', sa.Boolean(), default=True),
        sa.Column('photo_url', sa.String(), nullable=True),
        sa.Column('hired_date', sa.DateTime(), nullable=True),
        sa.Column('associated_account_id', sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table('agents')
    op.drop_index('ix_agencies_code', table_name='agencies')
    op.drop_table('agencies')
