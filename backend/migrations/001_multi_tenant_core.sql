-- NIKO multi-tenant foundation (PostgreSQL).
-- Apply only after configuring the application's verified identity -> UUID mapping.
-- Every API/worker transaction MUST set app.user_id from the verified server identity.
-- Never derive this value from an untrusted request field.
--
-- Example transaction setup:
--   SET LOCAL app.user_id = '<verified-internal-user-uuid>';
--
-- The application database role must not be a superuser or have BYPASSRLS.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS niko_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_issuer TEXT NOT NULL,
    identity_subject TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (identity_issuer, identity_subject)
);

CREATE TABLE IF NOT EXISTS niko_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES niko_users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (id, owner_id)
);
CREATE INDEX IF NOT EXISTS idx_niko_conversations_owner_updated
    ON niko_conversations(owner_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS niko_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES niko_users(id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'tool')),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (conversation_id, owner_id)
        REFERENCES niko_conversations(id, owner_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_niko_messages_owner_conversation_created
    ON niko_messages(owner_id, conversation_id, created_at);

CREATE TABLE IF NOT EXISTS niko_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES niko_users(id) ON DELETE CASCADE,
    memory_key TEXT NOT NULL,
    memory_value JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (owner_id, memory_key)
);

CREATE TABLE IF NOT EXISTS niko_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES niko_users(id) ON DELETE CASCADE,
    asset_kind TEXT NOT NULL CHECK (asset_kind IN ('image', 'video', 'document', 'audio', 'other')),
    object_key TEXT NOT NULL UNIQUE,
    content_type TEXT NOT NULL,
    byte_size BIGINT NOT NULL CHECK (byte_size >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_niko_assets_owner_created
    ON niko_assets(owner_id, created_at DESC);

CREATE TABLE IF NOT EXISTS niko_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES niko_users(id) ON DELETE CASCADE,
    job_kind TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'cancelled')),
    input_asset_ids UUID[] NOT NULL DEFAULT '{}',
    output_asset_ids UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_niko_jobs_owner_status_created
    ON niko_jobs(owner_id, status, created_at DESC);

-- Restricted identity bootstrap. The application role cannot read or write this
-- mapping table directly; it can only execute niko_resolve_user_id().
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'niko_identity_resolver') THEN
        CREATE ROLE niko_identity_resolver NOLOGIN NOSUPERUSER NOBYPASSRLS;
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS niko_identity_map (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_issuer TEXT NOT NULL,
    identity_subject TEXT NOT NULL,
    UNIQUE (identity_issuer, identity_subject)
);

REVOKE ALL ON TABLE niko_identity_map FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO niko_identity_resolver;
GRANT SELECT, INSERT, UPDATE ON TABLE niko_identity_map TO niko_identity_resolver;

CREATE OR REPLACE FUNCTION niko_resolve_user_id(p_issuer TEXT, p_subject TEXT)
RETURNS UUID
LANGUAGE SQL
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    INSERT INTO public.niko_identity_map (identity_issuer, identity_subject)
    VALUES (p_issuer, p_subject)
    ON CONFLICT (identity_issuer, identity_subject)
    DO UPDATE SET identity_subject = EXCLUDED.identity_subject
    RETURNING id;
$$;

ALTER FUNCTION niko_resolve_user_id(TEXT, TEXT) OWNER TO niko_identity_resolver;
REVOKE ALL ON FUNCTION niko_resolve_user_id(TEXT, TEXT) FROM PUBLIC;

-- Tenant isolation policies. Missing or malformed transaction context returns NULL.
CREATE OR REPLACE FUNCTION niko_current_user_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    raw_user_id TEXT;
BEGIN
    raw_user_id := NULLIF(current_setting('app.user_id', true), '');
    IF raw_user_id IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN raw_user_id::UUID;
EXCEPTION WHEN invalid_text_representation THEN
    RETURN NULL;
END;
$$;

DO $$
DECLARE
    table_name TEXT;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'niko_conversations',
        'niko_messages',
        'niko_memories',
        'niko_assets',
        'niko_jobs'
    ]
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', table_name);
        EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', table_name);
        EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %I', table_name);
        EXECUTE format(
            'CREATE POLICY tenant_isolation ON %I USING (owner_id = niko_current_user_id()) WITH CHECK (owner_id = niko_current_user_id())',
            table_name
        );
    END LOOP;
END
$$;

ALTER TABLE niko_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE niko_users FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_self_access ON niko_users;
CREATE POLICY user_self_access ON niko_users
    USING (id = niko_current_user_id())
    WITH CHECK (id = niko_current_user_id());

-- Grant EXECUTE on niko_resolve_user_id(TEXT, TEXT) to the backend application
-- role during deployment. Do not grant direct access to niko_identity_map.
