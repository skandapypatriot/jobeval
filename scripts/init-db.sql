-- JobEval Database Initialization
-- Run on PostgreSQL startup

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create enum types
DO $$ BEGIN
    CREATE TYPE project_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'archived');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE job_stage AS ENUM ('queued', 'importing', 'analyzing', 'recognizing', 'drawing', 'manufacturing', 'estimating', 'reporting', 'completed', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE file_role AS ENUM ('model_3d', 'drawing_2d', 'reference');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE file_status AS ENUM ('uploaded', 'processing', 'processed', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Projects table
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status project_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_created_at ON projects(created_at DESC);

-- Project files table
CREATE TABLE IF NOT EXISTS project_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    filename VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL,
    role file_role NOT NULL,
    status file_status NOT NULL DEFAULT 'uploaded',
    sha256 VARCHAR(64),
    object_key VARCHAR(512),
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_project_files_project_id ON project_files(project_id);
CREATE INDEX IF NOT EXISTS idx_project_files_status ON project_files(status);

-- Job status table
CREATE TABLE IF NOT EXISTS job_status (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    stage job_stage NOT NULL DEFAULT 'queued',
    progress DECIMAL(5,2) NOT NULL DEFAULT 0.0,
    current_step VARCHAR(255),
    error TEXT,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_job_status_project_id ON job_status(project_id);
CREATE INDEX IF NOT EXISTS idx_job_status_stage ON job_status(stage);

-- CAD specs table (JSONB for flexible schema)
CREATE TABLE IF NOT EXISTS cad_specs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    version VARCHAR(20) NOT NULL DEFAULT '1.0',
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cad_specs_project_id ON cad_specs(project_id);
CREATE INDEX IF NOT EXISTS idx_cad_specs_data_gin ON cad_specs USING GIN(data);

-- Manufacturing analysis table
CREATE TABLE IF NOT EXISTS manufacturing_analysis (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_manufacturing_analysis_project_id ON manufacturing_analysis(project_id);

-- Cost estimates table
CREATE TABLE IF NOT EXISTS cost_estimates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cost_estimates_project_id ON cost_estimates(project_id);

-- Reports table
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    template VARCHAR(50) NOT NULL,
    format VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    download_url VARCHAR(512),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_reports_project_id ON reports(project_id);

-- Materials table
CREATE TABLE IF NOT EXISTS materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    grade VARCHAR(50),
    standard VARCHAR(50),
    category VARCHAR(50) NOT NULL,
    density_kg_m3 DECIMAL(10,2) NOT NULL,
    properties JSONB DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_materials_category ON materials(category);
CREATE INDEX IF NOT EXISTS idx_materials_name ON materials(name);

-- Material pricing table
CREATE TABLE IF NOT EXISTS material_pricing (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    material_id UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
    region VARCHAR(100) NOT NULL,
    supplier VARCHAR(255),
    stock_dimensions JSONB,
    stock_weight_kg DECIMAL(10,2),
    price_per_kg DECIMAL(10,2),
    price_total DECIMAL(10,2),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    availability VARCHAR(50) DEFAULT 'unknown',
    lead_time_days INTEGER,
    last_updated TIMESTAMPTZ,
    is_verified BOOLEAN DEFAULT false,
    notes JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_material_pricing_material_id ON material_pricing(material_id);
CREATE INDEX IF NOT EXISTS idx_material_pricing_region ON material_pricing(region);

-- Users table (for future auth)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'engineer',
    avatar_url VARCHAR(512),
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- API keys table (for future auth)
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(255) NOT NULL,
    key_prefix VARCHAR(20) NOT NULL,
    scopes JSONB DEFAULT '[]',
    expires_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_api_keys_user_id ON api_keys(user_id);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_projects_updated_at ON projects;
CREATE TRIGGER update_projects_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_job_status_updated_at ON job_status;
CREATE TRIGGER update_job_status_updated_at
    BEFORE UPDATE ON job_status
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_cad_specs_updated_at ON cad_specs;
CREATE TRIGGER update_cad_specs_updated_at
    BEFORE UPDATE ON cad_specs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_manufacturing_analysis_updated_at ON manufacturing_analysis;
CREATE TRIGGER update_manufacturing_analysis_updated_at
    BEFORE UPDATE ON manufacturing_analysis
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_cost_estimates_updated_at ON cost_estimates;
CREATE TRIGGER update_cost_estimates_updated_at
    BEFORE UPDATE ON cost_estimates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_materials_updated_at ON materials;
CREATE TRIGGER update_materials_updated_at
    BEFORE UPDATE ON materials
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert default materials
INSERT INTO materials (name, grade, standard, category, density_kg_m3, properties) VALUES
('Aluminum', '6061-T6', 'ASTM B221', 'aluminum', 2700, '{"yield_strength_mpa": 276, "tensile_strength_mpa": 310, "elongation_pct": 12}'),
('Aluminum', '7075-T6', 'ASTM B221', 'aluminum', 2810, '{"yield_strength_mpa": 503, "tensile_strength_mpa": 572, "elongation_pct": 11}'),
('Steel', '1018', 'ASTM A108', 'steel', 7870, '{"yield_strength_mpa": 370, "tensile_strength_mpa": 440, "elongation_pct": 15}'),
('Steel', '4140', 'ASTM A829', 'steel', 7850, '{"yield_strength_mpa": 415, "tensile_strength_mpa": 655, "elongation_pct": 25}'),
('Stainless Steel', '304', 'ASTM A240', 'stainless', 8000, '{"yield_strength_mpa": 215, "tensile_strength_mpa": 505, "elongation_pct": 40}'),
('Stainless Steel', '316', 'ASTM A240', 'stainless', 8000, '{"yield_strength_mpa": 205, "tensile_strength_mpa": 515, "elongation_pct": 40}'),
('Brass', 'C36000', 'ASTM B16', 'brass', 8470, '{"yield_strength_mpa": 140, "tensile_strength_mpa": 340, "elongation_pct": 25}'),
('Copper', 'C11000', 'ASTM B152', 'copper', 8940, '{"yield_strength_mpa": 70, "tensile_strength_mpa": 220, "elongation_pct": 45}'),
('Delrin', 'Acetal', 'ASTM D6100', 'plastic', 1420, '{"yield_strength_mpa": 70, "tensile_strength_mpa": 75, "elongation_pct": 25}'),
('Nylon 6/6', 'PA66', 'ASTM D4066', 'plastic', 1140, '{"yield_strength_mpa": 80, "tensile_strength_mpa": 85, "elongation_pct": 50}')
ON CONFLICT DO NOTHING;