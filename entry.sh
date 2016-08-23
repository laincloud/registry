#!/bin/bash

sleep 5

etcd_endpoint="http://etcd.lain:4001"
registry_auth_key="/lain/config/auth/registry"

result=$(python auth/auth-check $etcd_endpoint $registry_auth_key)
IFS=',' read -r -a configs <<< "$result"

if [ "${configs[0]}" = "True" ]; then
    echo "should open auth"
    export REGISTRY_AUTH_TOKEN_REALM="${configs[1]}"
    export REGISTRY_AUTH_TOKEN_ISSUER="${configs[2]}"
    export REGISTRY_AUTH_TOKEN_SERVICE="${configs[3]}"
else
    echo "should close auth"
    export REGISTRY_AUTH=""
fi

registry garbage-collect config.yml

sleep 5

exec registry serve config.yml
