#!/bin/bash

here=$(pwd)

first_run=${FORCE:-false}
if [ ! -f ./venv/bin/task ] || [ "$first_run" = "true" ]; then
    mkdir -p ./venv/bin
    sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ./venv/bin
fi

export PATH="${here}/venv/bin:${HOME}/.local/share/aquaproj-aqua/bin:${PATH}"

if [ "$first_run" = "true" ]; then
    task workstation:install:base
fi

task python:venv python:install --force
source ./venv/bin/activate
task teller:install --force
task asdf:bootstrap
#task aqua:sync

#task install:chezmoi