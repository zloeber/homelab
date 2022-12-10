#!/bin/sh
sourced=0
if [ -n "$ZSH_EVAL_CONTEXT" ]; then 
  case $ZSH_EVAL_CONTEXT in *:file) sourced=1;; esac
elif [ -n "$KSH_VERSION" ]; then
    # shellcheck disable=SC2296,SC2046,SC2086 # nameref used
    [ "$(cd $(dirname -- $0) && pwd -P)/$(basename -- $0)" != "$(cd $(dirname -- ${.sh.file}) && pwd -P)/$(basename -- ${.sh.file})" ] && sourced=1
elif [ -n "$BASH_VERSION" ]; then
    (return 0 2>/dev/null) && sourced=1 
else # All other shells: examine $0 for known shell binary filenames
    # Detects `sh` and `dash`; add additional shell filenames as needed.
    case ${0##*/} in sh|dash) sourced=1;; esac
fi

if [ $sourced = "0" ]; then
    echo "This file is meant to be sourced, not executed" && 
    exit 30
fi

## Common/Helper functions
info () {
    printf "\033[2K[ \033[00;34mINFO\033[0m ] %s\n" "${1}"
}

debug () {
    if [ "$DEBUG_ENABLED" ]; then
        info "${1}"
    fi
}

eecho () {
    printf "\033[2K[ \033[00;34mINFO\033[0m ] %s\n" "${1}"
}

success () {
    printf "\r\033[2K[ \033[00;32mOK\033[0m ] %s\n" "${1}"
}

error () {
    _message=${1:-"Script Failure"}
    _errorcode=${2:-1}
    printf "\r\033[2K[\033[0;31mERROR\033[0m] %s\n" "${_message}"
    if [ "${CI}" = "true"  ]; then
        exit "${_errorcode}"
    else
        return "${_errorcode}"
    fi
}

warn () {
    printf "\r\033[2K[\033[0;33mWARNING\033[0m] %s\n" "${1}"
}

# Ensures that a required binary exists in current $PATH
# Usage: require <command name>
require() {
    _commandname=$1
    _not_found=0

    for _commandname; do
        if ! command -v -- "${_commandname}" > /dev/null 2>&1; then
            warn "Required binary check: ${_commandname}"
            _not_found=$((_not_found+1))
        else
            success "Required binary check: ${_commandname}"
        fi
    done

    if [ "$_not_found" -gt 0 ]; then
        error "Missing requirements: ${_not_found}"
    fi
}

# Scrapes the Hashicorp release endpoint for valid versions
# Usage: get_hashicorp_version <app>
get_hashicorp_version() {
	_vendorapp="${1?"Usage: $0 app"}"
    _IGNORED_EXT='(tar\.gz\.asc|\.txt|\.tar\.xz|\.asc|\.MD|\.hsm|\+ent\.hsm|\.rpm|\.deb|\.sha256|\.src\.tar\.gz|\.sig|SHA256SUM|\.log|homebrew|alpha|beta)'

	# Scrape HTML from release page for binary versions, which are 
	# given as ${binary}_<version>. We just use sed to extract.
    curl -s "https://releases.hashicorp.com/${_vendorapp}/" | grep -v -E "${IGNORED_EXT}" | sed -n "s/.*${_vendorapp}_\([0-9][^<]*\)<.*/\1/p" | sed -n 1p
}

# Scrapes the Hashicorp release endpoint for valid versions
# Usage: get_hashicorp_version <app>
get_hashicorp_versions() {
	_vendorapp="${1?"Usage: $0 app"}"
    _IGNORED_EXT='(tar\.gz\.asc|\.txt|\.tar\.xz|\.asc|\.MD|\.hsm|\+ent\.hsm|\.rpm|\.deb|\.sha256|\.src\.tar\.gz|\.sig|SHA256SUM|\.log|homebrew|alpha|beta)'

	# Scrape HTML from release page for binary versions, which are 
	# given as ${binary}_<version>. We just use sed to extract.
    curl -s "https://releases.hashicorp.com/${_vendorapp}/" | grep -v -E "${IGNORED_EXT}" | sed -n "s/.*${_vendorapp}_\([0-9][^<]*\)<.*/\1/p"
}


## VAULT_ENVIRONMENT handling
vault_cluster_address() {
    if [ "${VAULT_ADDR}" = "" ]; then
        warn "VAULT_ADDR not set, looking up address based on VAULT_ENVIRONMENT"
        # Uses VAULT_ENVIRONMENT to export the proper VAULT_ADDR
        # If neither are passed then nothing is exported.
        info "VAULT_ENVIRONMENT: ${VAULT_ENVIRONMENT}"
        _TARGET_VAULT_ENV=${VAULT_ENVIRONMENT:-"local"} 

        # Our current environment targets
        _local=http://127.0.0.1:8200
        _poc=https://vault.myorgpoc.aws.myorg.com
        _dev=https://vault-dev.myorgnon.aws.myorg.com
        _int=https://vault-int.myorgnon.aws.myorg.com
        _prod=https://vault.myorg.aws.myorg.com
        _target_venv=""

        # Lowercase the target environment
        if [ -n "$_TARGET_VAULT_ENV" ]; then
            target_venv=$(echo ${_TARGET_VAULT_ENV} | tr '[:upper:]' '[:lower:]')
        fi

        case "$target_venv" in
            local)
                export VAULT_ADDR=$_local
                ;;
            poc)
                export VAULT_ADDR=$_poc
                ;;
            dev)
                export VAULT_ADDR=$_dev
                ;;
            int|non|nonprod|nprd|nonprd|stage|stg)
                export VAULT_ADDR=$_int
                ;;
            prod|production|prd)
                export VAULT_ADDR=$_prod
                ;;
            *)
                export VAULT_ADDR=$_local
                ;;
        esac
    else
        success "VAULT_ADDR already set!"
    fi
    info "VAULT_ADDR: ${VAULT_ADDR}"
}

