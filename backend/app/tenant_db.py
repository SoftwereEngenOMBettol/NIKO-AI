"""Verified principal to PostgreSQL tenant context bridge.

Every database operation that touches tenant data must run inside
TenantDatabase.transaction(). The internal UUID is resolved from the verified
issuer + subject pair and the PostgreSQL context is transaction-local.
"""
from __future__ import annotations

from contextlib import contextmanager
from dataclasses import dataclass
from typing import Iterator

import psycopg

from app.auth import AuthenticatedPrincipal


@dataclass(frozen=True)
class Tenant:
    id: str
    issuer: str
    subject: str


class TenantDatabase:
    def __init__(self, dsn: str) -> None:
        self.dsn = dsn

    @contextmanager
    def transaction(self, principal: AuthenticatedPrincipal) -> Iterator[tuple[psycopg.Connection, Tenant]]:
        """Resolve identity and establish fail-closed RLS context for one transaction."""
        with psycopg.connect(self.dsn) as conn:
            with conn.transaction():
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO niko_users (identity_issuer, identity_subject)
                        VALUES (%s, %s)
                        ON CONFLICT (identity_issuer, identity_subject)
                        DO UPDATE SET updated_at = now()
                        RETURNING id
                        """,
                        (principal.issuer, principal.subject),
                    )
                    row = cur.fetchone()
                    if row is None:
                        raise RuntimeError("Unable to resolve authenticated tenant.")
                    user_id = str(row[0])
                    # set_config(..., true) is equivalent to SET LOCAL and cannot
                    # leak into the next transaction on a pooled connection.
                    cur.execute("SELECT set_config('app.user_id', %s, true)", (user_id,))
                    cur.execute("SELECT niko_current_user_id()")
                    context_id = cur.fetchone()[0]
                    if str(context_id) != user_id:
                        raise RuntimeError("Tenant context was not established.")
                    yield conn, Tenant(user_id, principal.issuer, principal.subject)
