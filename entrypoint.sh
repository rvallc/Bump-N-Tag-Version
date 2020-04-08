#!/bin/bash
set -e

VERSION_FILE=$1
tag_version=$2

: "${PREFIX=v}"
: "${DEFAULT_BUMP=patch}"
: "${BUMP_FILES=}"
: "${DRYRUN=false}"

echo
echo "Input file name: $VERSION_FILE"
echo "Tag version? ${tag_version}"
echo "Bump files: ${BUMP_FILES}"
echo "PREFIX: '${PREFIX}'"

echo "Git Head Ref: ${GITHUB_HEAD_REF}"
echo "Git Base Ref: ${GITHUB_BASE_REF}"
echo "Git Event Name: ${GITHUB_EVENT_NAME}"
echo
echo "Starting Git Operations"
git config --global user.email "UtilimarcBot@utilimarc.com"
git config --global user.name "Utilimarc GitActionBot"

github_ref=""

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
extract_string=$(echo "$content" | awk '/^([[:space:]])*(v|ver|version|V|VER|VERSION)?([[:blank:]])*([0-9]{1,2})\.([0-9]{1,3})\.([0-9]{1,4})(\.([0-9]{1,5}))?[[:space:]]*$/{print $0}')
echo "Extracted string: $extract_string"

if [[ "$extract_string" == "" ]]; then
    #
    # look for the first string like "1.2.3"
    #
    extract_string=$(echo "$content" | awk 'match($0,/"(([0-9]{1,2})\.([0-9]{1,3})\.([0-9]{1,4})(\.([0-9]{1,5}))?)"/){print substr($0,RSTART+1,RLENGTH-2); exit}')
    echo "Extracted string: $extract_string"
fi

if [[ "$extract_string" == "" ]]; then 
    echo "Invalid version string"
    extract_string=0.1.0
    exit 0
else
    echo "Valid version string found"
fi

#
# TODO: check if commit message in `git log -n 1` contains any of
# #major #minor #patch, if so, use it for DEFAULT_BUMP
#
# get commit logs and determine home to bump the version
# supports #major, #minor, #patch (anything else will be 'minor')
case "$(git log -n 1)" in
    *#major*) DEFAULT_BUMP="major" ;;
    *#minor*) DEFAULT_BUMP="minor" ;;
    *#patch*) DEFAULT_BUMP="patch" ;;
esac

major=$(semver get major "$extract_string")
minor=$(semver get minor "$extract_string")
patch=$(semver get patch "$extract_string")

oldver="$major.$minor.$patch"
newver=$(semver bump "${DEFAULT_BUMP}" "$extract_string")

echo "Old Ver: $oldver"
echo "Updated version: $newver" 

if [ "$BUMP_FILES" = "**" ] ; then
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
for file in "$VERSION_FILE" $BUMP_FILES ; do
    sed -i -e s/"$oldver"/"$newver"/g "$file"
done

#
# make a tag and commit to git and push to github
#
if "${DRYRUN}"; then
    echo "[DRYRUN] not committing"
    ([ -n "$tag_version" ] && [ "$tag_version" = "true" ]) && (true) || echo "[DRYRUN] No tag would be created."
else
    git add -A 
    git commit -m "Incremented to ${newver}"  -m "[skip ci]"
    ([ -n "$tag_version" ] && [ "$tag_version" = "true" ]) && (git tag -a "${PREFIX}${newver}" -m "[skip ci]") || echo "No tag created"

    git show-ref
    echo "Git Push"

    git push --follow-tags "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" HEAD:$github_ref
fi

echo
echo "End of Action"
echo

exit 0
