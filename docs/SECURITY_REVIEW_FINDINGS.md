# NIKO Security Review Findings

**Review scope:** API authentication boundaries and initial multi-tenant privacy controls  
**Reviewed branch:** `feat/tab-ai-parity-foundation`  
**Reviewed revision:** `b5de8412161b5510775de66899e92e1863dc5037`  
**Review type:** Static code review plus unauthenticated endpoint regression tests  
**Status:** Findings are open. This document does not implement fixes.

## Executive summary

The API currently applies JWT verification to `GET /v1/session`, but the reviewed chat, document-generation, and image-generation/edit routes do not declare an authentication dependency. Tests in `backend/tests/test_api_auth_boundaries.py` reproduce the current behavior without making real Ollama or image-provider calls.

This is an authentication-boundary review, not a full penetration test. It does not establish that user data is currently persisted or that a production deployment is publicly reachable. The database RLS migration is not wired to request transactions in the reviewed API code.

## Findings (ordered by severity)

### NIKO-SEC-001 — Unauthenticated image generation and editing can invoke a configured paid provider

- **Severity:** High
- **Affected routes:** `POST /v1/images/generations`, `POST /v1/images/edits`
- **Evidence:** Both route handlers in `backend/app/main.py` instantiate `OpenAIImageProvider` and call it without depending on `verify_access_token` or another authorization guard.
- **Reproduction:**
  1. Start the API with a valid image-provider API key configured.
  2. Send a multipart/form-data request to `/v1/images/generations` with a prompt and no `Authorization` header; the edit route similarly accepts a prompt and image file.
  3. The route proceeds to the provider call. The automated tests replace the provider with a local fake and assert HTTP 200 without credentials; no paid request is made by the tests.
- **Impact:** Anyone able to reach the API can potentially trigger image-provider usage against the operator's account, exhaust quota, create unexpected costs, or consume concurrency. The current size and prompt limits do not provide identity-based quotas or abuse controls.
- **Remediation owner:** Execution/API integration owner.
- **Required fix:** Require a verified principal; apply per-user and global rate/concurrency/spend limits; bind each generated asset/job to the authenticated owner; do not accept owner IDs from request bodies.

### NIKO-SEC-002 — Unauthenticated chat requests expose compute capacity to anonymous callers

- **Severity:** High
- **Affected route:** `POST /v1/chat`
- **Evidence:** The route has no authentication dependency and forwards the submitted message to Ollama.
- **Reproduction:**
  1. Start the API with Ollama available.
  2. Send `POST /v1/chat` with a valid JSON message and omit the `Authorization` header.
  3. The route forwards the prompt to the model. The regression test substitutes a fake Ollama client and observes HTTP 200 without credentials.
- **Impact:** Anonymous callers can consume CPU/GPU, memory, model context, and request slots; repeated or oversized traffic may degrade availability. There is no per-principal quota because no principal is required.
- **Required fix:** Require verified authentication, then enforce request-size, per-user rate, concurrency, and global capacity limits. Consider network-level protections as an additional layer, not a replacement for authentication.

### NIKO-SEC-003 — Unauthenticated document generation permits anonymous resource consumption

- **Severity:** Medium
- **Affected route:** `POST /v1/documents`
- **Evidence:** The route calls `generate_document` without an authentication dependency.
- **Reproduction:**
  1. Send a valid document-generation JSON request without an `Authorization` header.
  2. The route returns the generated file; the regression test substitutes a deterministic local generator and asserts HTTP 200.
- **Impact:** Anonymous users can consume server CPU and memory and generate arbitrary files within the endpoint's accepted formats and bounds. The current code streams the result and does not associate it with an authenticated owner.
- **Required fix:** Require verified authentication, apply per-user/global quotas and output-size limits, and persist any future asset under the authenticated owner only.

### NIKO-SEC-004 — PostgreSQL tenant isolation is not enforced by the API transaction layer yet

- **Severity:** High (release blocker; implementation gap)
- **Affected components:** `backend/migrations/001_multi_tenant_core.sql` and API/database integration
- **Evidence:** The reviewed `backend/app/main.py` contains no database transaction/session setup and no code that maps the verified `(issuer, subject)` principal to an internal user UUID or executes transaction-local `SET LOCAL app.user_id`. The migration comments explicitly require this context for every API and worker transaction.
- **Impact:** The migration's RLS policies cannot provide effective per-request isolation until the application consistently establishes verified tenant context and uses a database role subject to RLS. A missing context should fail closed, but that alone is not proof of complete tenant isolation.
- **Required fix:** Implement verified identity-to-user mapping; set tenant context transaction-locally for every request and background job; use a non-superuser role without `BYPASSRLS`; test connection-pool reuse, missing/malformed context, CRUD, pagination, joins, jobs, exports and object storage with at least two tenants.

### NIKO-SEC-005 — No API-level tenant/ownership authorization tests exist in the reviewed test set

- **Severity:** Medium (coverage gap)
- **Affected resources:** Conversations, messages, memories, assets, jobs, exports and downloads (as those APIs are implemented)
- **Evidence:** The reviewed tests cover token verification and provider behavior, but do not exercise cross-user resource access or IDOR attempts. The current API does not yet expose these persistent resource routes.
- **Impact:** Future resource endpoints could accidentally trust client-supplied IDs or omit owner predicates without a regression test detecting cross-tenant access.
- **Required fix:** Add two-principal tests for read, list, create, update, delete, search, pagination, download and job status/cancel operations. Assert that user B cannot distinguish or access user A's private resources (normally 404 or 403 according to the chosen policy).

## Authentication boundary inventory

