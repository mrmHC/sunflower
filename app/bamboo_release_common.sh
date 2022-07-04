GIT_TAG=$(git fetch --all && git for-each-ref --count=1 --sort='-*authordate' --format '%(refname:short)' refs/tags/release/android_*)
GIT_TAG_ALPHA=$(git fetch --all && git for-each-ref --count=1 --sort='-*authordate' --format '%(refname:short)' refs/tags/alpha/android_*)

function checkoutReleaseBranch() {
  origin="origin"
  initial_release=${1}

  RELEASE_MAJOR_VERSION=$(getLatestMajorVersionFromTag)

  if [ "${initial_release}" == "true" ]; then
    RELEASE_MAJOR_VERSION=$((RELEASE_MAJOR_VERSION + 1))
  fi

  RELEASE_BRANCH="release/android${RELEASE_MAJOR_VERSION}"
  release_branch_origin="${origin}/${RELEASE_BRANCH}"

  ## Bamboo sometimes checks out into 'detached HEAD' state when there are other commits already on the release branch.
  echo "Checkout ${RELEASE_BRANCH}"
  ${DRY_RUN} git checkout "${RELEASE_BRANCH}"

  echo "Setting branch tracking"
  ${DRY_RUN} git fetch ${origin}
  ${DRY_RUN} git branch --set-upstream-to="${release_branch_origin}" "${RELEASE_BRANCH}"

  ## New commits could have made their way in while the plan was sitting in build queue.
  echo "Pulling latest changes"
  ${DRY_RUN} git stash
  ${DRY_RUN} git pull --rebase
}

function getLatestMajorVersionFromTag() {
  release_version=${GIT_TAG#*_}
  release_major_version=${release_version%.*}

  echo "$release_major_version"
}

function installMissingGems() {
  echo "Installing missing Gems"
  echo "---------------------------------------------------------------------------------------------"
  ${DRY_RUN} set -o xtrace
  if [[ $(which rbenv) ]]; then
    echo 'rbenv is installed'
    ${DRY_RUN} eval "$(rbenv init -)"
    ${DRY_RUN} rbenv install --skip-existing
  elif [[ $(which rvm) ]]; then
    echo 'rvm found'
    ${DRY_RUN} rvm use ruby-2.7.4
  fi
  ${DRY_RUN} bundle install
}