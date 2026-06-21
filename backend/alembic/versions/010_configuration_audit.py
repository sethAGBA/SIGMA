"""Domaine configuration et audit : configurations, audit_logs

Revision ID: d0e1f2a3
Revises: c9d0e1f2
Create Date: 2024-01-01
"""

from alembic import op
import sqlalchemy as sa

revision = 'd0e1f2a3'
down_revision = 'c9d0e1f2'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'configurations',
        sa.Column('key', sa.String(), primary_key=True),
        sa.Column('value', sa.Text(), nullable=True),
    )

    op.create_table(
        'audit_logs',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('user_id', sa.String(), nullable=True),
        sa.Column('username', sa.String(), nullable=True),
        sa.Column('action', sa.String(), nullable=False),
        sa.Column('details', sa.Text(), nullable=True),
        sa.Column('timestamp', sa.DateTime(), nullable=True),
        sa.Column('severity', sa.String(), nullable=False),
        sa.Column('ip_address', sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table('audit_logs')
    op.drop_table('configurations')
