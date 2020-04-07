# Bump-N-Tag Version

GitHub Action program to handle application version file like
auto-increment of version number based on GitHub events. This action
program supports "push" and "pull-request" events.

This is based on `vinodhraj/Bump-N-Tag-Version` and `anothrNick/github-tag-action`.

## Inputs

### `file_name`

**Required** - The name of file contains version information.  It
could be a `./VERSION` file, or the `setup.py`, for example.

### `tag_version`

**Optional** - Value can be 'true' or 'false'. If 'true' will create a
tag for this version and push the tag to the repository. By default it
is 'false'

## Environment Variables

### PREFIX

**Optional** the prefix to add to the version on the tag.  Default is `v`
so that version `1.2.3` would be tagged as `v1.2.3`.

### DEFAULT_BUMP

**Optional** the part of the version to bump, `major`, `minor`, or
`patch`. Default is `patch`.

### BUMP_FILES

**Optional** This can be one of two things:

- space-separated list of files to bump the version from *oldver* to
  *newver* in.  Only the exact *oldver* will be replace.
  
- `**` if this globby pattern is used, then all of the files in the repo
  will be searched for the pattern `[bump if $PREFIX]` and the *following* line
  will be updated with the *newver*.  For example, if `__version__.py` can have:
  
```
...
__url__ = 'https://github.com/rvallc'
# [bump if v]
__version__ = '0.3.4'
__build__ = 0x000000
...
```
    and the `0.3.4` will be updated from the `file_name` file's version, regardless
    of whether it matches the *oldver*.

### DRYRUN

Set this to `true` to prevent the tag and commit from executing.

### `Sample **VERSION** file content`

File may contain any of the below listed version formats. Prefix
character or word can be in any of 'V' or 'VER' or 'VERSION' and
supports both lower and upper case. Number of segments of version
string can be either three or four where fourth segment represents
build number. This program by default will always increment last
segment part of version string.

```
1.2.3
v1.2.3
v 1.2.3
ver 1.2.3
version 1.2.3
VER 2.3.6.4
VERSION 1.2.4.55
"1.2.3"
```


## Example usage

Only bump when `master` is pushed to.

```
name: Bump version
on:
  push:
    branches:
      - master
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Increment version
      id: version
      uses: rvallc/Bump-N-Tag-Version@master
      with:
        file_name: './VERSION'
        tag_version: "true"
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        BUMP_FILES: '**'
        PREFIX: v
```

