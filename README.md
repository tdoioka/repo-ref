# repo-ref

repo-ref - Manage git-repo referances

## USAGE

### SYNOPSIS

```shell
repo-ref [-h|--help] <command> [<args>]
```

### DESCRIPTION

repo-ref provides a way to organize git-repo references.
When you creat a tree with git-repo, by using repo-ref instead, repo-ref will
build a local reference in the specified directory (by default ~/repo-refs)
and run repo init specified the built local reference.

### OPTIONS

-h, --help
: Prints the synopsis and a list of commands.

### COMMANDS

init
: You can use `repo-ref init` instead of `repo init`.
`repo-ref init` adds the `--reference` option to `repo init` with the directory
created by `repo-ref mirror`. If the reference is not exists, create it as `repo mirror`.
See also `mirror`.

sync
: You can use `repo-ref sync` instead of `repo sync`.
`repo-ref sync` will `repo sync` the reference first before performing `repo sync`
on that tree.

mirror
: Create a reference on specified directory.
If the reference already exists, run `repo sync` on that reference.
The argumetns are the same as `repo init`,
but in addition `-j` and `--jobs*` options of `repo sync` are available.
These `-j` options are used when fetching the reference with`repo sync`.
Also, `-g`,`--group`,`-p`,`--platform`, and `--depth` are ignored as they seem
inappropriate in the case of creating a reference.

syncall
: Run `reop sync` on the managed all references in order.
A repo references can also be built by specifying other references in `--references`.
`repo-ref syncall` can interpret that dependency and `reop sync` them in order.

list
: Print the list of references managed by `repo-ref` to stdout.

dir
: Print directory path of references managed by `repo-ref`.
Only the following arguments are interpreted:
 `-u`, `--manifest-url`, `-b`, `--manifest-branch`, `-m`, `--manifest-name`.

help
: Prints the synopsis and a list of commands.

## SETUP

### INSTALLATION

```shell
mkdir -p ~/bin
wget https://raw.githubusercontent.com/tdoioka/repo-ref/main/repo-ref.sh -O ~/bin/repo-ref
chmod a+x ~/bin/repo-ref
```
### CONFIGURATION
#### GIT CONFIG

reporef.root
: specify directory which put references.
This configure is ignored if the `REPOREF_DIR` environment is set.

#### ENVIRONMENT VARIABLES

REPOREF_DIR
: specify directory which put references.

### DIRECTORY STRUCTURES

Reference are placed under `reporef.root` with named repository-url/branch-name/manifest-name.

```shell
~/repo-ref
|--- android.googlesource.com/platform/manifest/
|    `-- default/
|        `-- default/
`--- github.com/xxxx/yyy-manifest
     |-- branch-name-a/
     |   `-- manifest-name/
     `-- branch-name-b/
         |-- manifest-name-a/
         `-- manifest-name-b/
```
