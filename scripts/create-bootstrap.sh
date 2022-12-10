#!/bin/bash
# Creates a bootstrap package for the current user account

#staging_path=$(mktemp -d)
target_path=${1:-"./bootstrap"}
private_files=(
    .ssh

)
DIR="${BASH_SOURCE%/*}"

if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

. "$DIR/vault-shared.sh"

function show() {
    info "DIR: ${DIR}"
    info "Target Path: ${target_path}"
}

show

mkdir -p "${target_path}"

success "Created bootstrap package at: ${target_path}"