## Vault Auth Functions
# These should emit 'VAULT_TOKEN' for further access into vault

## Gitlab authentication
vault_auth_gitlab() {
    # Attempt to use gitlab JWT based auth to get a VAULT_TOKEN
    _gitlab_auth_mount=${VAULT_GITLAB_AUTH_MOUNT:-"jwt_gitlab"}
    _gitlab_role=${VAULT_GITLAB_ROLE:-$(echo "$CI_PROJECT_PATH" | tr "/" "_")}

    info "gitlab_role=${_gitlab_role}"
    info "gitlab_auth_mount=${_gitlab_auth_mount}"

    if [ -n "${VAULT_ADDR}" ] && [ -n "$CI_JOB_JWT" ] && [ -n "$_gitlab_role" ]; then
        info "Attempting Vault authentication via Gitlab JWT role..."
        _vault_cmd_output=$(curl \
            -s --header "Accept: application/json" \
            --request POST \
            --data "{\"jwt\":\"${CI_JOB_JWT}\",\"role\":\"${_gitlab_role}\"}" "${VAULT_ADDR}/v1/auth/${_gitlab_auth_mount}/login" 2>&1) && _exit_status=$? || _exit_status=$?
        #_vault_cmd_output=$(vault write -field=token auth/${gitlab_auth_mount}/login role=${gitlab_role} jwt=$CI_JOB_JWT 2>&1) && _exit_status=$? || _exit_status=$?
        if [ "${_exit_status}" = 0 ]; then
            info "Gitlab vault JWT auth success! Exporting VAULT_TOKEN"
            VAULT_TOKEN="$(echo ${_vault_cmd_output} | jq -r .auth.client_token)"
            export VAULT_TOKEN
        else
            error "Gitlab vault JWT auth failure - ${_vault_cmd_output}" "${_exit_status}"
        fi
    else
        error "Requires the following environment variables: VAULT_ADDR, CI_JOB_JWT, and VAULT_GITLAB_ROLE"
    fi
}

