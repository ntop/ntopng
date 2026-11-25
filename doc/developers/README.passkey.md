# WebAuthn / Passkey Authentication in ntopng

This document describes the design, implementation, and operational details of
the WebAuthn/Passkey second-factor authentication support in ntopng.

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication Flows](#authentication-flows)
   - [Registration Flow](#registration-flow)
   - [Login Flow](#login-flow)
3. [Implementation Details](#implementation-details)
   - [Key Files](#key-files)
   - [Redis Storage](#redis-storage)
   - [C++ Backend (Ntop.cpp)](#c-backend-ntopcpp)
   - [HTTP Routing (HTTPserver.cpp)](#http-routing-httpservercpp)
   - [Lua Layer](#lua-layer)
   - [Frontend (password_dialog.lua)](#frontend-password_dialoglua)
4. [C++ Lua Bindings](#c-lua-bindings)
5. [Cryptographic Details](#cryptographic-details)
6. [Security Considerations](#security-considerations)
7. [Constraints and Limitations](#constraints-and-limitations)

---

## Overview

ntopng supports **WebAuthn** (Web Authentication API, W3C standard) as a
second authentication factor, alongside the existing TOTP/MFA support.
End users register one or more hardware security keys or platform
authenticators (Touch ID, Face ID, Windows Hello, YubiKey, etc.) — collectively
called **passkeys** — and are prompted to use one after password login.

**No external WebAuthn library is required.** The entire implementation is
self-contained in `src/Ntop.cpp` using only libraries already required by
ntopng:

| Library | Used for |
|---------|----------|
| **OpenSSL** (libssl + libcrypto) | `RAND_bytes` for challenge generation; `SHA256`, `EC_KEY`, `ECDSA_verify` for assertion verification |
| **Redis / hiredis** | Credential storage, pending-token and challenge state |

The implementation supports **ES256** (ECDSA over P-256 with SHA-256), which is
the algorithm mandated by the WebAuthn Level 2 specification and universally
supported by browsers and authenticators.

WebAuthn takes **priority over TOTP** when both are configured for the same
user: if a user has at least one registered passkey, the WebAuthn prompt is
shown instead of the TOTP prompt.

---

## Authentication Flows

### Registration Flow

```
Browser (logged-in user)          ntopng (Lua + C++)               Redis
        │                                  │                           │
        │  POST /lua/admin/                │                           │
        │    change_user_webauthn.lua      │                           │
        │    action=get_registration_      │                           │
        │    options&username=…&csrf=…     │                           │
        │─────────────────────────────────>│                           │
        │                                  │ generateWebAuthnChallenge │
        │                                  │ (RAND_bytes 32 → b64url)  │
        │                                  │──────────────────────────>│
        │                                  │ SET webauthn.reg.<chal>   │
        │                                  │     = username (TTL 5min) │
        │  { challenge, rp, user, … }      │                           │
        │<─────────────────────────────────│                           │
        │                                  │                           │
        │  navigator.credentials.create()  │                           │
        │  (browser prompts user for       │                           │
        │   authenticator gesture)         │                           │
        │                                  │                           │
        │  POST action=complete_           │                           │
        │    registration                  │                           │
        │    cred_id, client_data,         │                           │
        │    att_obj, challenge, …         │                           │
        │─────────────────────────────────>│                           │
        │                                  │ verifyAndStoreWebAuthn    │
        │                                  │   Registration():         │
        │                                  │  • verify clientDataJSON  │
        │                                  │  • CBOR-decode attObj     │
        │                                  │  • parse authData         │
        │                                  │  • verify rpIdHash        │
        │                                  │  • check UP flag          │
        │                                  │  • store credential       │
        │                                  │──────────────────────────>│
        │                                  │ SET webauthn_cred_<n>     │
        │  { result: 0 }                   │                           │
        │<─────────────────────────────────│                           │
```

### Login Flow

```
Browser                           ntopng (HTTPserver.cpp)           Redis
        │                                  │                           │
        │  POST /lua/login.lua             │                           │
        │  (username + password)           │                           │
        │─────────────────────────────────>│                           │
        │                                  │ password OK               │
        │                                  │ isWebAuthnEnabled(user)?  │
        │                                  │──────────────────────────>│
        │                                  │  YES: cred_count > 0      │
        │                                  │ createWebAuthnPendingToken │
        │                                  │  → token, challenge       │
        │                                  │──────────────────────────>│
        │                                  │ SET webauthn.pending.<tok>│
        │                                  │  = user|group|localuser|  │
        │                                  │    referer|challenge      │
        │  302 → /lua/webauthn_verify.lua  │    (TTL 5 min)            │
        │    ?token=<tok>                  │                           │
        │<─────────────────────────────────│                           │
        │                                  │                           │
        │  GET /lua/webauthn_verify.lua    │                           │
        │─────────────────────────────────>│                           │
        │  (page auto-triggers             │                           │
        │   navigator.credentials.get())   │                           │
        │                                  │                           │
        │  POST /webauthn_authorize.html   │                           │
        │    token, cred_id, client_data,  │                           │
        │    auth_data, signature          │                           │
        │─────────────────────────────────>│                           │
        │                                  │ getWebAuthnPendingToken   │
        │                                  │──────────────────────────>│
        │                                  │ verifyWebAuthnAssertion() │
        │                                  │  • decode b64url inputs   │
        │                                  │  • verify clientDataJSON  │
        │                                  │  • verify rpIdHash        │
        │                                  │  • check UP flag          │
        │                                  │  • find credential by ID  │
        │                                  │  • check signCount        │
        │                                  │  • verify ECDSA signature │
        │                                  │  • update signCount       │
        │                                  │──────────────────────────>│
        │                                  │ deleteWebAuthnPendingToken│
        │  302 → original referer          │ set_session_cookie()      │
        │<─────────────────────────────────│                           │
```

---

## Implementation Details

### Key Files

| File | Role |
|------|------|
| `src/Ntop.cpp` | All WebAuthn crypto and Redis CRUD: challenge generation, registration verification, assertion verification, credential storage |
| `include/Ntop.h` | Public declarations of all WebAuthn methods on `Ntop` |
| `include/ntop_defines.h` | Redis key prefixes and constants (`WEBAUTHN_*`) |
| `src/HTTPserver.cpp` | `webauthn_authorize()` handler; second-factor routing after password login |
| `src/LuaEngineNtop.cpp` | Lua bindings (`ntop.generateWebAuthnRegistrationOptions`, `ntop.completeWebAuthnRegistration`, etc.) |
| `scripts/lua/webauthn_verify.lua` | Second-factor challenge page; auto-invokes `navigator.credentials.get()` |
| `scripts/lua/admin/change_user_webauthn.lua` | REST endpoint for credential list/register/delete |
| `scripts/lua/inc/password_dialog.lua` | Passkeys tab UI in the user management modal |
| `scripts/locales/en.lua` | `webauthn.*` i18n strings |

### Redis Storage

All WebAuthn state is stored in Redis with no additional persistence layer.

#### Credential storage (permanent, no TTL)

```
ntopng.user.<username>.webauthn_cred_count   →  "<n>"
ntopng.user.<username>.webauthn_cred_0       →  "<cred_id_b64url>|<pk_x_hex>|<pk_y_hex>|<sign_count>|<name>"
ntopng.user.<username>.webauthn_cred_1       →  …
…
ntopng.user.<username>.webauthn_cred_9       →  …  (max 10 credentials, WEBAUTHN_MAX_CREDS)
```

The credential record fields are pipe-separated:

| Field | Description |
|-------|-------------|
| `cred_id_b64url` | Credential ID as returned by the authenticator (base64url) |
| `pk_x_hex` | P-256 public key X coordinate (32 bytes, hex) |
| `pk_y_hex` | P-256 public key Y coordinate (32 bytes, hex) |
| `sign_count` | Last observed authenticator signature counter |
| `name` | User-assigned label (e.g. "My iPhone") |

#### Registration challenge (TTL 5 minutes)

```
webauthn.reg.<challenge_b64url>   →  "<username>"
```

Created by `generateWebAuthnRegistrationOptions`, consumed and deleted by
`completeWebAuthnRegistration`.

#### Pending authentication token (TTL 5 minutes)

```
webauthn.pending.<token>   →  "<username>|<referer>|<challenge_b64url>"
```

Created by `createWebAuthnPendingToken` after password login succeeds,
deleted by `deleteWebAuthnPendingToken` after assertion verification.

### HTTP Routing (HTTPserver.cpp)

#### Second-factor trigger (inside password login handler)

After a successful password check, the login handler checks whether WebAuthn
is enabled for the user **before** checking TOTP:

```cpp
if (ntop->isWebAuthnEnabled(user)) {
  char token[64], challenge[128];
  if (ntop->createWebAuthnPendingToken(user, referer, token, sizeof(token),
                                       challenge, sizeof(challenge)))
    redirect_to_webauthn(conn, token);   // → /lua/webauthn_verify.lua?token=…
  return;
}
// TOTP check follows here
```

#### `POST /webauthn_authorize.html`

Handled by `webauthn_authorize()` in `HTTPserver.cpp`. This endpoint is
whitelisted (accessible without a session).

Steps:
1. Read POST fields: `token`, `cred_id`, `client_data`, `auth_data`, `signature`.
2. Look up and validate the pending token in Redis (`getWebAuthnPendingToken`).
3. Derive `origin` (`scheme://Host` header) and `rp_id` (hostname, port stripped)
   from the incoming HTTP request.
4. Call `verifyWebAuthnAssertion()`.
5. On success: delete the pending token, call `set_session_cookie()`, redirect to
   the stored referer.
6. On failure: redirect back to `/lua/webauthn_verify.lua?token=…&reason=invalid-key`.

### Lua Layer

#### `scripts/lua/webauthn_verify.lua`

The second-factor challenge page. On page load it:
1. Reads `token` from `_GET`.
2. Calls `ntop.getWebAuthnPendingToken(token)` to retrieve `username` and
   `challenge`.
3. Renders a page that auto-calls `navigator.credentials.get()` with the
   challenge, then POSTs the assertion to `/webauthn_authorize.html`.

#### `scripts/lua/admin/change_user_webauthn.lua`

REST endpoint for credential management. Requires CSRF token on all POST
requests.

| `action` | Method | Description |
|----------|--------|-------------|
| `get_registration_options` | POST | Generate and return a registration challenge |
| `complete_registration` | POST | Verify attestation and store credential |
| `list` | GET | Return JSON array of credentials for a user |
| `delete` | POST | Remove a credential by ID |

Authorization: admin users can manage any user's credentials; non-admin users
can manage only their own credentials (enforced in both Lua and C++).

### Frontend (password_dialog.lua)

The Passkeys tab is rendered inside the user management modal
(`scripts/lua/inc/password_dialog.lua`). The JavaScript:

- Uses `navigator.credentials.create()` for registration.
- Sets `rp: { name: "ntopng" }` without an explicit `id`, letting the browser
  use the effective domain of the current page (required for IP access to work
  with `localhost`; note that IP addresses other than `localhost` are not valid
  RP IDs per the WebAuthn spec).
- Encodes binary fields with base64url before POSTing to the Lua endpoint.
- Refreshes the credential list via `updateWebAuthnStatus(username)` after each
  add or remove operation.

All three POST requests (get options, complete registration, delete) include a
`csrf=` token rendered server-side by `ntop.getRandomCSRFValue()`, matching the
pattern used by the existing MFA tab.

---

## C++ Lua Bindings

Registered in `src/LuaEngineNtop.cpp`:

| Lua function | C++ handler |
|---|---|
| `ntop.generateWebAuthnRegistrationOptions(username)` | `ntop_generate_webauthn_registration_options` |
| `ntop.completeWebAuthnRegistration(username, name, cred_id, cdj, attobj, challenge, origin, rp_id)` | `ntop_complete_webauthn_registration` |
| `ntop.getWebAuthnCredentials(username)` | `ntop_get_webauthn_credentials` |
| `ntop.deleteWebAuthnCredential(username, cred_id)` | `ntop_delete_webauthn_credential` |
| `ntop.isWebAuthnEnabled(username)` | `ntop_is_webauthn_enabled` |
| `ntop.getWebAuthnPendingToken(token)` | `ntop_get_webauthn_pending_token` |

Authorization in the C++ bindings uses a dedicated helper
`allowWebAuthnManagement(vm, target_username)` that permits the call if the
caller is an administrator **or** if the caller is the same user as
`target_username`. This differs from `allowLocalUserManagement()` (admin-only)
and mirrors the self-service pattern used by `ntop_reset_user_password`.

---

## Cryptographic Details

### Challenge Generation

```
RAND_bytes(32 bytes)  →  base64url-encode  →  43-character challenge string
```

Stored in Redis with a 5-minute TTL. Challenges are single-use: consumed and
deleted on first use to prevent replay.

### Registration Verification (`verifyAndStoreWebAuthnRegistration`)

1. **Decode** `clientDataJSON` (base64url) and `attestationObject` (base64url).
2. **Verify `clientDataJSON`**:
   - `type` must be `"webauthn.create"`.
   - `challenge` must match the stored registration challenge (byte-for-byte
     after decoding both from base64url).
   - `origin` must match `expected_origin`.
3. **Parse `attestationObject`**: minimal CBOR decoder extracts the `authData`
   byte array from the `"none"` attestation format (the only format requested).
4. **Parse `authData`** binary structure:
   - Bytes 0–31: `rpIdHash` — SHA-256 of the RP ID.
   - Byte 32: flags (bit 0 = UP, bit 6 = AT).
   - Bytes 33–36: signature counter (big-endian uint32).
   - Bytes 37+: attested credential data (AAGUID, credential ID length,
     credential ID, COSE public key).
   - COSE key (CBOR map): extracts `x` (key -2) and `y` (key -3) as 32-byte
     P-256 coordinates.
5. **Verify `rpIdHash`**: `SHA256(rp_id)` must equal bytes 0–31 of `authData`.
6. **Check UP flag** (User Present, bit 0 of flags byte).
7. **Store credential** in Redis.

### Assertion Verification (`verifyWebAuthnAssertion`)

1. **Decode** `clientDataJSON`, `authenticatorData`, and `signature` (all
   base64url).
2. **Verify `clientDataJSON`**:
   - `type` must be `"webauthn.get"`.
   - `challenge` must match the pending token's stored challenge.
   - `origin` must match the `scheme://host` of the incoming request.
3. **Verify `rpIdHash`**: `SHA256(rp_id)` must equal bytes 0–31 of
   `authenticatorData`.
4. **Check UP flag** (byte 32, bit 0).
5. **Extract `signCount`** from bytes 33–36 (big-endian uint32).
6. **Find credential** by matching `cred_id` against stored credentials.
7. **Check `signCount`**: if the stored counter is non-zero, the new counter
   must be strictly greater (replay protection). Authenticators that always
   return 0 are accepted (stored counter stays 0).
8. **Verify ECDSA-P256 signature**:
   - Message = `authenticatorData || SHA256(clientDataJSON)`.
   - Public key reconstructed from stored `pk_x`, `pk_y` via `EC_KEY`.
   - Verified with `ECDSA_verify(0, msg, mlen, sig, slen, ec_key)`.
9. **Update `signCount`** in Redis.

---

## Security Considerations

| Concern | Mitigation |
|---------|-----------|
| Challenge replay | Challenges stored in Redis with 5-minute TTL; deleted on first use |
| CSRF on credential management | All POST requests to `change_user_webauthn.lua` require a valid `csrf=` token (rendered server-side) |
| Unauthorized credential access | C++ `allowWebAuthnManagement()` enforces admin-or-self; Lua endpoint has an additional authorization check |
| Assertion replay | `signCount` strictly increases; stale assertions rejected |
| Origin binding | `origin` in `clientDataJSON` verified against `scheme://Host` header of the actual HTTP request |
| RP ID binding | `rpIdHash` in `authenticatorData` verified against `SHA256(hostname)` |
| User presence | UP flag (bit 0) checked in both registration and assertion |
| Max credentials | Capped at 10 per user (`WEBAUTHN_MAX_CREDS`) to bound Redis key proliferation |
| Pending token scope | Token links a specific username to a specific challenge; cannot be used for a different user |

---

## Constraints and Limitations

- **HTTPS required.** Browsers expose `window.PublicKeyCredential` only in
  [secure contexts](https://w3c.github.io/webappsec-secure-contexts/) (HTTPS
  or `http://localhost`). Accessing ntopng via plain HTTP on a non-localhost
  address will silently make the API unavailable.

- **IP addresses not supported as RP IDs.** The WebAuthn spec forbids IP
  addresses (e.g. `192.168.1.1`) as RP IDs. ntopng omits `rp.id` in the
  `navigator.credentials.create()` call so the browser defaults to the
  effective domain, which handles named hostnames and `localhost` correctly.
  Deployment behind a reverse proxy with a proper DNS hostname is recommended.

- **ES256 only.** Only ECDSA P-256 (`alg: -7`) is requested and verified.
  RSA-based authenticators (`RS256`) are not supported.

- **`"none"` attestation only.** ntopng requests `attestation: "none"` and
  does not verify authenticator provenance (no attestation certificate
  validation). This is appropriate for a second-factor scenario where the
  goal is binding to a physical device rather than auditing device models.

- **No resident keys / discoverable credentials.** Registration requests
  `residentKey: "preferred"` but login always requires a username + password
  first; the WebAuthn assertion is a second factor, not a passwordless
  replacement.
