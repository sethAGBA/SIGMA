"""Domaine clients : clients

Revision ID: d4e5f6a7
Revises: c3d4e5f6
Create Date: 2024-01-01
"""

from alembic import op
import sqlalchemy as sa

revision = 'd4e5f6a7'
down_revision = 'c3d4e5f6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'clients',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('numero_client', sa.String(), nullable=False),
        sa.Column('nom', sa.String(), nullable=False),
        sa.Column('prenoms', sa.String(), nullable=False),
        sa.Column('date_naissance', sa.DateTime(), nullable=True),
        sa.Column('lieu_naissance', sa.String(), nullable=True),
        sa.Column('sexe', sa.String(), nullable=True),
        sa.Column('numero_cni', sa.String(), nullable=True),
        sa.Column('numero_passeport', sa.String(), nullable=True),
        sa.Column('telephone', sa.String(), nullable=True),
        sa.Column('email', sa.String(), nullable=True),
        sa.Column('whatsapp', sa.String(), nullable=True),
        sa.Column('adresse', sa.String(), nullable=True),
        sa.Column('situation_familiale', sa.String(), nullable=True),
        sa.Column('nombre_enfants', sa.Integer(), nullable=True),
        sa.Column('type_logement', sa.String(), nullable=True),
        sa.Column('description_logement', sa.Text(), nullable=True),
        sa.Column('langues_parlees', sa.String(), nullable=True),
        sa.Column('reference_nom_1', sa.String(), nullable=True),
        sa.Column('reference_tel_1', sa.String(), nullable=True),
        sa.Column('reference_relation_1', sa.String(), nullable=True),
        sa.Column('reference_nom_2', sa.String(), nullable=True),
        sa.Column('reference_tel_2', sa.String(), nullable=True),
        sa.Column('reference_relation_2', sa.String(), nullable=True),
        sa.Column('activite_principale', sa.String(), nullable=True),
        sa.Column('activites_secondaires', sa.Text(), nullable=True),
        sa.Column('revenus_mensuels', sa.Float(), nullable=True),
        sa.Column('charges_mensuelles', sa.Float(), nullable=True),
        sa.Column('capacite_remboursement', sa.Float(), nullable=True),
        sa.Column('anciennete_activite', sa.Integer(), nullable=True),
        sa.Column('lieu_exercice_activite', sa.String(), nullable=True),
        sa.Column('description_activite', sa.Text(), nullable=True),
        sa.Column('biens_patrimoine', sa.Text(), nullable=True),
        sa.Column('groupe_solidaire_id', sa.Integer(), nullable=True),
        sa.Column('caution_solidaire_active', sa.Boolean(), default=False),
        sa.Column('score_credit', sa.Integer(), default=50),
        sa.Column('niveau_risque', sa.String(), default='Moyen'),
        sa.Column('capacite_endettement', sa.Float(), nullable=True),
        sa.Column('taux_endettement', sa.Float(), nullable=True),
        sa.Column('montant_max_autorise', sa.Float(), nullable=True),
        sa.Column('date_creation', sa.DateTime(), nullable=True),
        sa.Column('agence', sa.String(), nullable=True),
        sa.Column('agent_affecte', sa.String(), nullable=True),
        sa.Column('photo_path', sa.String(), nullable=True),
        sa.Column('document_cni_path', sa.String(), nullable=True),
        sa.Column('document_justif_domicile_path', sa.String(), nullable=True),
        sa.Column('photo_commerce_path', sa.String(), nullable=True),
        sa.Column('photo_domicile_path', sa.String(), nullable=True),
        sa.Column('latitude', sa.Float(), nullable=True),
        sa.Column('longitude', sa.Float(), nullable=True),
        sa.Column('statut', sa.String(), default='Actif'),
        sa.Column('date_evaluation', sa.DateTime(), nullable=True),
        sa.Column('epargne_obligatoire_ouverte', sa.Boolean(), default=False),
    )
    op.create_index('ix_clients_numero_client', 'clients', ['numero_client'], unique=True)


def downgrade() -> None:
    op.drop_index('ix_clients_numero_client', table_name='clients')
    op.drop_table('clients')