vault_auth_approle() {
    # Attempt to use gitlab JWT based auth to get a VAULT_TOKEN
    _vault_approle_mount=${VAULT_APPROLE_MOUNT:-"approle"}
    info "vault_approle_mount: ${_vault_approle_mount}"
    info "VAULT_APPROLE_ROLE: ${VAULT_APPROLE_ROLE}"

    if [ -n "$VAULT_ADDR" ] && [ -n "$VAULT_APPROLE_ROLE" ]; then
        info "Attempting Vault authentication via AppRole"

        # If VAULT_APPROLE_ID is not defined then attempt to get it from vault
        if [ -z "$VAULT_APPROLE_ID" ]; then
            info "VAULT_APPROLE_ID missing, attempting to pull from vault"
            _vault_cmd_output=$(vault read "auth/${_vault_approle_mount}/role/${VAULT_APPROLE_ROLE}/role-id" -format=json | jq -r '.data.role_id' 2>&1) && _exit_status=$? || _exit_status=$?
            if [ "${_exit_status}" = 0 ]; then
                info "Attained the VAULT_APPROLE_ID"
                export VAULT_APPROLE_ID="${_vault_cmd_output}"
            else
                error "Unable to attain the VAULT_APPROLE_ID - ${_vault_cmd_output}" "${_exit_status}"
            fi
        fi
        # If VAULT_APPROLE_SECRET is not defined then attempt to get it from vault
        if [ ! -n "$VAULT_APPROLE_SECRET" ]; then
            info "VAULT_APPROLE_SECRET missing, attempting to pull from vault"
            _vault_cmd_output=$(vault write -f "auth/${_vault_approle_mount}/role/${VAULT_APPROLE_ROLE}/secret-id" -format=json | jq -r '.data.secret_id' 2>&1) && _exit_status=$? || _exit_status=$?
            if [ "${_exit_status}" = 0 ]; then
                info "Attained the VAULT_APPROLE_SECRET"
                export VAULT_APPROLE_SECRET="${_vault_cmd_output}"
            else
                error "Unable to attain the VAULT_APPROLE_SECRET - ${_vault_cmd_output}" "${_exit_status}"
            fi
        fi
        if [ -n "$VAULT_APPROLE_ID" ] && [ -n "$VAULT_APPROLE_SECRET" ]; then
            _vault_cmd_output=$(vault write auth/${_vault_approle_mount}/login role_id="${VAULT_APPROLE_ID}" secret_id="${VAULT_APPROLE_SECRET}" -format=json | jq -r '.auth.client_token' 2>&1) && _exit_status=$? || _exit_status=$?
            if [ "${_exit_status}" = 0 ]; then
                info "Attained the VAULT_TOKEN"
                export VAULT_TOKEN="${_vault_cmd_output}"
            else
                error "Unable to attain the VAULT_TOKEN - ${_vault_cmd_output}" "${_exit_status}"
            fi
        fi
    else
        error "Requires the following environment variables: VAULT_ADDR and VAULT_APPROLE_ROLE"
    fi
}

vault_auth_aws() {
    # If our variables are in place then attempt to assume an AWS role defined in vault
    _vault_aws_mount=${VAULT_AWS_MOUNT:-"aws"}
    #_vault_uri="${VAULT_ADDR/'https:\/\/'/""}"
    _vault_uri=$(echo "$VAULT_ADDR" | sed 's/https:\/\///g')
    info "vault_uri: ${_vault_uri}"
    info "VAULT_AWS_ROLE: ${VAULT_AWS_ROLE}"
    info "vault_aws_mount: ${_vault_aws_mount}"

    # Login to vault
    if [ -n "$VAULT_ADDR" ] && [ -n "$VAULT_AWS_ROLE" ] && [ -n "${_vault_aws_mount}" ]; then
        info "Attempting Vault authentication via AWS IAM role..."
        _vault_cmd_output=$( vault login \
            -method=aws \
            -path="${_vault_aws_mount}" \
            -field=token \
            header_value="${_vault_uri}" \
            role=${VAULT_AWS_ROLE} 2>&1 ) && _exit_status=$? || _exit_status=$?
        if [ "${_exit_status}" = 0 ]; then
            info "AWS IAM vault auth success! Exporting VAULT_TOKEN"
            export VAULT_TOKEN="${_vault_cmd_output}"
        else
            error "AWS IAM vault auth failure - ${_vault_cmd_output}" "${_exit_status}"
        fi
    else
        error "Requires the following environment variables: VAULT_ADDR, VAULT_AWS_MOUNT, and VAULT_AWS_ROLE"
    fi
}

