#!/bin/bash -l
set -e

file_name=$1
tag_version=$2
bump_files=$3

: "${PREFIX=v}"

echo
echo "Input file name: $file_name : $tag_version"
echo "Bump files: $bump_files"
echo "PREFIX: '${PREFIX}'"

echo "Git Head Ref: ${GITHUB_HEAD_REF}"
echo "Git Base Ref: ${GITHUB_BASE_REF}"
echo "Git Event Name: ${GITHUB_EVENT_NAME}"
echo
echo "Starting Git Operations"
git config --global user.email "Bump-N-Tag@github-action.com"
git config --global user.name "Bump-N-Tag App"

github_ref=""

if test "${GITHUB_EVENT_NAME}" = "push"
then
    github_ref=${GITHUB_REF}
else
    github_ref=${GITHUB_HEAD_REF}
    git checkout "$github_ref"
fi


echo "Git Checkout"

if test -f "$file_name" ; then
    content=$(cat "$file_name")
else
    content=$(echo "-- File doesn't exist --")
fi

echo "File Content: $content"
extract_string=$(echo "$content" | awk '/^([[:space:]])*(v|ver|version|V|VER|VERSION)?([[:blank:]])*([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{1,3})(\.([0-9]{1,5}))?[[:space:]]*$/{print $0}')
echo "Extracted string: $extract_string"

if [[ "$extract_string" == "" ]]; then 
    echo "Invalid version string"
    extract_string=0.1.0
    exit 0
else
    echo "Valid version string found"
fi

major=$(semver get major "$extract_string")
minor=$(semver get minor "$extract_string")
patch=$(semver get patch "$extract_string")
build=$(semver get build "$extract_string")

if [[ $build = "" ]]; then
    oldver="${PREFIX}$major.$minor.$patch"
    newver="${PREFIX}$(semver bump patch "$major.$minor.$patch")"
else
    oldver="${PREFIX}$major.$minor.$patch.$build"
    newver="${PREFIX}$(semver bump build "$major.$minor.$patch.$build")"
fi

echo "Old Ver: $oldver"
echo "Updated version: $newver" 

echo -n "${content/$oldver/$newver}" > "$file_name"

for file in $bump_files ; do
    sed -i -e s/"$oldver"/"$newver"/g "$file"
    echo "Updated '$file'"
    cat "$file"
    echo "--"
done

git add -A 
git commit -m "Incremented to ${newver}"  -m "[skip ci]"
([ -n "$tag_version" ] && [ "$tag_version" = "true" ]) && (git tag -a "${newver}" -m "[skip ci]") || echo "No tag created"

git show-ref
echo "Git Push"

git push --follow-tags "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" HEAD:$github_ref

echo
echo "End of Action"
echo

exit 0
