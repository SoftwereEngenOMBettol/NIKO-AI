"""Verified principal to PostgreSQL tenant context bridge.

Tenant identity is resolved through a narrowly privileged SECURITY DEFINER function.
The app role cannot read the identity map; it can only resolve its verified issuer +
subject pair. Every tenant-data operation must use this transaction context.
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
    def transaction(
        self, principal: AuthenticatedPrincipal
    ) -> Iterator[tuple[psycopg.Connection, Tenant]]:
        """Resolve the verified tenant and establish transaction-local RLS context."""
        if not principal.issuer.strip() or not principal.subject.strip():
            raise ValueError("A verified issuer and subject are required.")

        with psycopg.connect(self.dsn) as conn:
            with conn.transaction():
                with conn.cursor() as cur:
                    # This function can only read/write the restricted identity map.
                    # The app role has EXECUTE permission, not direct table access.
                    cur.execute(
                        "SELECT niko_private.niko_resolve_user_id(%s, %s)",
                        (principal.issuer, principal.subject),
                    )
                    row = cur.fetchone()
                    if row is None or row[0] is None:
                        raise RuntimeError("Unable to resolve authenticated tenant.")
                    user_id = str(row[0])

                    # SET LOCAL semantics: the value is cleared on transaction end.
                    cur.execute(
                        "SELECT set_config('app.user_id', %s, true)",
                        (user_id,),
                    )
                    cur.execute("SELECT public.niko_current_user_id()")
                    context_row = cur.fetchone()
                    if context_row is None or str(context_row[0]) != user_id:
                        raise RuntimeError("Tenant context was not established.")

                    # Bootstrap the tenant profile only after RLS context exists.
                    # The user_self_access policy permits this exact id and no other.
                    cur.execute(
                        """
                        INSERT INTO public.niko_users
                            (id, identity_issuer, identity_subject)
                        VALUES (%s, %s, %s)
                        ON CONFLICT (identity_issuer, identity_subject)
                        DO UPDATE SET updated_at = now()
                        RETURNING id
                        """,
                        (user_id, principal.issuer, principal.subject),
                    )
                    profile_row = cur.fetchone()
                    if profile_row is None or str(profile_row[0]) != user_id:
                        raise RuntimeError("Tenant profile does not match resolved identity.")

                    yield conn, Tenant(user_id, principal.issuer, principal.subject)
