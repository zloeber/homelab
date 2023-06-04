
# Umbrella repo for vault project work
SHELL:=/bin/bash
.DEFAULT_GOAL:=help

.POSIX:
.PHONY: *
.EXPORT_ALL_VARIABLES:

KUBECONFIG = $(shell pwd)/metal/kubeconfig.yaml
KUBE_CONFIG_PATH = $(KUBECONFIG)


ROOT_PATH := $(abspath $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST))))))
SSH_AUTHORIZED_KEY?=~/.ssh/id_rsa.pub
#SSH_HOST_KEY?=~/.ssh/$(shell hostname)-id_rsa.pub


PROFILE ?= default
CONFIG_FILE ?= $(ROOT_PATH)/$(PROFILE).yml
SKIP_ERRORS ?= 2>/dev/null || true
HOME_PATH := $(ROOT_PATH)/venv
TASKFILE_PATH?=$(HOME_PATH)/bin
PYTHON_VENV_PATH := $(ROOT_PATH)/venv
APP_PATH := $(HOME_PATH)/apps
PROJECT_BIN_PATH := $(HOME_PATH)/bin
SCRIPT_PATH ?= $(ROOT_PATH)/scripts
#GITLAB_CI_JSON := $(shell jq --raw-input --slurp < $(ROOT_PATH)/.gitlab-ci.yml || true)
TF_MODULE_FILTER := terraform-module-
AWS_PAGER=
# Generic shared variables
ifeq ($(shell uname -m),x86_64)
ARCH ?= amd64
endif
ifeq ($(shell uname -m),i686)
ARCH ?= 386
endif
ifeq ($(shell uname -m),aarch64)
ARCH ?= arm
endif
ifeq ($(shell uname -m),arm64)
ARCH ?= arm64
endif
ifeq ($(OS),Windows_NT)
OS := Windows
else
OS := $(shell sh -c 'uname -s 2>/dev/null || echo not' | tr '[:upper:]' '[:lower:]')
endif

ifdef CI
yq := $(shell which yq || echo $(PROJECT_BIN_PATH)/yq)
jq := $(shell which jq || echo $(PROJECT_BIN_PATH)/jq)
gomplate := $(shell which gomplate || echo $(PROJECT_BIN_PATH)/gomplate)
vault := $(shell which vault || echo $(PROJECT_BIN_PATH)/vault)
dive := $(shell which dive || echo $(PROJECT_BIN_PATH)/dive)
else
yq := $(PROJECT_BIN_PATH)/yq
jq := $(PROJECT_BIN_PATH)/jq
gomplate := $(PROJECT_BIN_PATH)/gomplate
vault := $(PROJECT_BIN_PATH)/vault
dive := $(PROJECT_BIN_PATH)/dive
endif

ENVIRONMENT ?= poc
INSTANCE_IP ?= <instance_ip>
AWS_CONFIG ?= ${HOME}/.aws/config

# Import default env vars
DEFAULT_ENVIRONMENT_VARS ?= config/environments/defaults.env
ifneq (,$(wildcard $(DEFAULT_ENVIRONMENT_VARS)))
include ${DEFAULT_ENVIRONMENT_VARS}
export $(shell sed 's/=.*//' ${DEFAULT_ENVIRONMENT_VARS})
endif

# Import target env vars
ENVIRONMENT_VARS ?= config/environments/$(ENVIRONMENT).env
ifneq (,$(wildcard $(ENVIRONMENT_VARS)))
include ${ENVIRONMENT_VARS}
export $(shell sed 's/=.*//' ${ENVIRONMENT_VARS})
endif

# Import env locally defined env vars
OVERRIDE_VARS ?= config/environments/$(ENVIRONMENT).override.env
ifneq (,$(wildcard $(OVERRIDE_VARS)))
include ${OVERRIDE_VARS}
export $(shell sed 's/=.*//' ${OVERRIDE_VARS})
endif

