"""Fail-closed JWT verification for NIKO API principals.

This module verifies access tokens only; it does not mint tokens or replace a
production identity provider. The signing secret is read exclusively from the
backend environment and is never accepted from clients.
"""
from __future__ import annotations

import os
from dataclasses import dataclass

import jwt
from fastapi import Header, HTTPException, status


@dataclass(frozen=True)
class AuthenticatedPrincipal:
    issuer: str
    subject: str


def _configuration() -> tuple[str, str, str | None]:
    secret = os.getenv("NIKO_AUTH_JWT_SECRET", "").strip()
    issuer = os.getenv("NIKO_AUTH_ISSUER", "").strip()
    audience = os.getenv("NIKO_AUTH_AUDIENCE", "").strip() or None
    if not secret or not issuer:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication is not configured on this server.",
        )
    return secret, issuer, audience


def verify_access_token(
    authorization: str | None = Header(default=None),
) -> AuthenticatedPrincipal:
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer access token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization scheme.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    secret, issuer, audience = _configuration()
    try:
        options = {"require": ["exp", "iat", "iss", "sub"]}
        claims = jwt.decode(
            token,
            secret,
            algorithms=["HS256"],
            issuer=issuer,
            audience=audience,
            options=options,
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    subject = str(claims.get("sub", "")).strip()
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Access token is missing a subject.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return AuthenticatedPrincipal(issuer=issuer, subject=subject)
