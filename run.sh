#!/bin/sh

make .dep/taskfile

here=$(pwd)

export PATH="${here}/venv/bin:${HOME}/venv/bin:${here}/.local/bin:${HOME}/.local/share/aquaproj-aqua/bin:${PATH}"

task workstation:install:base
task asdf:bootstrap
task aqua:sync


#task install:chezmoi