#!/bin/bash
# Creates a bootstrap package for the current user account

#staging_path=$(mktemp -d)
target_path=${1:-"./bootstrap"}
private_files=(
    "${HOME}/.ssh"
    "${HOME}/.docker"
)
DIR="${BASH_SOURCE%/*}"

if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

. "$DIR/vault-shared.sh"

function show() {
    info "DIR: ${DIR}"
    info "Target Path: ${target_path}"
    read -p "Press enter to continue"
}

if [[ -d "${target_path}" ]]; then
    warning "Target path already exists: ${target_path}"
    read -p "Press enter to exit"
    exit 0
fi

show
mkdir -p "${target_path}"

success "Created bootstrap package at: ${target_path}"

for file in "${private_files[@]}"; do
    if [[ -d "${file}" ]]; then
        cp -r "${file}" "${target_path}"
    elif [[ -f "${file}" ]]; then
        cp "${file}" "${target_path}"
    else
        error "File not found: ${file}"
    fi
    success "Copied private files to bootstrap package: ${file}"
done
