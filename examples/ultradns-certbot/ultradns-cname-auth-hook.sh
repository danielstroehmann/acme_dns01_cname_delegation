#!/bin/bash
# Certbot --manual-auth-hook: Creates _acme-challenge TXT record via UltraDNS REST API.
#
# CNAME delegation variant: CERTBOT_DOMAIN belongs to a *different* zone (e.g. example.com),
# but a CNAME already points _acme-challenge.<CERTBOT_DOMAIN> to
# _acme-challenge.<CERTBOT_DOMAIN>.<ULTRADNS_ZONE_NAME>.
# This hook therefore creates the TXT record under that delegated owner name inside
# ULTRADNS_ZONE_NAME (challenge-zone.com), e.g.:
#   owner  : _acme-challenge.www.example.com
#   zone   : challenge-zone.com
#   full   : _acme-challenge.www.example.com.challenge-zone.com.
#
# Certbot environment variables: CERTBOT_DOMAIN, CERTBOT_VALIDATION, CERTBOT_REMAINING_CHALLENGES

set -euo pipefail

DNS_PROPAGATION_WAIT=60

source "$(dirname "$0")/ultradns.conf"
source "$(dirname "$0")/ultradns-get-token.sh"

# CERTBOT_DOMAIN is NOT a subdomain of ULTRADNS_ZONE_NAME, so we use it verbatim as
# the owner label within ULTRADNS_ZONE_NAME. No suffix stripping needed.
RECORD_OWNER="_acme-challenge.${CERTBOT_DOMAIN}"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${API}/zones/${ULTRADNS_ZONE_NAME}./rrsets/TXT/${RECORD_OWNER}" \
  "${AUTH[@]}" \
  -H "Content-Type: application/json" \
  --data "{\"ttl\":120,\"rdata\":[\"${CERTBOT_VALIDATION}\"]}")

[ "${HTTP_STATUS}" = "201" ] || { echo "ERROR: Failed to create TXT record (HTTP ${HTTP_STATUS})" >&2; exit 1; }

if [ "${CERTBOT_REMAINING_CHALLENGES}" -eq 0 ]; then sleep "${DNS_PROPAGATION_WAIT}"; fi
