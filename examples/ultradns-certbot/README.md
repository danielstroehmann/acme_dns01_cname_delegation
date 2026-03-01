# Certbot UltraDNS CNAME-Delegation Hooks

Certbot `--manual-auth-hook` / `--manual-cleanup-hook` scripts that automate ACME DNS-01
certificate issuance via the **UltraDNS REST API** using the
[CNAME delegation technique](https://datatracker.ietf.org/doc/html/rfc8555#section-8.4).

## When to use this

Use these hooks when:

- The domain you want to certify lives in a DNS zone you **cannot automate directly** (no API,
  third-party control, or restricted write access), and
- You control a **separate UltraDNS zone** that can serve as the ACME challenge target.

A one-time CNAME in the primary zone delegates all future `_acme-challenge` lookups to your
UltraDNS challenge zone. After that, renewals run fully unattended without ever touching the
primary zone again.

For a detailed explanation of the technique see
[README.md](../../README.md) on project level.

## Files

| File | Description |
|---|---|
| `ultradns-cname-auth-hook.sh` | Creates the `_acme-challenge` TXT record |
| `ultradns-cname-cleanup-hook.sh` | Deletes the `_acme-challenge` TXT record |
| `ultradns-get-token.sh` | Shared helper: obtains and caches a Bearer token |
| `ultradns.conf.example` | Configuration template — copy to `ultradns.conf` and fill in |

## Setup

### 1. One-time DNS setup (primary zone)

Add a permanent CNAME in the zone that is authoritative for your domain:

```
_acme-challenge.www.example.com.  IN  CNAME  _acme-challenge.www.example.com.challenge-zone.com.
```

For a wildcard certificate you need an additional CNAME for the apex:

```
_acme-challenge.example.com.      IN  CNAME  _acme-challenge.example.com.challenge-zone.com.
```

Replace `challenge-zone.com` with your actual UltraDNS zone name.

### 2. Configure credentials

```bash
cp ultradns.conf.example ultradns.conf
chmod 600 ultradns.conf
$EDITOR ultradns.conf
```

`ultradns.conf` is listed in `.gitignore` and will never be committed.

### 3. Run certbot

```bash
certbot certonly \
  --manual \
  --preferred-challenges dns \
  --manual-auth-hook   /path/to/ultradns-cname-auth-hook.sh \
  --manual-cleanup-hook /path/to/ultradns-cname-cleanup-hook.sh \
  -d www.example.com
```

For subsequent renewals add `--manual-auth-hook` / `--manual-cleanup-hook` to your
renewal configuration or use `certbot renew`.

## Requirements

- `bash` 4+
- `curl`
- A UltraDNS account with write access to the challenge zone

## Configuration reference (`ultradns.conf`)

| Variable | Description |
|---|---|
| `ULTRADNS_USERNAME` | UltraDNS account username |
| `ULTRADNS_PASSWORD` | UltraDNS account password |
| `ULTRADNS_ZONE_NAME` | The challenge zone name (e.g. `challenge-zone.com`) |

The token is cached in `/tmp` for the duration of its validity to avoid repeated logins
across multiple hook invocations in a single certbot run.

## Security notes

- `ultradns.conf` is `chmod 600` — keep it that way.
- The token cache file (`/tmp/.ultradns_token_*`) is also created with `chmod 600`.
- Automation credentials only need write access to the challenge zone, not to any production DNS zone.