vault_auth_token() {
    # If our variables are in place then attempt to assume an AWS role defined in vault
    if [ -n "$VAULT_ADDR" ] && [ -n  "$VAULT_TOKEN" ]; then
        info "Attempting Vault authentication via token..."
        _vault_cmd_output=$(curl -s \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/auth/token/lookup-self" 2>&1) && _exit_status=$? || _exit_status=$?

        if [ "${_exit_status}" = 0 ]; then
            # Technically this is just informational as VAULT_TOKEN should already be set prior to calling this function
            info "Vault token auth success!"
        else
            error "Vault token authentication failure - ${_vault_cmd_output}" "${_exit_status}"
        fi
    else
        error "Requires the following environment variables: VAULT_ADDR and VAULT_TOKEN"
    fi
}

vault_auth_oidc() {
    require vault

    if [ -n "$VAULT_ADDR" ]; then
        info "Attempting Vault authentication via oidc..."
        #    require openssl
        # require open
        # _client_nonce
        # client_nonce=$(openssl rand -base64 12)
        # _vault_cmd_output=$(curl -s -X PUT \
        #     -H "X-Vault-Request: true" \
        #     -d '{"client_nonce":"'${client_nonce}'","redirect_uri":"http://localhost:8250/oidc/callback","role":""}' \
        #     "${VAULT_ADDR}/v1/auth/oidc/oidc/auth_url"  2>&1 | jq -r '.data.auth_url') && _exit_status=$? || _exit_status=$?

        _vault_cmd_output=$( vault login -method=oidc -token-only -no-store 2>&1 | tail -n 1 ) && _exit_status=$? || _exit_status=$?
        if [ "${_exit_status}" = 0 ]; then
            success "Vault oidc authentication, exporting VAULT_TOKEN"
            export VAULT_TOKEN="${_vault_cmd_output}"
        else
            error "Vault oidc auth failure - ${_vault_cmd_output}" "${_exit_status}"
        fi
    else
        error "Requires the following environment variables: VAULT_ADDR"
    fi
}


seed_vault_aws_sts() {
    require vault

    info "Seeding an AWS STS credential to KV"
    VAULT_KV_PATH=${VAULT_KV_PATH:-"controller/kv"}
    AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
    AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-""}
    AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-""}
    AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN:-""}
    TOKEN_LEASE_ID=${TOKEN_LEASE_ID:-""}
    info "VAULT_ADDR: ${VAULT_ADDR}"
    info "VAULT_KV_PATH: ${VAULT_KV_PATH}"
    info "VAULT_KV_SECRET: ${VAULT_KV_SECRET}"
    info "TOKEN_LEASE_ID: ${TOKEN_LEASE_ID}"
    if [ -n "$VAULT_TOKEN" ]; then
        if [ -n "$VAULT_KV_SECRET" ]; then
            _vault_cmd_output=$( vault kv \
                put "${VAULT_KV_PATH}/${VAULT_KV_SECRET}" \
                    AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}" \
                    AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
                    AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
                    AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" \
                    TOKEN_LEASE_ID="${TOKEN_LEASE_ID}" 2>&1 ) && _exit_status=$? || _exit_status=$?
            if [ "${_exit_status}" = 0 ]; then
                success "Seeding succeeded!"
            else
                error "Unable to seed kv secrets - ${_vault_cmd_output}" "${_exit_status}"
            fi
        else
            error "Seeding requires the following environment variables: VAULT_KV_SECRET"
        fi
    else
        error "Seeding requires the following environment variables: VAULT_ADDR"
    fi
}

vault_auth() {
    _vault_auth_method=${VAULT_AUTH_METHOD:-"token"}
    info "vault_auth_method: ${_vault_auth_method}"

    # Perform vault authentication first
    case ${_vault_auth_method} in
        token)
            vault_auth_token
            ;;
        approle)
            vault_auth_approle
            ;;
        oidc)
            vault_auth_oidc
            ;;
        gitlab)
            vault_auth_gitlab
            ;;
        aws)
            vault_auth_aws
            ;;
        *)
            vault_auth_token
            ;;
    esac
}

vault_token_lookup() {
    # A safer to display version of vault token lookup
    require vault
    vault token lookup -format yml | grep -vxE '[[:blank:]]*(id:.*)?' | grep -vxE '[[:blank:]]*(accessor:.*)?'

    ## Non-safe way to do this without vault binary
    # curl -s \
    #     -H "X-Vault-Token: ${VAULT_TOKEN}" \
    #     -H "X-Vault-Request: true" \
    #     ${VAULT_ADDR}/v1/auth/token/lookup-self | jq
}

# vault_kv_copy_recursive() {
#     require vault
#     _tmpfile
#     tmpfile=$(mktemp /tmp/vault-json-data.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }

#     _FOLDER_RE='^.*/$'

