# OpenID Connect (OIDC) SSO Authentication in ntopng

This document describes the design, implementation, and configuration of the
OpenID Connect Single Sign-On support in ntopng.

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication Flow](#authentication-flow)
3. [Configuration](#configuration)
4. [Implementation Details](#implementation-details)
   - [Key Files](#key-files)
   - [C++ Class: OIDCAuthenticator](#c-class-oidcauthenticator)
   - [HTTP Endpoints](#http-endpoints)
   - [JWT Validation](#jwt-validation)
   - [State and Nonce Management](#state-and-nonce-management)
   - [User Mapping and Auto-Creation](#user-mapping-and-auto-creation)
5. [Login Page Integration](#login-page-integration)
6. [REST API](#rest-api)
7. [Preferences UI](#preferences-ui)
8. [Dependencies](#dependencies)
9. [Security Considerations](#security-considerations)
10. [Testing with a Local IdP](#testing-with-a-local-idp)
11. [Extending the Implementation](#extending-the-implementation)

---

## Overview

The OIDC feature adds support for identity providers (IdPs)
that speak the **OpenID Connect 1.0** protocol — such as Keycloak, Okta,
Auth0, Azure AD / Entra ID, Google, and any other standards-compliant IdP.

The implementation uses the **Authorization Code Flow**, which keeps tokens
off the browser and is the recommended flow for server-side web applications.

**No external OIDC/OAuth2 library is required.**  Everything is implemented on
top of libraries that are basic ntopng dependencies:

| Library | Used for |
|---------|----------|
| **libcurl** | HTTP requests to IdP (discovery, token exchange, JWKS) |
| **OpenSSL** (libssl + libcrypto) | JWT signature verification (RS256/RS384/RS512, ES256/ES384/ES512) |
| **json-c** (bundled in `third-party/json-c/`) | JSON parsing |

---

## Authentication Flow

```
Browser                    ntopng                        Identity Provider (IdP)
  │                           │                                    │
  │  GET /lua/login.lua       │                                    │
  │──────────────────────────>│                                    │
  │  (shows login page with   │                                    │
  │   "Login with SSO" btn)   │                                    │
  │                           │                                    │
  │  GET /oidc_start          │                                    │
  │──────────────────────────>│                                    │
  │                           │ generate state, nonce              │
  │                           │ store in Redis (10 min TTL)        │
  │                           │ fetch discovery doc (cached)       │
  │  302 → IdP auth URL       │                                    │
  │<──────────────────────────│                                    │
  │                           │                                    │
  │  GET /authorize?...       │                                    │
  │──────────────────────────────────────────────────────────────>│
  │             (user authenticates at IdP — may include MFA)      │
  │<──────────────────────────────────────────────────────────────│
  │  302 → /oidc_callback?code=…&state=…                          │
  │                           │                                    │
  │  GET /oidc_callback       │                                    │
  │──────────────────────────>│                                    │
  │                           │ validate state (Redis lookup)      │
  │                           │ POST token endpoint                │
  │                           │──────────────────────────────────>│
  │                           │  { id_token, access_token, … }    │
  │                           │<──────────────────────────────────│
  │                           │ fetch JWKS (cached)               │
  │                           │ validate id_token JWT:            │
  │                           │  • signature (RS256/ES256)        │
  │                           │  • iss, aud, exp, nonce           │
  │                           │ derive username from claims        │
  │                           │ auto-create user if configured     │
  │                           │ create session cookie              │
  │  302 → original referer   │                                    │
  │<──────────────────────────│                                    │
```

---

## Configuration

All OIDC settings are stored in Redis under the `ntopng.prefs.oidc.*` namespace.
They can be set through:

- The ntopng **Preferences → Authentication** tab (web UI)
- The REST API endpoints documented in the [REST API](#rest-api) section
- Directly via `redis-cli` for scripted deployments

### Configuration Keys

| Redis key | Type | Default | Description |
|-----------|------|---------|-------------|
| `ntopng.prefs.oidc.enabled` | `"0"` / `"1"` | `"0"` | Enable OIDC authentication |
| `ntopng.prefs.oidc.client_id` | string | — | OAuth2 client ID registered at the IdP |
| `ntopng.prefs.oidc.client_secret` | string | — | OAuth2 client secret |
| `ntopng.prefs.oidc.issuer_url` | URL | — | IdP issuer URL (OIDC discovery appends `/.well-known/openid-configuration`) |
| `ntopng.prefs.oidc.base_redirect_uri` | URL | — | ntopng's publicly reachable base URL; the callback will be `{base}/oidc_callback` |
| `ntopng.prefs.oidc.scopes` | string | `"openid profile email roles"` | Space-separated OIDC scopes to request |
| `ntopng.prefs.oidc.group_claim` | string | `"groups"` | JWT claim that carries group membership |
| `ntopng.prefs.oidc.admin_group` | string | — | Value in the group claim that grants ntopng admin role; empty → all users are unprivileged |
| `ntopng.prefs.oidc.auto_create_users` | `"0"` / `"1"` | `"0"` | Automatically create an ntopng user on first OIDC login |

### Minimal Example (via redis-cli)

```sh
redis-cli set ntopng.prefs.oidc.enabled           "1"
redis-cli set ntopng.prefs.oidc.client_id          "ntopng"
redis-cli set ntopng.prefs.oidc.client_secret      "s3cr3t"
redis-cli set ntopng.prefs.oidc.issuer_url         "https://keycloak.example.com/realms/myrealm"
redis-cli set ntopng.prefs.oidc.base_redirect_uri  "https://ntopng.example.com"
redis-cli set ntopng.prefs.oidc.admin_group        "ntopng-admins"
redis-cli set ntopng.prefs.oidc.auto_create_users  "1"
```

The IdP must have `https://ntopng.example.com/oidc_callback` registered as an
allowed redirect URI.

---

## Implementation Details

### Key Files

| File | Role |
|------|------|
| `include/OIDCAuthenticator.h` | Class declaration |
| `src/OIDCAuthenticator.cpp` | Full implementation |
| `include/ntop_defines.h` | URL and Redis key constants (`OIDC_*`, `PREF_OIDC_*`) |
| `include/Ntop.h` | `OIDCAuthenticator* oidcAuth` member + `getOIDCAuthenticator()` getter |
| `include/ntop_includes.h` | `#include "OIDCAuthenticator.h"` entry |
| `src/Ntop.cpp` | Instantiation in constructor, deletion in destructor |
| `src/HTTPserver.cpp` | `oidc_start()` / `oidc_callback()` handler functions; URL whitelist; route dispatch |
| `scripts/lua/login.lua` | "Login with SSO" button (conditional on `oidc.enabled`) |
| `scripts/lua/admin/prefs.lua` | POST handler to save OIDC preferences from the web UI |
| `scripts/lua/rest/v2/get/ntopng/oidc_config.lua` | REST GET endpoint |
| `scripts/lua/rest/v2/set/ntopng/oidc_config.lua` | REST POST/SET endpoint |
| `scripts/locales/en.lua` | `login.sso_login` and `login.oidc-error` i18n strings |

### C++ Class: OIDCAuthenticator

The class lives in `include/OIDCAuthenticator.h` / `src/OIDCAuthenticator.cpp`
and is owned by the `Ntop` singleton as `oidcAuth` (always instantiated, never
guarded by a compile-time `#ifdef`).

```
Ntop
 └── OIDCAuthenticator* oidcAuth
      ├── startAuthFlow(referer)  → authorization URL (string)
      └── handleCallback(code, state, ...)  → bool + username/group/referer
```

#### Key Methods

```cpp
// Returns true when ntopng.prefs.oidc.enabled == "1"
bool isEnabled() const;

// Generates state+nonce, stores them in Redis, and returns the full IdP
// authorization URL to redirect the browser to.
std::string startAuthFlow(const char *referer);

// Validates state, exchanges code for tokens, validates JWT, maps to a
// ntopng user.  Returns true and populates username/group/referer on success.
bool handleCallback(const char *code, const char *state,
                    std::string &username, std::string &group,
                    std::string &referer_out);
```

#### Internal Structure

```
startAuthFlow()
  └── loadConfig()                      reads all prefs from Redis
  └── ensureEndpointsLoaded()           fetches .well-known/openid-configuration (1h cache)
  └── generateRandom()                  crypto-random state + nonce (OpenSSL RAND_bytes)
  └── storeState()                      Redis key "oidc.state.<state>" with 10-min TTL
  └── builds authorization URL

handleCallback()
  └── popState()                        validates + atomically deletes state from Redis
  └── loadConfig()
  └── ensureEndpointsLoaded()
  └── curlPostForm()                    POST to token_endpoint (form-encoded)
  └── getJWKS()                         fetches jwks_uri (1h cache)
  └── parseAndValidateJWT()
        └── base64urlDecode()
        └── verifySignature()
              └── buildRSAKeyFromJWK() or buildECKeyFromJWK()
              └── EVP_DigestVerify*()
        └── validates iss, aud, exp, nonce
        └── extracts preferred_username / email / sub
        └── checks group_claim for admin_group membership
  └── username sanitization
  └── auto-create user via ntop->addUser() if configured
```

#### Thread Safety

`OIDCAuthenticator` is shared across all Mongoose worker threads.
The `Endpoints` discovery cache and the JWKS cache are protected by
`pthread_mutex_t mutex_`.  Configuration reads go directly to Redis on each
request (same pattern used by RADIUS and HTTP auth).

### HTTP Endpoints

Two new endpoints are registered in `src/HTTPserver.cpp`:

#### `GET /oidc_start`

Query parameters:
- `referer` — URL to redirect to after successful login (must start with `/`)

Behaviour:
1. Checks `OIDCAuthenticator::isEnabled()`.
2. Calls `startAuthFlow(referer)` to get the IdP authorization URL.
3. Responds with `HTTP 302 → <authorization_url>`.

On error: redirects to `/lua/login.lua?reason=oidc-error`.

#### `GET /oidc_callback`

Query parameters (set by IdP):
- `code` — authorization code
- `state` — echoed state value
- `error` — present when the IdP rejects the request (e.g. `access_denied`)

Behaviour:
1. If `error` is present, redirects to login with `reason=oidc-error`.
2. Calls `handleCallback(code, state, ...)`.
3. On success: calls `set_session_cookie()` and redirects to the stored referer.
4. On failure: redirects to login with `reason=oidc-error`.

Both endpoints are added to `isWhitelistedURI()` so they are reachable without
an existing session.

### JWT Validation

The id_token is a JSON Web Token (JWT) with three base64url-encoded parts:
`<header>.<payload>.<signature>`.

Validation steps in `parseAndValidateJWT()`:

1. **Split** on `.` → header, payload, signature.
2. **Decode header** → extract `alg` (required) and `kid` (optional).
3. **Algorithm check** — only `RS256/RS384/RS512` and `ES256/ES384/ES512` are
   accepted.  `none` and symmetric algorithms are rejected.
4. **Signature verification** via `verifySignature()`:
   - Parse JWKS, find the key matching `kid` (and `use=sig` if present).
   - Build an `EVP_PKEY` from the JWK's raw parameters:
     - RSA: decode `n` (modulus) and `e` (public exponent) from base64url,
       build RSA key via `RSA_set0_key()`.
     - EC (P-256/P-384/P-521): decode `x` and `y` coordinates from base64url,
       build EC key via `EC_KEY_set_public_key_affine_coordinates()`.
   - For ES* algorithms, convert the raw `R||S` signature to ASN.1 DER format
     required by OpenSSL's `EVP_DigestVerifyFinal`.
   - Verify using `EVP_DigestVerify*()` with the appropriate digest
     (SHA-256/384/512 selected by algorithm suffix).
5. **Decode payload** → validate standard claims:
   - `iss` — must equal `endpoints_.issuer` (from discovery document).
   - `aud` — must contain `client_id` (string or array).
   - `exp` — must be in the future (`time(NULL)`).
   - `nonce` — must match the value stored in Redis for this state.
6. **Extract user info**:
   - Username: `preferred_username` → `email` → `sub` (in priority order).
   - Email: `email` claim.
   - Admin: check `group_claim` claim (string or array) for `admin_group`.

#### JWKS Key Selection

The JWKS may contain multiple keys.  Key selection logic:

1. If the JWT header contains a `kid`, skip keys with a different `kid`.
2. Skip keys with `use` set to something other than `sig`.
3. Use the first matching key whose `kty` is `RSA` or `EC`.
4. If no key matches after applying filters, log a warning and return failure.

### State and Nonce Management

CSRF protection and replay prevention are handled via a short-lived Redis key:

```
Key:   oidc.state.<state_value>
Value: <nonce>|<referer>
TTL:   600 seconds (OIDC_STATE_TTL)
```

- **`state`** is a 32-byte cryptographically random value (base64url-encoded via
  `RAND_bytes`).  It prevents CSRF attacks on the callback endpoint.
- **`nonce`** is a 32-byte cryptographically random value included in the
  authorization request and verified inside the JWT payload.  It prevents
  token replay attacks.
- `popState()` performs a Redis `GET` followed by `DEL` — if the same callback
  URL is hit twice (e.g. browser back button), the second request will fail
  because the key no longer exists.

### User Mapping and Auto-Creation

After successful JWT validation the username is derived as follows:

1. Use `preferred_username` claim if present and non-empty.
2. Fall back to `email` claim.
3. Fall back to `sub` (subject) claim.

The derived string is then **sanitized**:
- Lowercased.
- Only `[a-z0-9._-]` characters kept; `@` is replaced with `_`.
- Truncated to `NTOP_USERNAME_MAXLEN - 1` characters.

**Admin role assignment** is determined by checking whether the configured
`group_claim` contains the configured `admin_group` value (supports both
string-valued and array-valued claims).  An empty `admin_group` means all OIDC
users get the unprivileged role.

**`auto_create_users = 1`** (opt-in):
- If the derived username does not exist in ntopng (`ntop->existsUser()`
  returns false), `ntop->addUser()` is called with:
  - A random password (the user will never need it).
  - `full_name` set to the email address if available.
  - Group set to admin or unprivileged based on claims.
  - No special network/interface/pool restrictions.

**`auto_create_users = 0`** (default):
- The ntopng user must be pre-created manually (with any password).  If the
  derived username does not exist, the login is rejected.  This allows an
  administrator to control which IdP users can access ntopng.

---

## Login Page Integration

`scripts/lua/login.lua` reads the `ntopng.prefs.oidc.enabled` preference via
`ntop.getPref()` and conditionally renders a "Login with SSO" button:

```lua
local oidc_enabled = ntop.getPref("ntopng.prefs.oidc.enabled") == "1"
if oidc_enabled then
  -- renders an <a> tag pointing to /oidc_start?referer=<current_referer>
end
```

The button is rendered **outside** the credentials `<form>` so it functions as
a plain link, not a form submission.  The `referer` query parameter carries the
page the user was originally trying to access so they land there after login.

---

## REST API

### GET `/lua/rest/v2/get/ntopng/oidc_config.lua`

Returns current OIDC configuration.  The `client_secret` field is always
masked as `"********"` in the response.  Requires `preferences` capability.

**Example response:**
```json
{
  "rc": 0,
  "rc_str": "OK",
  "rsp": {
    "enabled": true,
    "client_id": "ntopng",
    "client_secret": "********",
    "issuer_url": "https://keycloak.example.com/realms/myrealm",
    "scopes": "openid profile email roles",
    "group_claim": "groups",
    "admin_group": "ntopng-admins",
    "base_redirect_uri": "https://ntopng.example.com",
    "auto_create_users": true
  }
}
```

### POST `/lua/rest/v2/set/ntopng/oidc_config.lua`

Saves OIDC configuration.  Accepts both form-encoded and JSON body.
Requires `preferences` capability.

**Request fields** (all optional; omitted fields are not changed):

| Field | Type | Notes |
|-------|------|-------|
| `enabled` | bool / `"0"`/`"1"` | |
| `client_id` | string | |
| `client_secret` | string | Ignored if value is `"********"` |
| `issuer_url` | string | |
| `scopes` | string | Default `"openid profile email roles"` if blank |
| `group_claim` | string | Default `"groups"` if blank |
| `admin_group` | string | |
| `base_redirect_uri` | string | |
| `auto_create_users` | bool / `"0"`/`"1"` | |

**Example curl:**
```sh
curl -u admin:password -X POST \
  'https://ntopng.example.com/lua/rest/v2/set/ntopng/oidc_config.lua' \
  -H 'Content-Type: application/json' \
  -d '{
    "enabled": true,
    "client_id": "ntopng",
    "client_secret": "s3cr3t",
    "issuer_url": "https://keycloak.example.com/realms/myrealm",
    "base_redirect_uri": "https://ntopng.example.com",
    "admin_group": "ntopng-admins",
    "auto_create_users": true
  }'
```

---

## Preferences UI

OIDC settings are handled in `scripts/lua/admin/prefs.lua` under the `auth` tab
(same tab as LDAP, RADIUS, and HTTP auth settings).  POST fields:

| POST field | Redis key updated |
|-----------|-------------------|
| `toggle_oidc_auth` | `ntopng.prefs.oidc.enabled` |
| `oidc_client_id` | `ntopng.prefs.oidc.client_id` |
| `oidc_client_secret` | `ntopng.prefs.oidc.client_secret` (skipped if `"********"`) |
| `oidc_issuer_url` | `ntopng.prefs.oidc.issuer_url` |
| `oidc_scopes` | `ntopng.prefs.oidc.scopes` |
| `oidc_group_claim` | `ntopng.prefs.oidc.group_claim` |
| `oidc_admin_group` | `ntopng.prefs.oidc.admin_group` |
| `oidc_base_redirect_uri` | `ntopng.prefs.oidc.base_redirect_uri` |
| `toggle_oidc_auto_create_users` | `ntopng.prefs.oidc.auto_create_users` |

> **Note:** A Vue component for the OIDC settings form in the auth tab still
> needs to be added to `http_src/vue/`.  See `README.GUI.frontend.md` for
> the frontend development workflow.

---

## Dependencies

No new runtime dependencies are introduced.  All required libraries are already
mandatory for building ntopng:

| Library | Minimum version | Notes |
|---------|----------------|-------|
| libcurl | any recent | Used for HTTP GET/POST to IdP |
| OpenSSL | 1.1+ (3.0+ recommended) | RSA/EC low-level APIs used; deprecation warnings suppressed for OpenSSL 3.0 via `#pragma GCC diagnostic` |
| json-c | any | Bundled in `third-party/json-c/` |

---

## Security Considerations

| Concern | Mitigation |
|---------|-----------|
| CSRF on callback | Cryptographic `state` parameter verified against Redis |
| Token replay | `nonce` claim included in authorization request and verified in JWT |
| State enumeration | State values are 192-bit random (32 bytes via `RAND_bytes`), TTL 10 min |
| Signature forgery | `alg: none` and symmetric algorithms rejected; only RS*/ES* accepted |
| Token expiry | `exp` claim validated against `time(NULL)` |
| Audience mismatch | `aud` claim must contain `client_id` |
| Open redirects | `referer` must begin with `/` before being used as a redirect target |
| Username injection | Derived usernames are sanitized to `[a-z0-9._-]` |
| Client secret exposure | Secret is stored in Redis; GET config API masks it as `"********"` |
| HTTP vs HTTPS | The `Secure` flag is added to session cookies when the connection is HTTPS (existing `get_secure_cookie_attributes()` logic) |

### Recommended Production Checklist

- [ ] ntopng is served over HTTPS.
- [ ] `base_redirect_uri` uses HTTPS.
- [ ] The IdP's allowed redirect URIs list contains exactly
      `{base_redirect_uri}/oidc_callback` (no wildcards).
- [ ] `client_secret` is rotated periodically at the IdP and updated in Redis.
- [ ] `auto_create_users` is disabled in high-security environments; users are
      pre-provisioned manually.
- [ ] `admin_group` is set to a specific group that only trusted users belong
      to; leave empty to deny admin access to all OIDC users.

---

## Testing with a Local IdP

[Keycloak](https://www.keycloak.org/) can be run locally via Docker for
development and testing:

```sh
docker run -p 8080:8080 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:latest start-dev
```

1. Open `http://localhost:8080` → Administration Console.
2. Create a realm (e.g. `ntopng-test`).
3. Create a client:
   - Client ID: `ntopng`
   - Client authentication: ON (confidential client)
   - Valid redirect URIs: `http://localhost:3000/oidc_callback`
   - Copy the client secret from the **Credentials** tab.
4. Create a group `ntopng-admins` and add your test user to it.
5. Add `groups` as a token claim:
   - Client → Client scopes → `ntopng-dedicated` → Add mapper → Group membership
   - Token Claim Name: `groups`, Full group path: OFF.
6. Configure ntopng:

```sh
redis-cli set ntopng.prefs.oidc.enabled           "1"
redis-cli set ntopng.prefs.oidc.client_id          "ntopng"
redis-cli set ntopng.prefs.oidc.client_secret      "<secret from step 3>"
redis-cli set ntopng.prefs.oidc.issuer_url         "http://localhost:8080/realms/ntopng-test"
redis-cli set ntopng.prefs.oidc.base_redirect_uri  "http://localhost:3000"
redis-cli set ntopng.prefs.oidc.admin_group        "ntopng-admins"
redis-cli set ntopng.prefs.oidc.auto_create_users  "1"
```

7. Start ntopng on port 3000: `./ntopng -w 3000`.
8. Open `http://localhost:3000` → login page should show "Login with SSO".

---

## Extending the Implementation

### Adding MFA for OIDC Users

Currently, OIDC-authenticated users skip ntopng's own TOTP MFA step (the IdP
is expected to enforce its own MFA).  To add ntopng MFA on top of OIDC:

In `src/HTTPserver.cpp`, `oidc_callback()`, after the `handleCallback()` call
succeeds:

```cpp
if (ntop->isTOTPEnabled(out_username.c_str())) {
  char token[33];
  if (ntop->createMFAPendingToken(out_username.c_str(), out_group.c_str(),
                                  false /* not a local user */,
                                  referer.c_str(), token, sizeof(token))) {
    redirect_to_mfa(conn, token);
    return;
  }
}
// otherwise fall through to set_session_cookie()
```

### Supporting PKCE

For public clients (no client secret), extend `startAuthFlow()` to generate a
`code_verifier` / `code_challenge` pair and include `code_challenge` and
`code_challenge_method=S256` in the authorization URL.  Pass `code_verifier`
to `handleCallback()` and include it in the token exchange POST body.

### Supporting the Userinfo Endpoint

Some IdPs do not include all claims in the id_token but expose them at the
`userinfo_endpoint`.  After a successful token exchange, make an additional
`GET {userinfo_endpoint}` request with `Authorization: Bearer <access_token>`
and merge the resulting JSON into the claims used for username/group mapping.

### Caching Endpoints and JWKS Invalidation

The discovery document and JWKS are cached for 1 hour (`3600` seconds).
Forced invalidation (e.g. after IdP key rotation) can be triggered by:

```sh
# Force re-discovery on next request
redis-cli del "ntopng.prefs.oidc.*"  # or restart ntopng
```

Alternatively, add a REST endpoint that calls
`oidcAuth->invalidateCache()` (not yet implemented).
