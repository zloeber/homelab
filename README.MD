# KubeStrap

The original intent for this project was to use Kubernetes in docker via kind/k3d to bootstrap a secured internal IoT distributed Kuberntes cluster core vault pki and other local core services for a home automation solution. This has instead become a collection of [taskfiles](https://taskfile.dev), dotfiles, and scripts that simplify workspace management for multi-git devops projects in a declarative open source, reproducible, reusable way. 

I will use this to explore various tools and maintain several projects and explore various open source tools.

# Ethos

This project has so many disparate scripts and tasks that it may be hard to find the common elements among them. I'll state them here for clarity:

- Most tasks are rootless. As such, cli apps are usually installed to `./venv/bin` or `~/venv/bin`. Aqua will use `${HOME}/venv/share/aquaproj-aqua/bin` by default for its binaries. You are responsible for your own `PATH` var. So ensure your `.zshrc` or `.profile` or `.bashrc` files (look for the `export PATH="./venv/bin:${PATH}"` command).

- I lean towards readable declarative yaml configurations for most configurations where terraform is not sufficient. 
- Typically, I will search for and install applications via aqua-cli (`aqua g -i` then `aqua install`) and use asdf-vm to manage programming language installs. 

# Install

## Workstation (Ubuntu)

First setup the workstation with essential tools and a cli environment

```bash
./scripts/workstation-bootstrap.sh
./venv/bin/task workstation:install:base
```
Dependencies can be installed after cloning this repo.

```bash
./run.sh
```

# Usage

Most usage is via a set of Taskfile definitions in the `tasks/taskfiles` folder that can be used in your shell to do things like;

1. Manage a set of disparate git repos as single workspace
2. Install several devops tools to suit your need, keeps console snippets and tasks in an ever growing catalog of automation tasks for the future.
3. Install a new linux workstation with some things.
4. Other stuff

>**Hint** For other info on [taskfile](https://taskfile.dev) you should hit up its site.

The goal of this setup is largely to be able to pivot quickly between personal projects and be able to pick up where I left off. I also do quite a bit of cli tool testing and solution scaffolding. This means being able to quickly setup specific versions of go, python, or any other number of other exploratory or interesting tools. For this I lean on docker, aqua, and asdf-vm.

If these requirements are not met you can try to install them via 

```bash
./run.sh
```

Or to setup a new workstation mostly from scratch (to my own needs of course) on the latest linux mint ubuntu based deployment. Ensure that task is in your path and then install a bunch of things as needed:

```bash
task workstation:install:base
task workstation:install:joplin

```

## Workspaces

Workspaces logically divide work efforts into their own folders in `workspaces`. These are created by [Vendir]() spec files in the workspaces folder. So to when we use the default workspace any and all new folders for it's operational needs should be in `workspaces/default/<repo name>`. These currently get synced right in the folder itself but all subdirectories are ignored in `.gitignore` for safety sake.