#     _VAULT_SOURCE_ADDR="${VAULT_SOURCE_ADDR:-${VAULT_ADDR:-""}}"
#     _VAULT_TARGET_ADDR="${VAULT_TARGET_ADDR:-${VAULT_ADDR:-""}}"

#     # Arguments:
#     # $1: source_store
#     # $2: target_store
#     # $3: path
#     copy_recursive() {
#         _source_store="${1}"
#         _target_store="${2}"
#         _source_base_path="${source_store}${3}"
#         _target_base_path="${target_store}${3}"

#         _entries=($(vault kv list -format=json "${source_base_path}" | jq -r '.[]'))
#         for entry in "${entries[@]}"; do
#             _source_full_path="${source_base_path}${entry}"
#             info -n "Processing entry ${source_full_path} ... "
#             expr "$entry" : "$FOLDER_RE" > /dev/null
# #           if [ "${entry}" =~ ${FOLDER_RE} ]; then
#                 copy_recursive "${1}" "${2}" "${3}${entry}"
#             else
#                 _target_full_path="${target_base_path}${entry}"
#                 info "${source_store}${source_full_path} -> ${target_store}${source_full_path}"
#                 VAULT_ADDR="${VAULT_SOURCE_ADDR}" vault kv get -format=json "${source_full_path}" | jq -r '.data.data' > "${tmpfile}"
#                 VAULT_ADDR="${VAULT_TARGET_ADDR}" vault kv put "${target_full_path}" @"${tmpfile}"
#             fi
#         done
#     }

#     copy_recursive "$@"

#     if [ -f "${tmpfile}" ]; then
#         rm -f "${tmpfile}" || echo "Unable to delete tmpfile (${tmpfile}). Manual clean up necessary."
#     fi
# }

## Vault KV seeding functions
# seed_vault_kv_secret() {
#     require vault

#     _kv_secret_value=${VAULT_KV_SECRET_VALUE:-""}
#     _kv_secret_name=${VAULT_KV_SECRET_NAME:-"value"}
#     _kv_path="${VAULT_KV_PATH}/${VAULT_KV_SECRET}"
#     info "kv_path: ${kv_path}"
#     info "kv_secret_name: ${kv_secret_name}"
#     info "Attempting KV Secret update to path - ${kv_path}"
#     if [[ "$kv_secret_value" =~ ^@ ]]; then
#         info "Secret is defined as a file, loading"
#         _ src=$(echo "${kv_secret_value}" | cut -c 2-)
#         if file -b --mime-encoding $src | grep -s binary > /dev/null; then
#             info "Secret data is binary, encoding"
#             _vault_cmd_output=$( cat $src | base64 | vault kv put $kv_path \
#                 ${kv_secret_name}=- format="base64"  2>&1 ) \
#                 && _exit_status=$? || _exit_status=$?
#         else
#             info "Secret data is plain text, NOT encoding"
#             _vault_cmd_output=$( cat $src | vault kv put $kv_path ${kv_secret_name}=- format="text" 2>&1 ) \
#                 && _exit_status=$? || _exit_status=$?
#         fi
#     else
#         info "Secret data is NOT a file, seeding as plain text"
#         _vault_cmd_output=$( vault kv put $kv_path \
#             ${kv_secret_name}="${kv_secret_value}" format="text" 2>&1 ) \
#                 && _exit_status=$? || _exit_status=$?
#     fi
#     if [ "${_exit_status}" = 0 ]; then
#         info "Vault kube secret seeding succeeded!"
#     else
#         error "Unable to seed kv secret - ${_vault_cmd_output}" "${_exit_status}"
#     fi
# }

# seed_vault_kube_provider() {
#     require vault