ifneq (,$(wildcard $(yq)))
WORKSPACE ?= $(shell $(yq) r $(CONFIG_FILE) workspace)
PROJECT ?= $(shell $(yq) r $(CONFIG_FILE) project)
REPO_LIST ?= $(shell $(yq) r $(CONFIG_FILE) 'repos.*.url')
MODULE_LIST ?= $(shell $(yq) r $(CONFIG_FILE) 'repos.*.name' | grep '$(TF_MODULE_FILTER)' )
REPO_COUNT ?= $(shell $(yq) r $(CONFIG_FILE) 'repos.*.url' --collect --length)
REPO_PATHS ?= $(shell $(yq) r $(CONFIG_FILE) 'repos.*.name')
else
WORKSPACE ?= workspace
PROJECT ?= project
REPO_LIST ?=
MODULE_LIST ?= 
REPO_COUNT ?= 0
endif

WORKSPACE_PATH ?= $(WORKSPACE)/$(PROJECT)

GIT_COMMIT:=$(shell git rev-parse --short=8 HEAD 2>/dev/null || echo local)
GIT_BRANCH:=$(shell git branch --show-current 2>/dev/null || echo unknown)

SEDOPTION=
ifeq ($(OS),darwin)
SEDOPTION=-i ''
endif

.PHONY: help
help: ## Help
	@grep --no-filename -E '^[a-zA-Z_/-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: .update/self
.update/self: ## Update local repo
	@git pull --all --tags || true

.PHONY: update
update: .update/self workspace/update ## Shortcut for workspace/update


.PHONY: deps
deps: .dep/apt .dep/ssh .dep/taskfile .dep/jq .dep/yq ## Install dependant apps

.PHONY: venv
venv: ## Start virtual environment
	@python3 -m venv $(PYTHON_VENV_PATH)
	@export PATH="$(PYTHON_VENV_PATH)/bin:$$PATH" && \
		pip3 install pip --upgrade --index-url=https://pypi.org/simple/
	@source $(PYTHON_VENV_PATH)/bin/activate || true
	@$(PYTHON_VENV_PATH)/bin/pip3 install -r requirements.txt


YQ_VERSION ?= 3.4.1
$(yq): ## Install yq
	@echo "Attempting to install yq - $(YQ_VERSION)"
	@mkdir -p $(PROJECT_BIN_PATH)
	@curl --retry 3 --retry-delay 5 --fail -sSL \
		-o $(yq) https://github.com/mikefarah/yq/releases/download/$(YQ_VERSION)/yq_$(OS)_$(ARCH)
	@chmod +x $(yq)
	@echo "Binary requirement: $(yq)"

JQ_VERSION ?= 1.6
#.PHONY: .dep/jq
$(jq): ## Install jq
	@echo "Attempting to install jq - $(JQ_VERSION)"
	@mkdir -p $(PROJECT_BIN_PATH)
ifeq ($(OS),darwin)
	@curl --retry 3 --retry-delay 5 --fail -sSL \
		-o $(jq) https://github.com/stedolan/jq/releases/download/jq-$(JQ_VERSION)/jq-osx-$(ARCH)
else
	@curl --retry 3 --retry-delay 5 --fail -sSL \
		-o $(jq) https://github.com/stedolan/jq/releases/download/jq-$(JQ_VERSION)/jq-$(OS)-$(ARCH)
endif
	@chmod +x $(jq)
	@echo "Binary requirement: $(jq)"

TASK_VERSION ?= 3.9.0
task := $(PROJECT_BIN_PATH)/task

.PHONY: task
task: ## Install/Run task
ifeq (,$(wildcard $(task)))
	@echo "Attempting to install task - $(TASK_VERSION)"
	@mkdir -p $(PROJECT_BIN_PATH)
	@mkdir -p /tmp/task
	@curl --retry 3 --retry-delay 5 --fail -sSL -o - \
		https://github.com/go-task/task/releases/download/v$(TASK_VERSION)/task_$(OS)_$(ARCH).tar.gz \
		| tar -C /tmp/task -zx task
	@mv /tmp/task/task $(task)
	@chmod +x $(task)
endif
	@$(task)

.PHONY: .dep/apt
.dep/apt:
	sudo apt -y install openssh-server ntp ansible && sudo systemctl enable ssh && sudo systemctl start ssh

.PHONY: .dep/ssh
.dep/ssh:
ifeq (,$(wildcard $(SSH_AUTHORIZED_KEY)))
	ssh-keygen -t rsa -C "$(shell whoami)@localhost"
	cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
endif
	@true

