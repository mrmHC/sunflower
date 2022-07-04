#!/bin/bash
# exits the script with an error code if *any* command fails
set -e

function echoerr() {
  echo "" 1>&2
  echo "$@" 1>&2
  echo "" 1>&2
}

function usage() {
  echo "Set version code and name for release. THIS IS MEANT TO BE USED ONLY BY BAMBOO!"
  echo
  echo "./bamboo_release_versioning.sh"
  echo
  echo -e "\t-H"
  echo -e "\t--help"
  echo -e "\t\tShows this help"
  echo
  echo -e "\t-D"
  echo -e "\t--dry-run"
  echo -e "\t\tInstead of performing operations, will simply echo the commands to STDOUT."
  echo
}

BASEDIR=$(git rev-parse --show-toplevel)
pushd $BASEDIR

DRY_RUN=""
RELEASE_BRANCH=""
GRADLE_FILE="./app/build.gradle"
VERSION_CODE=""

while [ "$1" != "" ]; do
  PARAM=$(echo $1 | awk -F= '{print $1}')
  case ${PARAM} in
  -H | --help)
    usage
    exit
    ;;
  -D | --dry-run)
    DRY_RUN="echo "
    ;;
  *)
    echoerr "ERROR: unknown parameter \"$PARAM\""
    usage
    exit 1
    ;;
  esac
  shift
done

source ./app/bamboo_release_common.sh

function getGradleVersionName(){
  gradleVersionNameTmp=$(grep -m1 ' VERSION_NAME = "[^0-9]*[0-9]*[^0-9]*[^0-9]*.[^0-9]*"' ${GRADLE_FILE})
  gradleVersionNameTmp=${gradleVersionNameTmp#*VERSION_NAME = }
  gradleVersionName=$(echo $gradleVersionNameTmp | sed -e 's/^"//'  -e 's/"$//')
  echo "$gradleVersionName"
}

function getGradleVersionNameMinor(){
  gradleVersionName=$(getGradleVersionName)
  gradleMinorVersion=${gradleVersionName#*.}
  echo "$gradleMinorVersion"
}

function bumpVersionCode() {
  ## Read app version from previous tag
  release_version_code=${GIT_TAG_ALPHA#*(}
  release_version_code=${release_version_code%)*}
  VERSION_CODE=$((release_version_code + 1))

  echo "Bumping app version code from ${release_version_code} to ${VERSION_CODE} in ${RELEASE_BRANCH}..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    ${DRY_RUN} sed -i '' "s/VERSION_CODE = [^0-9]*[0-9]*[^0-9]*[^0-9]*/VERSION_CODE = ${VERSION_CODE}/g" "${GRADLE_FILE}"
  else
    ${DRY_RUN} sed -i "s/VERSION_CODE = [^0-9]*[0-9]*[^0-9]*[^0-9]*/VERSION_CODE = ${VERSION_CODE}/g" "${GRADLE_FILE}"
  fi

  if [ "$(shouldUpdateVersionName)" != "true" ]; then
    ## Commit new version code.
    echo "Bumped to version code ${VERSION_CODE}, committing..."
    ${DRY_RUN} git add "${GRADLE_FILE}"
    ${DRY_RUN} git diff-index --quiet HEAD || git commit --author="Bamboo <>" -m "Bump version code to ${VERSION_CODE}"
  fi
}

function bumpVersionName() {
  if [ "$(shouldUpdateVersionName)" == "true" ]; then
    ## Read app version from previous tag
    majorVersion=$(getReleaseMajorVersionFromGradle)
    minorVersion=$(getReleaseVersionMinorFromTag)
    newMinorVersion=$((minorVersion+1))
    new_version_name="${majorVersion}.${newMinorVersion}"

    echo "Bumping app version name to ${new_version_name} in ${RELEASE_BRANCH}..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      ${DRY_RUN} sed -i '' "s/VERSION_NAME = [^0-9]*[0-9]*[^0-9]*.[^0-9]*/VERSION_NAME = "\""${new_version_name}"\""/g" "${GRADLE_FILE}"
    else
      ${DRY_RUN} sed -i "s/VERSION_NAME = [^0-9]*[0-9]*[^0-9]*.*[^0-9]*/VERSION_NAME = "\""${new_version_name}"\""/g" "${GRADLE_FILE}"
    fi

    ## Commit new version name.
    echo "Bumped to version name ${new_version_name} and code to ${VERSION_CODE}, committing..."
    ${DRY_RUN} git add "${GRADLE_FILE}"
    ${DRY_RUN} git diff-index --quiet HEAD || git commit --author="Bamboo <>" -m "Bump version to ${new_version_name}(${VERSION_CODE})"
  fi
}

#  The version name should only be updated after releasing a patch. In that specific case,
#  the release tag version will be the same as the version in the gradle file
function shouldUpdateVersionName(){
  gradleMajorVersion=$(getReleaseMajorVersionFromGradle)
  majorVersionFromTag=$(getReleaseMajorVersionFromTag)
  minorVersionFromTag=$(getReleaseVersionMinorFromTag)
  gradleMinorVersion=$(getGradleVersionNameMinor)
  if [ "${gradleMinorVersion}" -eq "${minorVersionFromTag}" ] && [ "$gradleMajorVersion" -eq "${majorVersionFromTag}" ]; then
     echo "true"
  else
     echo "false"
  fi
}

function pushChanges() {
  echo "Pushing changes to ${RELEASE_BRANCH}..."
  ${DRY_RUN} git push origin "${RELEASE_BRANCH}"
}

function getReleaseMajorVersionFromGradle(){
  gradleVersionName=$(getGradleVersionName)
  releaseMajorVersion=${gradleVersionName%.*}
  echo "${releaseMajorVersion}"
}

function getReleaseMajorVersionFromTag(){
  releaseMajorVersion=$(getLatestMajorVersionFromTag)

  if [ "${INITIAL_RELEASE}" == "true" ]; then
    releaseMajorVersion=$((releaseMajorVersion + 1))
  fi
  echo ${releaseMajorVersion}
}

function tagReleaseBranch() {
  versionName=$(getGradleVersionName)
  tag="alpha/android_${versionName}(${VERSION_CODE})"

  ${DRY_RUN} git tag -a "${tag}" -m "v=${versionName}(${VERSION_CODE})"
  ${DRY_RUN} git push origin "${tag}"
}

function getReleaseVersionMinorFromTag(){
    release_version=${GIT_TAG#*.}
    last_release_version_name_minor=${release_version%(*}
    echo $((last_release_version_name_minor))
}

getGradleVersionName
bumpVersionCode
bumpVersionName
pushChanges
tagReleaseBranch

popd
