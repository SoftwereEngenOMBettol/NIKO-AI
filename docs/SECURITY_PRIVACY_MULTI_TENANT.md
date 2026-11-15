# NIKO Security, Privacy and Multi-Tenant Architecture

## Security objective

NIKO is a multi-user service. Every account is a separate security boundary. A user must never be able to read, infer, modify, overwrite, delete, or download another user's conversations, memories, prompts, audio, images, videos, documents, jobs, settings, connected accounts, or billing records.

"Supports many users" means the architecture is designed for concurrent accounts and horizontal scaling. It does not mean unlimited capacity: production capacity must be measured with load tests and scaled according to infrastructure, provider quotas, and cost.

## Identity and authentication

- Use a proven identity provider and short-lived access tokens with refresh-token rotation and revocation.
- Support Sign in with Apple for iOS; add other OAuth providers only when needed and configured securely.
- The backend validates token signature, issuer, audience, expiry, nonce where applicable, and revocation/session state.
- Derive the internal user/tenant ID only from the verified server-side identity. Never trust a user_id, tenant_id, owner_id, role, or storage path supplied by the mobile client.
- Use opaque internal identifiers; do not expose sequential database IDs.
- Require re-authentication or step-up confirmation for sensitive account, export, deletion, billing, and connected-account operations.

## Tenant isolation and authorization

- Every user-owned row must carry a non-null owner/tenant key.
- Every read, write, update, delete, search, background job, and export must be scoped to the authenticated principal.
- Use PostgreSQL constraints and Row-Level Security as defence in depth. Apply tenant context transaction-locally and ensure pooled connections cannot leak tenant state between requests.
- Do not rely on UI hiding or client-side filters for authorization.
- Every object lookup must check ownership before returning metadata or content. Random IDs are not authorization.
- Background workers must receive a signed, minimal job context and re-check ownership before reading inputs or writing outputs.
- Admin/support access must be restricted, audited, time-limited, and unavailable by default.

## Protected data inventory

All of the following are private user data:
- conversations, prompts, responses, attachments, memory and personalization;
- speech transcripts, voice settings, and any retained audio;
- uploaded and generated images, video, documents, previews and thumbnails;
- jobs, job logs, intermediate outputs, tool results and browsing history;
- profile data, preferences, API connections, OAuth grants and billing records.

Raw audio should be processed on-device for wake-word detection where feasible. Do not upload idle listening audio. Do not retain raw recordings by default.

## File and media security

- Store objects in private buckets/containers, never public by default.
- Use server-generated object keys that include an internal owner scope; never accept arbitrary client paths.
- Issue short-lived signed download/upload URLs only after an ownership check; use narrow method, object, size and content-type constraints.
- Validate file extension, MIME type and actual file signature; enforce size, duration, pixel and decompression limits.
- Scan or sandbox untrusted uploads before parsing. Process office documents and media in isolated workers with resource limits.
- Prevent path traversal, archive bombs, malicious macros, SSRF via imported URLs, and unsafe preview rendering.
- Expire temporary artifacts and provide user-controlled deletion/export workflows.

## Encryption and secrets

- Enforce TLS for all network traffic.
- Encrypt databases, backups and object storage at rest using managed keys; use envelope encryption/KMS where available.
- Keep provider keys, signing secrets and OAuth client secrets only in a secret manager or protected deployment environment. Never ship them in Flutter, mobile binaries, logs, or Git.
- Rotate secrets and signing keys; support revocation and incident response.
- Consider per-tenant data-encryption keys for high-sensitivity stored content as the product matures.

## Privacy by design

- Collect the minimum data needed for a feature and explain why it is needed.
- Do not use private user content to train models unless a separate, explicit, informed opt-in exists and the provider contract supports it.
- Review provider retention, data residency, subprocessors, training policy, and deletion terms before sending user content to any AI provider.
- Keep operational logs metadata-only where possible. Redact tokens, prompts, transcripts, document contents, image URLs and personal identifiers.
- Define retention periods for sessions, temporary files, jobs, backups and audit logs.
- Provide account export, deletion, session revocation and connected-account disconnect flows.
- Never claim end-to-end encryption if the server or AI provider can read plaintext.

## Abuse prevention and scaling

- Stateless API instances behind a load balancer; shared durable state in PostgreSQL and private object storage.
- Use a queue for long-running image/video/document/agent jobs; workers are horizontally scalable and idempotent.
- Apply per-user and per-IP rate limits, quotas, concurrency caps, upload limits, provider spend limits and abuse detection.
- Use backpressure, bounded retries, timeouts, circuit breakers and dead-letter handling.
- Track latency, error rates, queue depth, provider failures and spend without logging user content.
- Define capacity only after load tests (for example 100, 1,000 and 10,000 concurrent sessions as staged targets), then scale based on measured results. These are test targets, not current guarantees.

## Mandatory security tests

1. Create at least two users and verify that each can access only their own records and objects.
2. Attempt IDOR attacks by swapping conversation, memory, file, image, video, job and account IDs.
3. Test cross-tenant access through list, search, pagination, export, download, update and delete endpoints.
4. Test worker isolation and ensure retries cannot attach results to the wrong user.
5. Test PostgreSQL RLS with pooled connections and concurrent transactions to detect tenant-context leakage.
6. Test revoked/expired tokens, role escalation, refresh-token replay and account takeover protections.
7. Test malicious uploads, MIME spoofing, oversized files, archive bombs and unsafe URL imports.
8. Verify logs, traces, crash reports and analytics do not contain secrets or user content.
9. Run dependency, secret, static-analysis and container scans in CI.
10. Perform an independent security review and penetration test before public launch.

## Incident response

- Maintain an incident contact and documented containment process.
- Be able to revoke sessions and provider credentials, disable a compromised integration, quarantine affected objects, and preserve minimal audit evidence.
- Assess scope and notify affected users/regulators where legally required.
- Never conceal or silently downgrade a confirmed cross-user data exposure.

## Release gates

No public multi-user release until authentication, tenant isolation, private object storage, authorization tests, rate limits, backup/restore, deletion/export, monitoring and independent security review have passed. No architecture can honestly promise absolute secrecy; NIKO must minimize access, enforce isolation, test it continuously, and disclose residual risks.