#     info "Seeding Kube terraform provider secrets"
#     _VAULT_KV_PATH=${VAULT_KV_PATH:-"controller/kv"}
#     _KUBE_OWNER=${KUBE_OWNER:-"caas"}
#     _KUBE_CLUSTER=${KUBE_CLUSTER:-"kind"}
#     _KUBE_TOKEN=${KUBE_TOKEN:-$(cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)}
#     _KUBE_CERT=${KUBE_CERT:-$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt 2>/dev/null)}
#     _VAULT_KV_SECRET=${VAULT_KV_SECRET:-"${KUBE_OWNER}/${KUBE_CLUSTER}/provider"}
#     info "VAULT_ADDR: ${VAULT_ADDR}"
#     info "VAULT_KV_PATH: ${_VAULT_KV_PATH}"
#     info "VAULT_KV_SECRET: ${_VAULT_KV_SECRET}"
#     info "KUBE_URL: ${KUBE_URL}"
#     info "KUBE_CERT: ${_KUBE_CERT}"
#     info "KUBE_CLUSTER: ${_KUBE_CLUSTER}"
#     info "KUBE_USERNAME: ${KUBE_USERNAME}"
#     info "KUBE_PASSWORD: ${KUBE_PASSWORD}"
#     info "KUBE_CLIENT_CERTIFICATE: ${KUBE_CLIENT_CERTIFICATE}"
#     info "KUBE_CLIENT_KEY: ${KUBE_CLIENT_KEY}"
#     if [[ -n "$VAULT_ADDR" && -n "$VAULT_TOKEN" && -n "$_KUBE_TOKEN" && -n "$KUBE_URL" && -n "$_KUBE_CERT" ]]; then
#         _vault_cmd_output=$( vault kv \
#             put "${_VAULT_KV_PATH}/${_VAULT_KV_SECRET}" \
#             url="${KUBE_URL}" \
#             username="${KUBE_CLIENT_USERNAME}" \
#             password="${KUBE_CLIENT_PASSWORD}" \
#             client_certificate="${KUBE_CLIENT_CERTIFICATE}" \
#             client_key="${KUBE_CLIENT_KEY}" \
#             certificate="${_KUBE_CERT}" 2>&1 ) && _exit_status=$? || _exit_status=$?
#         if [ "${_exit_status}" = 0 ]; then
#             info "Vault kube provider seeding succeeded!"
#         else
#             error "Unable to seed kube kv provider secrets - ${_vault_cmd_output}" "${_exit_status}"
#         fi
#     else
#         error "Vault kube provider secret seeding requires the following environment variables: VAULT_ADDR, KUBE_TOKEN, KUBE_CERT, and KUBE_URL"
#     fi
# }

# seed_vault_kube_authmount() {
#     require vault

#     info "Seeding a kube auth mount secret"
#     _VAULT_KV_PATH=${VAULT_KV_PATH:-"controller/kv"}
#     _KUBE_OWNER=${KUBE_OWNER:-"caas"}
#     _KUBE_CLUSTER=${KUBE_CLUSTER:-"kind"}
#     _KUBE_TOKEN=${KUBE_TOKEN:-$(cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)}
#     _KUBE_CERT=${KUBE_CERT:-$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt 2>/dev/null)}
#     _VAULT_KV_SECRET=${VAULT_KV_SECRET:-"${KUBE_OWNER}/${KUBE_CLUSTER}/vault_auth"}
#     info "VAULT_ADDR: ${VAULT_ADDR}"
#     info "VAULT_KV_PATH: ${VAULT_KV_PATH}"
#     info "VAULT_KV_SECRET: ${VAULT_KV_SECRET}"
#     info "KUBE_URL: ${KUBE_URL}"
#     info "KUBE_CERT: ${KUBE_CERT}"
#     info "KUBE_CLUSTER: ${KUBE_CLUSTER}"
#     info "KUBE_OWNER: ${KUBE_OWNER}"
#     if [[ -n "$VAULT_TOKEN" ]]; then
#         if [[ -n "$VAULT_ADDR" && -n "$KUBE_TOKEN" && -n "$KUBE_URL" && -n "$KUBE_CERT" ]]; then
#             _vault_cmd_output=$( vault kv \
#                 put "${VAULT_KV_PATH}/${VAULT_KV_SECRET}" \
#                 token="${KUBE_TOKEN}" \
#                 name="${KUBE_URL}" \
#                 certificate="${KUBE_CERT}" 2>&1 ) && _exit_status=$? || _exit_status=$?
#             if [ "${_exit_status}" = 0 ]; then
#                 info "Vault kube secret seeding succeeded!"
#             else
#                 error "Unable to seed kube kv secrets - ${_vault_cmd_output}" "${_exit_status}"
#             fi
#         else
#             error "Unable to seed kube kv secrets - ${_vault_cmd_output}" "${_exit_status}"
#         fi
#     else
#         error "Vault kube auth secret seeding requires the following environment variables: VAULT_ADDR, KUBE_TOKEN, KUBE_CERT, and KUBE_URL"
#     fi
# }

