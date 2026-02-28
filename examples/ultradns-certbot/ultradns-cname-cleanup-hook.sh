#!/bin/bash
# Certbot --manual-cleanup-hook: Deletes _acme-challenge TXT record via UltraDNS REST API.
#
# CNAME delegation variant: mirrors ultradns-cname-auth-hook.sh.
# Deletes the delegated owner record from ULTRADNS_ZONE_NAME (challenge-zone.com), e.g.:
#   owner  : _acme-challenge.www.example.com
#   zone   : challenge-zone.com
#   full   : _acme-challenge.www.example.com.challenge-zone.com.
#
# Certbot environment variables: CERTBOT_DOMAIN, CERTBOT_VALIDATION

set -euo pipefail

source "$(dirname "$0")/ultradns.conf"
source "$(dirname "$0")/ultradns-get-token.sh"

# CERTBOT_DOMAIN is NOT a subdomain of ULTRADNS_ZONE_NAME, so we use it verbatim as
# the owner label within ULTRADNS_ZONE_NAME. No suffix stripping needed.
RECORD_OWNER="_acme-challenge.${CERTBOT_DOMAIN}"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
  "${API}/zones/${ULTRADNS_ZONE_NAME}./rrsets/TXT/${RECORD_OWNER}" \
  "${AUTH[@]}")

# 200/204 = deleted, 404 = already gone — both are acceptable for cleanup
[[ "${HTTP_STATUS}" =~ ^(200|204|404)$ ]] || echo "WARN: DELETE returned HTTP ${HTTP_STATUS}" >&2
