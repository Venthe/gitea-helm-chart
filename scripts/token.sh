#!/bin/sh

set -eu

check_token() {
  set +e

  echo "Checking for existing token..."
  token="$(kubectl get secret "$SECRET_NAME" -o jsonpath="{.data['token']}" 2> /dev/null)"
  [ $? -ne 0 ] && return 1
  [ -z "$token" ] && return 2
  return 0
}

create_token() {
  echo "Waiting for new token to be generated..."
  begin=$(date +%s)
  end=$((begin + 300)) # 5 minutes
  while true; do
    [ -f /data/actions/token ] && return 0
    [ "$(date +%s)" -gt $end ] && return 1
    sleep 5
  done
}

store_token() {
  echo "Storing the token in Kubernetes secret..."
  kubectl patch secret "$SECRET_NAME" -p "{\"data\":{\"token\":\"$(base64 /data/actions/token | tr -d '\n')\"}}"
}

if check_token; then
  echo "Key already in place, exiting."
  exit
fi

if ! create_token; then
  echo "Timed out waiting for a token to appear."
  exit 1
fi

store_token
