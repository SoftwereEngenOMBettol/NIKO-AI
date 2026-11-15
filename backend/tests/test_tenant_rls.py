import os
import uuid

import pytest

from app.auth import AuthenticatedPrincipal
from app.tenant_db import TenantDatabase


@pytest.mark.skipif(not os.getenv("NIKO_TEST_DATABASE_URL"), reason="PostgreSQL integration database is not configured")
def test_two_tenants_are_isolated_by_rls():
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

    with db.transaction(b) as (conn, tenant_b):
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM niko_conversations WHERE id = %s", (conversation_id,))
            assert cur.fetchone() is None
            with pytest.raises(Exception):
                cur.execute(
                    "INSERT INTO niko_conversations (id, owner_id, title) VALUES (%s, %s, %s)",
                    (uuid.uuid4(), tenant_a.id, "forbidden"),
                )

    with db.transaction(a) as (conn, _):
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM niko_conversations WHERE id = %s", (conversation_id,))
            assert cur.fetchone()[0] == conversation_id
