#!/bin/sh

ci=false
if echo "$@" | grep -qoE '(--ci)'; then
    ci=true
fi

only_check=false
if echo "$@" | grep -qoE '(--only-check)'; then
    only_check=true
fi

remote_tags=$(curl 'https://api.github.com/repos/Moonfin-Client/Mobile-Desktop/tags' -s)

with_retry() {
    retries=5
    count=0
    output=""
    status=0

    while [ $count -lt $retries ]; do
        output=$("$@" 2>&1)
        status=$?

        if echo "$output" | grep -q 'Not Found'; then
            count=$((count + 1))
            echo "attempt $count/$retries: 404 Not Found encountered, retrying..." >&2
            sleep 1
        else
            echo "[TRACE] [cmd=$*] output: $output" 1>&2
            echo "$output" | tr -d '\000-\031'
            return $status
        fi
    done

    echo "max retries reached. last output: $output (cmd=$*)" >&2
    exit 1
}

get_tag_short_meta() {
    echo "$remote_tags" | jq -r '(map(select(.name | test("[0-9]+\\.[0-9]+$")))) | first'
}

tag=$(get_tag_short_meta)

resolve_version_remote_sha1() {
    echo "$tag" | jq -r '.commit.sha'
}

resolve_semver() {
    echo "$tag" | jq -r '.name'
}

commit_version=""
updated=false

update_version() {
    os=$1

    meta=$(jq ".variants[\"$os\"]" <sources.json)

    local_sha1=$(echo "$meta" | jq -r '.sha1')
    remote_sha1=$(resolve_version_remote_sha1)

    local="$local_sha1"
    remote="$remote_sha1"

    echo "Checking version @ $arch... local=$local remote=$remote"

    if [ "$local" = "$remote" ]; then
        echo "Local version is up to date"
        return
    fi

    echo "Local version mismatch with remote so we* assume it's outdated"

    if $only_check; then
        echo "should_update=true" >>"$GITHUB_OUTPUT"
        exit 0
    fi

    semver=$(resolve_semver)
    updated_at="$remote"
    target_release_name="$semver"
    download_url="https://api.github.com/repos/Moonfin-Client/Mobile-Desktop/zipball/refs/tags/$target_release_name"
    prefetch_output=$(nix store prefetch-file --unpack --hash-type sha256 --json "$download_url")
    sha256=$(echo "$prefetch_output" | jq -r '.hash')

    jq ".variants[\"$os\"] = {\"version\":\"$semver\",\"sha1\":\"$remote_sha1\",\"url\":\"$download_url\",\"sha256\":\"$sha256\"}" <sources.json >sources.json.tmp
    mv sources.json.tmp sources.json

    echo "Updated to $semver. Downloading pubspec.lock locally..."

    pubspec_url="https://raw.githubusercontent.com/Moonfin-Client/Mobile-Desktop/$target_release_name/pubspec.lock"
    wget -O - $pubspec_url | yj > pubspec.lock.json

    echo "Updated pubspec.lock.json."

    if ! $ci; then
        return
    fi

    updated=true
    commit_version="$semver"
}

main() {
    set -e

    update_version "linux"

    if $only_check && $ci; then
        echo "should_update=false" >>"$GITHUB_OUTPUT"
    fi

    # Check if there are changes
    if $ci && ! git diff --exit-code >/dev/null; then
        # Prepare commit message
        init_message="chore(update):"
        message="$init_message"

        message="$message upgrade to $commit_version"

        echo "commit_message=$message" >>"$GITHUB_OUTPUT"
    fi
}

main
