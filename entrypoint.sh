#!/bin/bash

#
# Bashy stuff for catching errors
#
SCRIPT=$(basename "$0")
# SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# ERRCOUNT=0
onerror() {
    echo "$(tput setaf 1)$SCRIPT: Error on line ${BASH_LINENO[0]}, exiting.$(tput sgr0)"
    exit 1
}
trap onerror ERR

#
# Command line args
#
VERSION_FILE=$1
tag_version=$2
DO_FILE_BUMP=$3

#
# Environment variables
#
: "${PREFIX=v}"
: "${DEFAULT_BUMP=patch}"
: "${BUMP_FILES=}"
: "${DRYRUN=false}"

#
# Status
#
echo
echo "Input file name: $VERSION_FILE"
echo "Tag version? ${tag_version}"
echo "Bump files: ${BUMP_FILES}"
echo "PREFIX: '${PREFIX}'"
echo
echo "Git Head Ref: ${GITHUB_HEAD_REF}"
echo "Git Base Ref: ${GITHUB_BASE_REF}"
echo "Git Event Name: ${GITHUB_EVENT_NAME}"
echo
echo "Starting Git Operations"
echo

# who this commit will be done as
git config --global user.email "UtilimarcBot@utilimarc.com"
git config --global user.name "Utilimarc GitActionBot"

# https://help.github.com/en/actions/configuring-and-managing-workflows/using-environment-variables

if test "${GITHUB_EVENT_NAME}" = "push"
then
    github_ref=${GITHUB_REF}
else
    github_ref=${GITHUB_HEAD_REF}
    git checkout "$github_ref"
fi

echo "Git Checkout"

if test -f "$VERSION_FILE" ; then
    content=$(cat "$VERSION_FILE")
else
    content=$(echo "-- File '$VERSION_FILE' doesn't exist --")
fi

echo "File Content: $content"
extract_string=$(echo "$content" | awk '/^([[:space:]])*(v|ver|version|V|VER|VERSION)?([[:blank:]])*([0-9]{1,2})\.([0-9]{1,3})\.([0-9]{1,4})[[:space:]]*$/{print $0}')
echo "Extracted string: $extract_string"

if [[ "$extract_string" == "" ]]; then
    #
    # look for the first string like "1.2.3"
    #
    extract_string=$(echo "$content" | awk 'match($0,/"(([0-9]{1,2})\.([0-9]{1,3})\.([0-9]{1,4}))"/){print substr($0,RSTART+1,RLENGTH-2); exit}')
    echo "Extracted string: $extract_string"
fi

if [[ "$extract_string" == "" ]]; then 
    echo "Invalid version string"
    extract_string=0.1.0
    exit 0
else
    echo "Valid version string found"
fi

# fetch tags
git fetch --tags

# get latest tag that looks like a semver (with PREFIX)
tag=$(git for-each-ref --sort=-v:refname --count=1 --format '%(refname)' "refs/tags/${PREFIX}[0-9]*.[0-9]*.[0-9]*" | cut -d / -f 3-)
tag_commit=$(git rev-list -n 1 "$tag")

# get current commit hash for tag
commit=$(git rev-parse HEAD)

if [ "$tag_commit" == "$commit" ]; then
    echo "No new commits since previous tag. Skipping..."
    echo ::set-output "name=tag::$tag"
    exit 0
fi

if [ -z "$tag" ]; then
    # the entire log!
    log=$(git log --pretty='%B')
else
    # log since last version tag
    log=$(git log "$tag..HEAD" --pretty='%B')
fi

#
# determine home to bump the version supports #major, #minor, #patch
# (anything else will be 'minor')
#
case "$log" in
    *#major*) DEFAULT_BUMP="major" ;;
    *#minor*) DEFAULT_BUMP="minor" ;;
    *#patch*) DEFAULT_BUMP="patch" ;;
esac

major=$(semver get major "$extract_string")
minor=$(semver get minor "$extract_string")
patch=$(semver get patch "$extract_string")

oldver="$major.$minor.$patch"
if "${DO_FILE_BUMP}" ; then
    newver=$(semver bump "${DEFAULT_BUMP}" "$extract_string")
else
    newver=$oldver
fi

echo "Old Ver: $oldver"
echo "Updated version: $newver" 

if [ "$BUMP_FILES" = "**" ]; then
    #
    # replace version patterns in all text files following a line containing [bump if $PREFIX]
    #
    git ls-files | while IFS= read -r f ; do
        LC_CTYPE=C LANG=C sed -i \
                -e "/\[bump if $PREFIX\]/{n;s/[0-9]\{1,2\}\.[0-9]\{1,3\}\.[0-9]\{1,4\}/${newver}/g;}" "$f"
    done
    BUMP_FILES=
fi

#
# replace the exact version in a fixed list of files
#
if "${DO_FILE_BUMP}" ; then
    for file in "$VERSION_FILE" $BUMP_FILES ; do
        sed -i -e s/"$oldver"/"$newver"/g "$file"
    done
fi

#
# make a tag and commit to git and push to github
#
if "${DRYRUN}"; then
    echo "[DRYRUN] not committing: ${PREFIX}${newver}"
    ([ -n "$tag_version" ] && [ "$tag_version" = "true" ]) && (true) || echo "[DRYRUN] No tag would be created."
else
    if "${DO_FILE_BUMP}" ; then
        git add -A
        git commit -m "Incremented to ${newver}"  -m "[skip ci]"
    fi
    ([ -n "$tag_version" ] && [ "$tag_version" = "true" ]) && (git tag -a "${PREFIX}${newver}" -m "[skip ci]") || echo "No tag created"

    git show-ref
    echo "Git Push"

    git push --follow-tags "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" HEAD:"$github_ref"
fi

echo
echo "End of Action"
echo

exit 0
