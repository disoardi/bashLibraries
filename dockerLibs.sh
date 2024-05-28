#!/usr/bin/env bash
#
# Builds images for each Dockerfile found recursively in the given directory.
# Resolves image dependencies for images in the same organization.
# Tags images based on the directory structure and git branch names.
#
# Usage: fnInit [Dockerfile|directory] [...]
#
# The parent directory basename is used as the user/organization name.
# The current directory basename is used as the repository name.
# The branch is used as the version, with "master" being tagged as "latest".
# e.g.: parentdir/currentdir:latest
#
# If DOCKER_ORG is defined, it is used as the user/organization name.
# If DOCKER_HUB is defined, it is prefixed to the user/organization name.
# e.g.: $DOCKER_HUB/$DOCKER_ORG/repository:latest
#

# List all service of a dockerfile passed as parameter
fnListServices() {
    local compose_file=$1
    if [ -z "$compose_file" ]; then
        eerror "Error: Please provide the path to the Docker Compose file as an argument."
        return 1
    fi

    if ! command -v yq &> /dev/null; then
        eerror "Error: 'yq' command not found. Please install 'yq' to use this function."
        return 1
    fi

    docker compose -f $compose_file config | yq '.services[]|key'
}

# Normalizes according to docker hub organization/image naming conventions:
fnNormalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g'
}

# Build and tag the image based on the git branches in the current directory:
fnBuildVersion() {
    image="$1"
    shift
    if [ ! -d '.git' ]; then
        edebug "Create single image with name: ${image}"
        # Not a git repository, so simply build a "latest" image version:
        docker build -t "$image" "$@" .
        return $?
    fi
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    edebug "current_branch: ${current_branch}"
    # Iterate over all branches:
    branches=$(git for-each-ref --format='%(refname:short)' refs/heads/)
    for branch in $branches; do
        edebug "branch: ${branch}"
        git checkout "$branch"
        # Tag master as "latest":
        if [ "$branch" = 'master' ] || [ "$branch" = 'main'  ]; then
            branch='latest'
        fi
        # Normalize the branch name:
        branch="$(fnNormalize "$branch")"
        # Build and tag the image with the branch name:
        docker build -t "$image:$branch" "$@" .
    done
    git checkout "$current_branch"
}

# Builds an image for each git branch of the given Dockerfile directory:
fnBuild() {
    cwd="$PWD"
    file="$(basename "$1")"
    dir="$(dirname "$1")"
    cd "$dir" || return 1
    organization="$DOCKER_ORG"
    if [ -z "$organization" ]; then
        # Use the parent folder for the organization/user name:
        organization="$(cd .. && fnNormalize "$(basename "$PWD")")"
    fi
    if [ -n "$DOCKER_HUB" ]; then
        organization="$DOCKER_HUB/$organization"
    fi
    # Use the current folder for the image name:
    image="$organization/$(fnNormalize "$(basename "$PWD")")"
    # Check if the image depends on another image of the same organization:
    from=$(grep "^FROM $organization/" "$file" | awk '{print $2}')
    # If it does, only build if the image is already available:
    if [ -z "$from" ] || docker inspect "$from" > /dev/null 2>&1; then
        fnBuildVersion "$image" -f "$file"
    else
        echo "$image requires $from ..." >&2 && false
    fi
    status=$?
    cd "$cwd" || return 1
    return $status
}

# Builds and tags images for each Dockerfile in the arguments list:
fnBuildImages() {
    # Set the maximum number of calls on the first run:
    if [ "$MAX_CALLS" = 0 ]; then
        # Worst case scenario needs n*(n+1)/2 calls for dependency resolution,
        # which is the sum of all natural numbers (1+2+3+4+...n).
        # n is the number of arguments (=Dockerfiles) provided:
        MAX_CALLS=$(($#*($#+1)/2))
    fi
    CALLS=$((CALLS+1))
    if [ $CALLS -gt $MAX_CALLS ]; then
        ecrit 'Could not resolve image dependencies.' >&2
        return 1
    fi
    for file; do
        # Shift the arguments list to remove the current Dockerfile:
        shift
        # Basic check if the file is a valid Dockerfile:
        if ! grep '^FROM ' "$file"; then
            ecrit "Invalid Dockerfile: $file" >&2
            continue
        fi
        if ! fnBuild "$file"; then
            # The current build requires another image as dependency,
            # so we add it to the end of the build list and start over:
            fnBuildImages "$@" "$file"
            return $?
        fi
    done
}

MAX_CALLS=1
CALLS=0
NEWLINE='
'

# Parses the arguments, finds Dockerfiles and starts the builds:
fnBuildByGitBanchs() {
    args=
    for arg; do
        if [ -d "$arg" ]; then
            # Search for Dockerfiles and add them to the list:
            args="$args$NEWLINE$(find "$arg" -name Dockerfile)"
        else
            args="$args$NEWLINE$arg"
        fi
    done
    # Set the list as arguments, splitting only at newlines:
    IFS="$NEWLINE";
    # shellcheck disable=SC2086
    set -- $args;
    unset IFS
    fnBuildImages "$@"
}

fnBuildSimple(){
    edebug "Simpler images builder running with ${@:-.} arguments"
    docker build "${@:-.}"
}

fnRun() {
    docker run "${@:-.}"
}

fnRunRM() {
    docker run --rm "${@:-.}"
}
