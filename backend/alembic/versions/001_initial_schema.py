"""Initial schema for JobEval.

Revision ID: 001
Revises: 
Create Date: 2024-01-15 10:00:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create enum types
    op.execute("CREATE TYPE project_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'archived')")
    op.execute("CREATE TYPE job_stage AS ENUM ('queued', 'importing', 'analyzing', 'recognizing', 'drawing', 'manufacturing', 'estimating', 'reporting', 'completed', 'failed')")
    op.execute("CREATE TYPE file_role AS ENUM ('model_3d', 'drawing_2d', 'reference')")
    op.execute("CREATE TYPE file_status AS ENUM ('uploaded', 'processing', 'processed', 'failed')")

    # Projects table
    op.create_table(
        'projects',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('uuid_generate_v4()')),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('description', sa.Text, nullable=True),
        sa.Column('status', sa.Enum('pending', 'processing', 'completed', 'failed', 'archived', name='project_status'), nullable=False, server_default='pending'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('idx_projects_status', 'projects', ['status'])
    op.create_index('idx_projects_created_at', 'projects', ['created_at'])

    # Project files table
    op.create_table(
        'project_files',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('uuid_generate_v4()')),
        sa.Column('project_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('projects.id', ondelete='CASCADE'), nullable=False),
        sa.Column('filename', sa.String(255), nullable=False),
        sa.Column('original_filename', sa.String(255), nullable=False),
        sa.Column('mime_type', sa.String(100), nullable=False),
        sa.Column('size_bytes', sa.BigInteger, nullable=False),
        sa.Column('role', sa.Enum('model_3d', 'drawing_2d', 'reference', name='file_role'), nullable=False),
        sa.Column('status', sa.Enum('uploaded', 'processing', 'processed', 'failed', name='file_status'), nullable=False, server_default='uploaded'),
        sa.Column('sha256', sa.String(64), nullable=True),
        sa.Column('object_key', sa.String(512), nullable=True),
        sa.Column('uploaded_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('processed_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('idx_project_files_project_id', 'project_files', ['project_id'])
    op.create_index('idx_project_files_status', 'project_files', ['status'])

    # Job status table
    op.create_table(
        'job_status',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('uuid_generate_v4()')),
        sa.Column('project_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('projects.id', ondelete='CASCADE'), nullable=False),
        sa.Column('stage', sa.Enum('queued', 'importing', 'analyzing', 'recognizing', 'drawing', 'manufacturing', 'estimating', 'reporting', 'completed', 'failed', name='job_stage'), nullable=False, server_default='queued'),
        sa.Column('progress', sa.Numeric(5, 2), nullable=False, server_default='0.0'),
        sa.Column('current_step', sa.String(255), nullable=True),
        sa.Column('error', sa.Text, nullable=True),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('idx_job_status_project_id', 'job_status', ['project_id'])
    op.create_index('idx_job_status_stage', 'job_status', ['stage'])

    # CAD specs table
    op.create_table(
        'cad_specs',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('uuid_generate_v4()')),
        sa.Column('project_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('projects.id', ondelete='CASCADE'), nullable=False),
        sa.Column('version', sa.String(20), nullable=False, server_default='1.0'),
        sa.Column('data', postgresql.JSONB, nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('idx_cad_specs_project_id', 'cad_specs', ['project_id'])
    op.create_index('idx_cad_specs_data_gin', 'cad_specs', ['data'], postgresql_using='gin')

    # Manufacturing analysis table
    op.create_table(
        'manufacturing_analysis',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('uuid_generate_v4()')),
        sa.Column('project_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('projects.id', ondelete='CASCADE'), nullable=False),
        sa.Column('data', postgresql.JSONB, nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('idx_manufacturing_analysis_project_id', 'manufacturing_analysis', ['project_id'])

    # Cost estimates table
    op.create_table(
        'cost_estimates',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('uuid_generate_v4()')),
        sa.Column('project_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('projects.id', ondelete='CASCADE'), nullable=False),
        sa.Column('data', postgresql.JSONB, nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('idx_cost_estimates_project_id', 'cost_estimates', ['project_id'])

    # Reports table
    op.create_table(
        'reports',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('uuid_generate_v4()')),
        sa.Column('project_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('projects.id', ondelete='CASCADE'), nullable=False),
        sa.Column('template', sa.String(50), nullable=False),
        sa.Column('format', sa.String(20), nullable=False),
        sa.Column('status', sa.String(20), nullable=False, server_default='pending'),
        sa.Column('download_url', sa.String(512), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('idx_reports_project_id', 'reports', ['project_id'])

    # Materials table
    op.create_table(
        'materials',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('uuid_generate_v4()')),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('grade', sa.String(50), nullable=True),
        sa.Column('standard', sa.String(50), nullable=True),
        sa.Column('category', sa.String(50), nullable=False),
        sa.Column('density_kg_m3', sa.Numeric(10, 2), nullable=False),
        sa.Column('properties', postgresql.JSONB, nullable=False, server_default='{}'),
        sa.Column('is_active', sa.Boolean, nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('idx_materials_category', 'materials', ['category'])
    op.create_index('idx_materials_name', 'materials', ['name'])

    # Material pricing table
    op.create_table(
        'material_pricing',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('uuid_generate_v4()')),
        sa.Column('material_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('materials.id', ondelete='CASCADE'), nullable=False),
        sa.Column('region', sa.String(100), nullable=False),
        sa.Column('supplier', sa.String(255), nullable=True),
        sa.Column('stock_dimensions', postgresql.JSONB, nullable=True),
        sa.Column('stock_weight_kg', sa.Numeric(10, 2), nullable=True),
        sa.Column('price_per_kg', sa.Numeric(10, 2), nullable=True),
        sa.Column('price_total', sa.Numeric(10, 2), nullable=True),
        sa.Column('currency', sa.String(3), nullable=False, server_default='USD'),
        sa.Column('availability', sa.String(50), nullable=False, server_default='unknown'),
        sa.Column('lead_time_days', sa.Integer, nullable=True),
        sa.Column('last_updated', sa.DateTime(timezone=True), nullable=True),
        sa.Column('is_verified', sa.Boolean, nullable=False, server_default='false'),
        sa.Column('notes', postgresql.JSONB, nullable=False, server_default='[]'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('idx_material_pricing_material_id', 'material_pricing', ['material_id'])
    op.create_index('idx_material_pricing_region', 'material_pricing', ['region'])

    # Users table
    op.create_table(
        'users',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('uuid_generate_v4()')),
        sa.Column('email', sa.String(255), nullable=False, unique=True),
        sa.Column('password_hash', sa.String(255), nullable=False),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('role', sa.String(50), nullable=False, server_default='engineer'),
        sa.Column('avatar_url', sa.String(512), nullable=True),
        sa.Column('is_active', sa.Boolean, nullable=False, server_default='true'),
        sa.Column('last_login', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('idx_users_email', 'users', ['email'])

    # API keys table
    op.create_table(
        'api_keys',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('uuid_generate_v4()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('key_hash', sa.String(255), nullable=False),
        sa.Column('key_prefix', sa.String(20), nullable=False),
        sa.Column('scopes', postgresql.JSONB, nullable=False, server_default='[]'),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('last_used_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('idx_api_keys_user_id', 'api_keys', ['user_id'])

    # Create trigger function for updated_at
    op.execute("""
        CREATE OR REPLACE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
    """)

    # Add triggers
    for table in ['projects', 'job_status', 'cad_specs', 'manufacturing_analysis', 'cost_estimates', 'materials', 'users']:
        op.execute(f"""
            DROP TRIGGER IF EXISTS update_{table}_updated_at ON {table};
            CREATE TRIGGER update_{table}_updated_at
                BEFORE UPDATE ON {table}
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
        """)


def downgrade() -> None:
    # Drop triggers
    for table in ['users', 'materials', 'cost_estimates', 'manufacturing_analysis', 'cad_specs', 'job_status', 'projects']:
        op.execute(f"DROP TRIGGER IF EXISTS update_{table}_updated_at ON {table};")

    op.execute("DROP FUNCTION IF EXISTS update_updated_at_column()")

    # Drop tables in reverse order
    op.drop_table('api_keys')
    op.drop_table('users')
    op.drop_table('material_pricing')
    op.drop_table('materials')
    op.drop_table('reports')
    op.drop_table('cost_estimates')
    op.drop_table('manufacturing_analysis')
    op.drop_table('cad_specs')
    op.drop_table('job_status')
    op.drop_table('project_files')
    op.drop_table('projects')

    # Drop enum types
    op.execute("DROP TYPE IF EXISTS file_status")
    op.execute("DROP TYPE IF EXISTS file_role")
    op.execute("DROP TYPE IF EXISTS job_stage")
    op.execute("DROP TYPE IF EXISTS project_status")