vault_assume_aws_sts() {
    ## Depreciated alias
    lease_aws_sts_account
}

## Leasing functions for vault secrets engines
lease_aws_sts_account() {
    # If our variables are in place then attempt to attain temporary AWS credentials via an AWS STS role defined in vault
    _vault_aws_sts_mount=${VAULT_AWS_STS_MOUNT:-"aws_sts"}
    VAULT_AWS_STS_ROLE=${VAULT_AWS_STS_ROLE:-${VAULT_STS_ROLE:-""}}
    if [ -n "$VAULT_ADDR" ] && [ -n "$VAULT_TOKEN" ]; then
        if [ -n "$VAULT_AWS_STS_ROLE" ] && [ -n "${_vault_aws_sts_mount}" ]; then
            info "VAULT_AWS_STS_ROLE: ${VAULT_AWS_STS_ROLE}"
            info "vault_aws_sts_mount: ${_vault_aws_sts_mount}"
            info "Attempting Vault AWS STS role token generation..."
            _vault_cmd_output=$( curl -s \
                -H "X-Vault-Token: ${VAULT_TOKEN}" \
                -H "Accept: application/json" \
                "${VAULT_ADDR}/v1/${_vault_aws_sts_mount}/creds/${VAULT_AWS_STS_ROLE}" 2>&1 ) && _exit_status=$? || _exit_status=$?
            # _vault_cmd_output=$( vault read \
            #     -format=json \
            #     ${_vault_aws_sts_mount}/creds/${VAULT_AWS_STS_ROLE} 2>&1 ) \
            #     && _exit_status=$? || _exit_status=$?
            if [ "${_exit_status}" = 0 ]; then
                export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
                export AWS_PAGER=${AWS_PAGER:-""}
                AWS_ACCESS_KEY_ID="$( echo ${_vault_cmd_output} | jq -r '.data.access_key' )"
                export AWS_ACCESS_KEY_ID
                AWS_SECRET_ACCESS_KEY="$( echo ${_vault_cmd_output} | jq -r '.data.secret_key' )"
                export AWS_SECRET_ACCESS_KEY
                AWS_SESSION_TOKEN="$( echo ${_vault_cmd_output} | jq -r '.data.security_token' )"
                export AWS_SESSION_TOKEN
                TOKEN_LEASE_ID="$( echo ${_vault_cmd_output} | jq -r '.lease_id' )"
                export TOKEN_LEASE_ID
                success "Vault AWS STS credentials exported!"
            else
                error "Vault AWS STS account generation failure - ${_vault_cmd_output}" "${_exit_status}"
            fi
        else
            error "AWS STS credential sourcing required variables missing: VAULT_AWS_STS_MOUNT, VAULT_AWS_STS_ROLE"
        fi
    else
        error "AWS STS credential sourcing required variables missing: VAULT_ADDR, VAULT_TOKEN"
    fi
}

lease_ad_svc_account() {
    require vault
    # svc account name as defined in your manifest
    _vault_ad_role=${VAULT_AD_ROLE:-""} 
    _vault_ad_domain=${VAULT_AD_DOMAIN:-"nmtest"}
    if [ -n "$VAULT_ADDR" ] && [ -n "$VAULT_TOKEN" ] && [ -n "${_vault_ad_role}" ] && [ -n "${_vault_ad_domain}" ]; then
        _vault_cmd_output=""
        _vault_cmd_output=$(vault read ad/${_vault_ad_domain}/creds/${_vault_ad_role} -format=json 2>&1 ) && _exit_status=$? || _exit_status=$?
        if [ "${_exit_status}" = 0 ]; then
            info "Vault ad svc account leased!"
            AD_USERNAME=$(echo ${_vault_cmd_output} | jq -r '.data.username')
            AD_PASSWORD=$(echo ${_vault_cmd_output} | jq -r '.data.current_password')
            AD_LAST_PASSWORD=$(echo ${_vault_cmd_output} | jq -r '.data.last_password')
            info "AD_USERNAME=${AD_USERNAME}"
            info "AD_LAST_PASSWORD=${AD_LAST_PASSWORD}"
            export AD_USERNAME
            export AD_PASSWORD
            export AD_LAST_PASSWORD
        else
            error "Unable to lease ad service account from vault - ${_vault_cmd_output}" "${_exit_status}"
        fi
    else
        error "Leasing a vault managed AD service account requires VAULT_ADDR, VAULT_TOKEN, VAULT_AD_ROLE, and VAULT_AD_DOMAIN"
    fi
}

