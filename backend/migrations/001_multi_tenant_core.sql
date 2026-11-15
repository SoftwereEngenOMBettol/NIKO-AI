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

-- Tenant isolation policies. The request/worker layer must SET LOCAL app.user_id
-- from a verified principal inside every transaction. Missing context returns no rows.
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
        EXECUTE format(
            'DROP POLICY IF EXISTS tenant_isolation ON %I',
            table_name
        );
        EXECUTE format(
            'CREATE POLICY tenant_isolation ON %I USING (owner_id = NULLIF(current_setting(''app.user_id'', true), '''')::uuid) WITH CHECK (owner_id = NULLIF(current_setting(''app.user_id'', true), '''')::uuid)',
            table_name
        );
    END LOOP;
END $$;

ALTER TABLE niko_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE niko_users FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_self_access ON niko_users;
CREATE POLICY user_self_access ON niko_users
    USING (id = NULLIF(current_setting('app.user_id', true), '')::uuid)
    WITH CHECK (id = NULLIF(current_setting('app.user_id', true), '')::uuid);

-- Production deployment must grant only required table/sequence privileges to a
-- non-superuser application role and must test RLS with the exact pooled role.
