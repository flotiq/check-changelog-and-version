#!/bin/bash

RED='\033[31;1m'
GREEN='\033[32;1m'
NC='\033[0m' # No Color
function echo_red () {
  echo -e "${RED}\xE2\x9C\x98 ${@}${NC}"
}
function echo_green () {
  echo -e "${GREEN}\xE2\x9C\x94${NC}" ${@}
}
function read_version() {
  jq .version -r
}
# Install dependencies
npx -q semver-compare-cli --help > /dev/null || echo ""
npx -q changelog-parser --help > /dev/null || echo ""

# Make sure CHANGELOG has Unix line endings
[ -f $CHANGELOG_FILE ] && sed -i.bak 's/\r$//' $CHANGELOG_FILE || echo "No changelog file detected"
# Gather version info
git fetch origin $CI_MERGE_REQUEST_TARGET_BRANCH_NAME
TARGET_REF="origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME"
echo target ref $TARGET_REF
COMMON_ANCESTOR=$(git merge-base HEAD $TARGET_REF)
CHANGED_FILES=$(git diff -w --name-only HEAD $COMMON_ANCESTOR)
CHANGED_FILES_TO_CURRENT_TARGET=$(git diff -w --name-only HEAD "${TARGET_REF}")

if [ ! "$(type -t read_version)" = 'function' ]; then
  function read_version() { cat; };
fi

if [ -f ./${VERSION_FILE} ]; then
  CURRENT_VERSION=$(cat ./${VERSION_FILE} | read_version)
else
  echo "No package json exists, assuming v0.0.0"
  CURRENT_VERSION="0.0.0"
fi

if ! REMOTE_VERSION=$(git show ${TARGET_REF}:${VERSION_FILE} | read_version); then
  echo "No remote VERSION exists, assuming v0.0.0"
  REMOTE_VERSION="0.0.0"
fi

if ! OLD_VERSION=$(git show $COMMON_ANCESTOR:${VERSION_FILE} | read_version); then
  echo "No old VERSION exists, assuming v0.0.0"
  OLD_VERSION="0.0.0"
fi

echo "REMOTE_VERSION=$REMOTE_VERSION"
echo "OLD_VERSION=$OLD_VERSION"
echo "CURRENT_VERSION=$CURRENT_VERSION"
# Run all checks
if echo $CHANGED_FILES | grep -q ${VERSION_FILE};
then echo_green ${VERSION_FILE} file changed on $CI_MERGE_REQUEST_SOURCE_BRANCH_NAME
else echo_red ${VERSION_FILE} file did not change on $CI_MERGE_REQUEST_SOURCE_BRANCH_NAME; FAILED=true
fi

if echo $CHANGED_FILES_TO_CURRENT_TARGET | grep -q ${VERSION_FILE};
then echo_green ${VERSION_FILE} file changed compared to current $CI_MERGE_REQUEST_TARGET_BRANCH_NAME
else echo_red ${VERSION_FILE} file did not change compared to current $CI_MERGE_REQUEST_TARGET_BRANCH_NAME; FAILED=true
fi

if npx semver-compare-cli $CURRENT_VERSION gt $OLD_VERSION;
then echo_green version in ${VERSION_FILE} increased on $CI_MERGE_REQUEST_SOURCE_BRANCH_NAME
else echo_red version in ${VERSION_FILE} needs to increase on $CI_MERGE_REQUEST_SOURCE_BRANCH_NAME; FAILED=true
fi

if npx semver-compare-cli $CURRENT_VERSION gt $REMOTE_VERSION;
then echo_green version in ${VERSION_FILE} increased compared to current ${TARGET_REF}
else echo_red version in ${VERSION_FILE} needs to be higher than on ${TARGET_REF}; FAILED=true
fi

if [ -f $CHANGELOG_FILE ];
then CHANGELOG_STRUCT=$(npx changelog-parser $CHANGELOG_FILE)
else CHANGELOG_STRUCT='{"versions":[]}'
fi

if echo $CHANGELOG_STRUCT | jq -e --arg version $CURRENT_VERSION '.versions[] | select(.version == $version)' > /dev/null;
then echo_green $CHANGELOG_FILE file contains $CURRENT_VERSION
else echo_red $CHANGELOG_FILE file does not contain $CURRENT_VERSION; FAILED=true
fi

if echo $CHANGED_FILES | grep -q $CHANGELOG_FILE;
then echo_green $CHANGELOG_FILE file changed on $CI_MERGE_REQUEST_SOURCE_BRANCH_NAME
else echo_red $CHANGELOG_FILE file did not change on $CI_MERGE_REQUEST_SOURCE_BRANCH_NAME; FAILED=true
fi

if echo $CHANGED_FILES_TO_CURRENT_TARGET | grep -q $CHANGELOG_FILE;
then echo_green $CHANGELOG_FILE file changed compared to current $CI_MERGE_REQUEST_TARGET_BRANCH_NAME
else echo_red $CHANGELOG_FILE file did not change compared to current $CI_MERGE_REQUEST_TARGET_BRANCH_NAME; FAILED=true
fi

if [ ! -z "$FAILED" ]; then
  echo "Some checks for versioning failed"
  exit 1;
fi