checkout_ad_library_account() {
    # library name as defined in your manifest
    require vault

    _exit_status=""
    _vault_cmd_output=""
    _available_accounts=""
    _vault_ad_role=${VAULT_AD_ROLE:-""}
    _vault_ad_domain=${VAULT_AD_DOMAIN:-"nmtest"}
    _vault_ad_account_ttl=${VAULT_AD_ACCOUNT_TTL:-"300"}
    info "vault_ad_role: ${_vault_ad_role}"
    info "vault_ad_domain: ${_vault_ad_domain}"
    info "vault_ad_account_ttl: ${_vault_ad_account_ttl}"

    if [ -n "$VAULT_ADDR" ] && [ -n "$VAULT_TOKEN" ] && [ -n "${_vault_ad_role}" ] && [ -n "${_vault_ad_domain}" ]; then
        _vault_cmd_output=$(vault read "ad/${_vault_ad_domain}/library/${_vault_ad_role}/status" 2>&1) && _exit_status=$? || _exit_status=$?
        if [ "${_exit_status}" = 0 ]; then
            info "Vault ad library available accounts:"
            info "${_vault_cmd_output}"
            available_accounts=$(echo "${_vault_cmd_output}" | grep 'available:true')
            if [ -n "${available_accounts}" ]; then 
                _vault_cmd_output=""
                _vault_cmd_output=$(vault write "ad/${_vault_ad_domain}/library/${_vault_ad_role}/check-out" \
                    -format=json ttl="${_vault_ad_account_ttl}" 2>&1 ) && _exit_status=$? || _exit_status=$?
                if [ "${_exit_status}" = 0 ]; then
                    info "Vault ad svc account leased!"
                    AD_USERNAME=$(echo "$_vault_cmd_output" | jq -r '.data.service_account_name')
                    export AD_USERNAME
                    info "AD_USERNAME=${AD_USERNAME}"
                    AD_PASSWORD=$(echo "$_vault_cmd_output" | jq -r '.data.password')
                    export AD_PASSWORD
                    AD_LEASE_ID=$(echo "$_vault_cmd_output" | jq -r '.lease_id')
                    export AD_LEASE_ID
                else
                    error "Unable to lease ad library service account from vault - ${_vault_cmd_output}" "${_exit_status}"
                fi
            else
                error "Unable to lease ad service account from vault as none are available to lease!" 1
            fi
        else
            error "Unable to check ad library service account availability - ${_vault_cmd_output}" "${_exit_status}"
        fi
    else
        error "Leasing a vault managed AD service account requires VAULT_ADDR, VAULT_TOKEN, VAULT_AD_ROLE, and VAULT_AD_DOMAIN" 1
    fi
}

checkin_ad_library_account() {
    require vault

    _exit_status=""
    _vault_cmd_output=""
    _vault_ad_role=${VAULT_AD_ROLE:-""}
    _vault_ad_domain=${VAULT_AD_DOMAIN:-"nmtest"}
    _ad_username=${AD_USERNAME:-""}
    info "vault_ad_role: ${_vault_ad_role}"
    info "vault_ad_domain: ${_vault_ad_domain}"
    info "ad_username: ${_ad_username}"

    if [ -n "$VAULT_ADDR" ] && [ -n "$VAULT_TOKEN" ] && [ -n "$_vault_ad_role" ] && [ -n "$_vault_ad_domain" ] && [ -n "$_ad_username" ]; then
        _vault_cmd_output=$(vault write \
            "ad/${_vault_ad_domain}/library/${_vault_ad_role}/check-in" \
            --force \
            service_account_names="${_ad_username}" 2>&1) && _exit_status=$? || _exit_status=$?
        if [ "${_exit_status}" = 0 ]; then
            success "Vault ad library service account checked in!"
        else
            warn "Unable to checkin ad service account from vault - ${_vault_cmd_output}"
        fi
    else
        warn "Checking in a vault managed AD library service account requires VAULT_ADDR, VAULT_TOKEN, VAULT_AD_ROLE, AD_USERNAME, and VAULT_AD_DOMAIN" 1
    fi
}


require jq
require curl