.PHONY: .dep/taskfile
.dep/taskfile:
ifeq (,$(wildcard $(TASKFILE_PATH)/task))
	@mkdir -p $(TASKFILE_PATH)
	@sh -c "$$(curl --location https://taskfile.dev/install.sh)" -- -d -b $(TASKFILE_PATH)
endif
	@true

# search/workspace/%: ## Search workspace for references to %
# 	find $(WORKSPACE_PATH) -name "*.tf" -print0 -type f -not -path "**/.local/*" | xargs -I {}  -0 grep -H --color -e "$(subst search/workspace/,,$@)" "{}"

# .PHONY: show/vaultmodules
# show/vaultmodules: ## Show hvault tagged modules
# 	@$(MAKE) -S -C $(WORKSPACE_PATH)/vault_modules show/module/releases

# .PHONY: .dep/dive
# .dep/dive: ## Install docker image exploration tool, dive
# ifeq (,$(wildcard $(dive)))
# 	@$(MAKE) --no-print-directory -C $(APP_PATH)/githubapp auto wagoodman/dive INSTALL_PATH=$(PROJECT_BIN_PATH)
# endif

# .PHONY: docker/dive
# docker/dive: .dep/dive ## Examine the image with the dive
# 	$(dive) $(DOCKER_IMAGE):local

# .PHONY: backup/state
# backup/state: ## Backup the state for an environment
# 	@mkdir -p $(HOME_PATH)/$(ENVIRONMENT)/state
# 	@aws --profile $(AWS_PROFILE) s3 sync s3://${ENV}-tf-state $(HOME_PATH)/$(ENVIRONMENT)/state
# 	@echo synced reports to :$(HOME_PATH)/$(ENVIRONMENT)/state


.PHONY: git/lint
git/lint: ## Find merge request conflict detrius
	@echo "Looking for merge request conflict detrius"
	@failedfiles=$$(find . -type f \( -iname "*.tf" -o -iname "*.yml" -o ! -iname "workspace" ! -iname ".local" ! -iname "venv*" ! -iname ".git" ! -iname "Makefile" \) -exec grep -l "<<<<<<< HEAD" {} \;); \
	if [ "$$failedfiles" ]; then echo "Failed git/lint files: $${failedfiles} "; exit 1; fi

.PHONY: find/ref
find/ref: ## Find ref statements
	@find $(WORKSPACE_PATH) -type f \( -iname ".gitlab-ci.yml" \) -exec grep "ref:" {} \;

.PHONY: update/ref
update/ref: ## Update ref statements
	find $(WORKSPACE_PATH) -type f  \( -iname ".gitlab-ci.yml" \) -exec sed -i 's/ref:.+/ref: $(CICD_VERSION)/g' {} \;


.PHONY: git/setupstream
git/setupstream: ## Set the current git branch upstream to a branch by the same name on the origin
	@git branch --set-upstream-to=origin/$(GIT_BRANCH) $(GIT_BRANCH)

%: ## A parameter
	@true

deploy: metal bootstrap smoke-test ## Default kube deployment

configure: ## Configure the current repo
	./scripts/configure
	git status

metal: ## Deploy metal (Stage 1)
	make -C metal

bootstrap: ## Deploy bootstrap (Stage 2)
	make -C bootstrap

external: ## Deploy external (Stage 3)
	make -C external

smoke-test: ## Run smoke tests
	make -C test filter=Smoke

post-install: ## Run post-install hacks
	@./scripts/hacks

tools: ## Create and run a tools container environment
	@docker run \
		--rm \
		--interactive \
		--tty \
		--network host \
		--env "KUBECONFIG=${KUBECONFIG}" \
		--volume "/var/run/docker.sock:/var/run/docker.sock" \
		--volume $(shell pwd):$(shell pwd) \
		--volume ${HOME}/.ssh:/root/.ssh \
		--volume ${HOME}/.terraform.d:/root/.terraform.d \
		--volume homelab-tools-cache:/root/.cache \
		--volume homelab-tools-nix:/nix \
		--workdir $(shell pwd) \
		nixos/nix nix-shell

test: ## Run all tests
	make -C test

clean: ## Clean up
	docker compose --project-directory ./metal/roles/pxe_server/files down
	k3d cluster delete homelab-dev

dev: ## Deploy dev environment
	make -C metal cluster env=dev
	make -C bootstrap

docs: ## Serve docs
	mkdocs serve

git-hooks: ## Install git hooks
	pre-commit install