| Route | Authentication in reviewed code | Observed behavior |
|---|---|---|
| `GET /health` | None | Public health/model availability response |
| `GET /v1/session` | `verify_access_token` | Rejects missing token with 401 |
| `GET /v1/capabilities` | None | Public capability metadata |
| `POST /v1/chat` | None | Accepts anonymous request |
| `POST /v1/documents` | None | Accepts anonymous request |
| `POST /v1/images/generations` | None | Accepts anonymous request and calls configured provider |
| `POST /v1/images/edits` | None | Accepts anonymous request and calls configured provider |

Public health/capability endpoints may be intentionally public, but should return only operationally safe metadata. Confirm that they do not disclose secrets, internal hostnames, tenant data, or sensitive configuration.

## Test evidence and limitations

The tests in `backend/tests/test_api_auth_boundaries.py`:
- Assert that chat, documents, image generation and image editing currently return success without an Authorization header.
- Assert that the session route rejects a missing token.
- Replace Ollama and image-provider calls with local fakes; they do not call paid services or require an Ollama server.

These are **current-behavior characterization tests**, not desired security acceptance tests. Once the implementation owner adds authentication, these tests should be deliberately changed to assert 401/403 for anonymous requests and successful access for valid principals.

Not tested by this review:
- A live public deployment or external network reachability.
- Actual provider billing.
- PostgreSQL RLS against a running PostgreSQL instance and a non-superuser application role.
- Object-storage authorization, signed URL expiry, worker isolation, load/DoS resistance, or physical-device security.

## Required implementation follow-up (outside this review scope)

1. Add `Depends(verify_access_token)` (or a centrally enforced equivalent) to every private API route, including new routes by default.
2. Decide whether `/health` and `/v1/capabilities` are public; minimize their returned metadata.
3. Resolve the verified token principal to an internal user record; never use a client-supplied owner/user ID.
4. Establish transaction-local RLS context for every database transaction and worker task.
5. Add RLS integration tests using the exact non-superuser pooled database role used in production.
6. Add private object storage and owner-checked download flows; signed URLs must be short-lived and issued only after authorization.
7. Add per-user and global rate limits, concurrency controls, quotas, spend caps and audit events without logging prompts, tokens or private content unnecessarily.
8. Add IDOR tests for all resource operations before exposing persistent user data.

**Release recommendation:** Do not expose the API as a multi-user public service until SEC-001 through SEC-004 are fixed and verified, and cross-tenant integration tests pass.


---

## Follow-up verification — 15 November 2026

This section supersedes the original "current behavior" statements above where the implementation has since changed. The initial review remains as historical evidence of the pre-fix state.

### Authentication follow-up

At branch revision `79eb1a35296b5af4cf777c94c0e45f88e24c6749`, the following private routes declare `Depends(verify_access_token)`:

- `POST /v1/chat`
- `POST /v1/documents`
- `POST /v1/images/generations`
- `POST /v1/images/edits`

The session endpoint also requires a verified token. The route-level dependency is evaluated before the endpoint body, so unauthenticated requests should not reach Ollama, document generation or image-provider calls.

The characterization tests were updated in commit `4a2f2e38cdd4fa6524426af353038cf9d6a687af` to assert:
- Missing JWT returns 401 on the four private routes.
- Provider/generator fakes are not called when JWT is missing.
- A valid test JWT can reach the endpoint handlers.

These tests use local fakes and do not make paid provider calls. The new commit triggered CI; its final result must be checked separately.

### RLS follow-up and current blocker

The branch now includes `backend/app/tenant_db.py`, which maps the verified `(issuer, subject)` principal to an internal user UUID and sets transaction-local `app.user_id`. It also includes a two-principal PostgreSQL integration test and a PostgreSQL 16 service in Backend CI.

However, Backend CI run #55 at revision `79eb1a35296b5af4cf777c94c0e45f88e24c6749` failed with **5 failed, 16 passed**:
- Four failures were the outdated anonymous-access characterization tests; these were updated in commit `4a2f2e38cdd4fa6524426af353038cf9d6a687af`.
- The remaining RLS test failed because PostgreSQL reported `function niko_current_user_id() does not exist`.

The PostgreSQL service logs show that the migration's PL/pgSQL function and DO block were submitted with malformed dollar-quote delimiters (`AS $` / `DO $`) rather than valid dollar-quoted bodies. Consequently the function and RLS policies were not created, and `TenantDatabase.transaction()` failed when it called the missing function.

**RLS is therefore NOT verified and must not be considered complete.** The migration owner must correct the SQL delimiters, rerun the migration from a clean PostgreSQL database, and obtain a passing two-user RLS integration test using the non-superuser `niko_app` role.

### Remaining security gaps

- No rate limiting, per-user concurrency limits, or provider spend caps have yet been evidenced in the inspected route implementation.
- The tenant transaction bridge exists, but the currently inspected API handlers do not use it for persistent tenant resources. The current endpoints return generated content directly and do not yet provide persistent conversation, memory, asset or job APIs.
- Worker identity propagation and worker-side RLS have not been demonstrated.
- Private object storage, owner-checked signed downloads, deletion/export, and IDOR coverage for persistent resource APIs remain unverified.
- A passing RLS test for one conversation table does not prove isolation for every future resource or operation.

### Current evidence and limitations

- Backend CI run #55: failed; see https://github.com/SoftwereEngenOMBettol/NIKO-AI/actions/runs/43738157918
- iOS Simulator CI run #44 at the same revision: passed; this is a simulator build only, not a physical iPhone test.
- No production deployment, live paid provider call, physical-device security test, or independent penetration test was performed as part of this follow-up.

**Release recommendation:** Do not expose NIKO as a public multi-user service until the RLS migration and integration test pass, every private route is authenticated, quotas/abuse controls exist, and resource/worker/storage ownership tests pass.
