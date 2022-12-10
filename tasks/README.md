# Tasks

Tasks are taskfile.dev driven tasks you may do at a cli once in a while or maybe multiple times a day. These get broken down by technology type and included in your project's root Taskfile.yaml file.

Taskfile uses golang templating and a particular env and vars resolution that can be confusing. The gist is:

- `vars` blocks within included task files are global in scope. If defined multiple times the last defined variable 'wins' and will be the value for all tasks unless manually overriden at the task level.

- `env` blocks within task files are a mystery to me. No, they don't get evaluated at include time the same way?