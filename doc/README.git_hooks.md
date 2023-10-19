Commit Hooks
============

ntopng uses git hooks to perform certain operations upon commit.

Hooks are implemented in the sources directory, under `./hooks`. Currently, pre-commit hooks are implemented to carry out localization-related operations and also to create minified files.

Pre-commit hooks are implemented in file `hooks/pre-commit`. The file is an `sh` executable automatically run before every commit.

The file can be modified and extended to perform additional tasks. Among other tasks that can be performed, one can do automatic checks on indentation and also static code analyses to make sure the repo is always clean.

