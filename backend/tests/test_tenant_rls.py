import os
import uuid

import psycopg
import pytest

from app.auth import AuthenticatedPrincipal
from app.tenant_db import TenantDatabase


pytestmark = pytest.mark.skipif(
    not os.getenv("NIKO_TEST_DATABASE_URL"),
    reason="PostgreSQL integration database is not configured",
)


def test_two_tenants_are_isolated_by_rls_and_identity_bootstrap_is_stable():
    db = TenantDatabase(os.environ["NIKO_TEST_DATABASE_URL"])
    a = AuthenticatedPrincipal("https://issuer.example", "user-a")
    b = AuthenticatedPrincipal("https://issuer.example", "user-b")

    with db.transaction(a) as (conn, tenant_a):
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO niko_conversations (owner_id, title) VALUES (%s, %s) RETURNING id",
                (tenant_a.id, "A private conversation"),
            )
            conversation_id = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM niko_users WHERE id = %s", (tenant_a.id,))
            assert cur.fetchone()[0] == 1

    # A second transaction for the same verified identity must resolve the same UUID.
    with db.transaction(a) as (conn, tenant_a_again):
        assert tenant_a_again.id == tenant_a.id
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM niko_users WHERE id = %s", (tenant_a.id,))
            assert cur.fetchone()[0] == 1

    with db.transaction(b) as (conn, tenant_b):
        assert tenant_b.id != tenant_a.id
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM niko_conversations WHERE id = %s", (conversation_id,))
            assert cur.fetchone() is None
            with pytest.raises(psycopg.errors.InsufficientPrivilege):
                cur.execute("SELECT identity_subject FROM niko_identity_map")
            with pytest.raises(psycopg.errors.InsufficientPrivilege):
                cur.execute(
                    "INSERT INTO niko_conversations (id, owner_id, title) VALUES (%s, %s, %s)",
                    (uuid.uuid4(), tenant_a.id, "forbidden"),
                )

    with db.transaction(a) as (conn, _):
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM niko_conversations WHERE id = %s", (conversation_id,))
            assert cur.fetchone()[0] == conversation_id


def test_transaction_local_tenant_context_is_cleared_when_connection_is_reused():
    dsn = os.environ["NIKO_TEST_DATABASE_URL"]
    tenant_id = str(uuid.uuid4())

    with psycopg.connect(dsn) as conn:
        with conn.transaction():
            with conn.cursor() as cur:
                cur.execute("SELECT set_config('app.user_id', %s, true)", (tenant_id,))
                cur.execute("SELECT niko_current_user_id()")
                assert str(cur.fetchone()[0]) == tenant_id

        # Same physical connection, new transaction: no tenant context may survive.
        with conn.transaction():
            with conn.cursor() as cur:
                cur.execute("SELECT niko_current_user_id()")
                assert cur.fetchone()[0] is None
