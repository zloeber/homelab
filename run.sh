#!/bin/sh

make .dep/taskfile

here=$(pwd)

export PATH="${PATH}:${HOME}/.local/bin:${here}/.local/bin"
task workstation:install:base
task asdf:bootstrap
#task install:chezmoi