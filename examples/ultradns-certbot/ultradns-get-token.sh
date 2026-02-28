#!/bin/bash
# Shared helper: returns a valid UltraDNS Bearer token, using a file-based cache
# to avoid repeated logins across hook invocations.
#
# Expects to be sourced AFTER ultradns.conf (needs ULTRADNS_USERNAME / ULTRADNS_PASSWORD).
# Sets ACCESS_TOKEN and AUTH in the calling shell.
# Defines API if not already set.

API="${API:-https://api.ultradns.com}"
_TOKEN_CACHE="/tmp/.ultradns_token_$(echo "${ULTRADNS_USERNAME}" | tr -dc '[:alnum:]')"

_get_ultradns_token() {
  local now
  now=$(date +%s)

  if [[ -f "${_TOKEN_CACHE}" ]]; then
    local cached_expiry cached_token
    cached_expiry=$(cut -d: -f1 "${_TOKEN_CACHE}")
    cached_token=$(cut -d: -f2- "${_TOKEN_CACHE}")
    if [[ -n "${cached_token}" && "${now}" -lt "${cached_expiry}" ]]; then
      ACCESS_TOKEN="${cached_token}"
      AUTH=(-H "Authorization: Bearer ${ACCESS_TOKEN}")
      return 0
    fi
  fi

  local token_response expires_in expiry
  token_response=$(curl -s -X POST "${API}/authorization/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "username=${ULTRADNS_USERNAME}" \
    --data-urlencode "password=${ULTRADNS_PASSWORD}")

  ACCESS_TOKEN=$(echo "${token_response}" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
  [[ -z "${ACCESS_TOKEN}" ]] && { echo "ERROR: UltraDNS authentication failed: ${token_response}" >&2; exit 1; }

  expires_in=$(echo "${token_response}" | grep -o '"expiresIn":[0-9]*' | cut -d: -f2)
  # Cache with 120-second safety margin; fall back to 1 hour if expiresIn is missing
  expiry=$(( now + ${expires_in:-3600} - 120 ))

  echo "${expiry}:${ACCESS_TOKEN}" > "${_TOKEN_CACHE}"
  chmod 600 "${_TOKEN_CACHE}"

  AUTH=(-H "Authorization: Bearer ${ACCESS_TOKEN}")
}

_get_ultradns_token
