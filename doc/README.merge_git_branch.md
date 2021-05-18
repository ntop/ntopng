When developing new features or doing big changes, it is recommended to branch `dev`, commit new files and changes into the new branch, and eventually merge into `dev` all the changes.

This README demonstrates how to perform this procedure. It assumes a branch `bootstrap5` is branched and eventually merged into `dev` after a rebase.

To branch `dev` into a new branch `bootstrap5`

```
git branch -b bootstrap5
Switched to a new branch 'boostrap5'
```

From this point on, all the commits and changes can be commited regularly in `bootstrap5`. To push the local branch remotely do

```
git push -u origin boostrap5
```

Once all the changes are done it is recommended to rebase `boostrap5` into `dev`. This is to keep the commits history clean, and only add a single commit into `dev`.

The first thing to do is to `squash` all the commits done into `bootstrap5` into a single commit. To know how many commits need to be `squash` ed, the least common commit between `dev` and `bootstrap5` must be found. This is also called the _merge base_ and can be found as follows

```
git merge-base bootstrap5 dev
1e52154ef6b07be763679e308bf23c919e1d0d93
```

Now that the SHA1 of the _merge base_ commit is known, an interactive rebase `git rebase -i` can be performed to squash all the commits in `bootstrap5`


```
git rebase -i 1e52154ef6b07be763679e308bf23c919e1d0d93
```

This will open up an editor.

```
pick 049daed Adds bootstrap-5.0.0-beta3-dist
pick 04150aa Adds bootstrap-5.0.0
pick 009244f Updates bootstrap-5.0.0-beta3-dist to bootstrap-5.0.0-dist
pick 59e52e5 initial migration to bs v5
pick 0ba8590 porting to bs5
[...]
```

Replace the work `pick` with the word `squash` for all the commits that need to be `squash` ed. Ideally, only the first commit (`d8080ef`) will be `pick` ed and all the other commits will be `squash` ed.

```
pick 049daed Adds bootstrap-5.0.0-beta3-dist
squash 04150aa Adds bootstrap-5.0.0
squash 009244f Updates bootstrap-5.0.0-beta3-dist to bootstrap-5.0.0-dist
squash 59e52e5 initial migration to bs v5
squash 0ba8590 porting to bs5
[...]
```

Save and close the editor to let git begin the `squash`. Once the `squash` is done, the editor will be open one more time to edit the comments of the resulting `squash` ed commit.

```
# This is a combination of 13 commits.
# The first commit's message is:
Adds bootstrap-5.0.0-beta3-dist

# This is the 2nd commit message:

Adds bootstrap-5.0.0

# This is the 3rd commit message:

Updates bootstrap-5.0.0-beta3-dist to bootstrap-5.0.0-dist

# This is the 4th commit message:

initial migration to bs v5

[...]
```

Edit as desired and save. Now, update the datetime of the commit that can be old.

```
git commit --amend --reset-author
```

Now the commit is ready to be `merge`d into dev. Ideally, before `merging` into dev, a `rebase` should be performed. However, depending on how the two branches have diverged, this can result in many conflicts. To rebase into dev:

```
git rebase dev
```

If git complains that there are conflics and solving them would result to be too difficult, abort the rebase

```
 git rebase --abort
```

Now the last step, the actual `merge`. Switch back to `dev` and update it.

```
git checkout dev
```

Do the merge with 

```
git merge boostrap5
```

Now `dev` has all the commits of `boostrap5` squashed into a single commit. 

Merge Conflicts
---------------

Merging can result into conflicts, e.g., 

```
git merge bootstrap5
Auto-merging scripts/plugins/alerts/security/unexpected_new_device/locales/en.lua
CONFLICT (content): Merge conflict in scripts/plugins/alerts/security/unexpected_new_device/locales/en.lua
[...]
Auto-merging scripts/lua/modules/format_utils.lua
CONFLICT (content): Merge conflict in scripts/lua/modules/format_utils.lua
Auto-merging scripts/lua/modules/discover_utils.lua
Auto-merging scripts/lua/modules/alert_utils.lua
[...]
```

To resolve conflicts, edit conflicting files (they can be located with `git status` under `Unmerged paths`). Conflicts are reported between `<<<<<<<` and `>>>>>>>`. Change the code opportunely and remove those symbols. Once the conficts are resolved, mark the resolution with `git add <path to the conflicting file>`. After all the conflicts are resolved, a final `git commit` can be run.
