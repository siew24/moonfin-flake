#!/bin/sh

ci=false
if echo "$@" | grep -qoE '(--ci)'; then
    ci=true
fi

only_check=false
if echo "$@" | grep -qoE '(--only-check)'; then
    only_check=true
fi

remote_tags=$(curl 'https://api.github.com/repos/Moonfin-Client/Moonfin-Core/tags' -s)

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
    download_url="https://api.github.com/repos/Moonfin-Client/Moonfin-Core/zipball/refs/tags/$target_release_name"
    prefetch_output=$(nix store prefetch-file --unpack --hash-type sha256 --json "$download_url")
    sha256=$(echo "$prefetch_output" | jq -r '.hash')

    jq ".variants[\"$os\"] = {\"version\":\"$semver\",\"sha1\":\"$remote_sha1\",\"url\":\"$download_url\",\"sha256\":\"$sha256\"}" <sources.json >sources.json.tmp
    mv sources.json.tmp sources.json

    echo "Updated to $semver. Downloading pubspec.lock locally..."

    pubspec_url="https://raw.githubusercontent.com/Moonfin-Client/Moonfin-Core/$target_release_name/pubspec.lock"
    wget -O - $pubspec_url | yj > pubspec.lock.json

    echo "Updated pubspec.lock.json."

    # Upstream raises its Dart/Flutter floor with some releases (2.6.0 moved to
    # Dart 3.13 while our pinned nixpkgs still shipped 3.12), so take a fresh
    # nixpkgs with every release. This must run before update_git_hashes: the
    # prefetch reads nixpkgs from this flake's lock, and the build has to see the
    # same fetchgit.
    echo "Updating the nixpkgs input..."
    nix flake update nixpkgs

    update_git_hashes

    if ! $ci; then
        return
    fi

    updated=true
    commit_version="$semver"
}

# Nix's own "give me a wrong hash and I will tell you the right one" trick. We
# go through nixpkgs fetchgit rather than nix-prefetch-git on purpose: pub2nix
# fetches these with fetchgit's defaults (submodules included), and a prefetch
# tool with different defaults yields a different NAR and the build then fails
# on a hash mismatch. Sourcing nixpkgs from our own flake input keeps it
# identical to whatever package.nix will use.
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

prefetch_git_hash() {
    _url=$1
    _rev=$2
    _out=$(nix build --no-link --impure --expr "
      let
        flake = builtins.getFlake \"path:$PWD\";
        pkgs = flake.inputs.nixpkgs.legacyPackages.\${builtins.currentSystem};
      in
      pkgs.fetchgit {
        name = \"prefetch-git-hash\";
        url = \"$_url\";
        rev = \"$_rev\";
        hash = \"$FAKE_HASH\";
      }
    " 2>&1) || true
    echo "$_out" | awk '/got:/ { print $2; exit }'
}

# pubspec.lock can point at git repos rather than pub.dev. Those need a Nix
# hash each or pub2nix refuses to evaluate. Upstream switched media_kit to a
# fork in 2.5.0 and that is exactly how main ended up unbuildable.
update_git_hashes() {
    echo "Scanning pubspec.lock.json for git-sourced dependencies..."

    command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required by update_git_hashes" >&2; exit 1; }
    command -v nix >/dev/null 2>&1 || { echo "ERROR: nix is required by update_git_hashes" >&2; exit 1; }


    entries=$(jq -r '
        .packages
        | to_entries[]
        | select(.value.source == "git")
        | [.key, .value.description.url, .value.description."resolved-ref"]
        | @tsv
    ' pubspec.lock.json)

    if [ $? -ne 0 ]; then
        echo "ERROR: jq failed to read pubspec.lock.json" >&2
        exit 1
    fi

    if [ -z "$entries" ]; then
        # A parse that finds nothing when git sources plainly exist means the
        # lock schema moved. Writing {} there would silently reintroduce the
        # very bug this function exists to prevent.
        if grep -qE '"source": ?"git"' pubspec.lock.json; then
            echo "ERROR: pubspec.lock.json has git sources but none parsed." >&2
            echo "Refusing to write an empty git-hashes.json." >&2
            exit 1
        fi
        printf '{}\n' >git-hashes.json
        echo "No git-sourced dependencies. Wrote an empty git-hashes.json."
        return
    fi

    acc=$(mktemp)
    seen=$(mktemp)
    printf '{}' >"$acc"
    : >"$seen"

    while IFS="$(printf '\t')" read -r name url rev; do
        [ -z "$name" ] && continue

        # Several packages commonly share one repo and rev. Fetch it once.
        hash=$(awk -v k="$url@$rev" '$1 == k { print $2; exit }' "$seen")
        if [ -z "$hash" ]; then
            echo "  prefetching $name <- $url @ $rev"
            hash=$(prefetch_git_hash "$url" "$rev")
            if [ -z "$hash" ]; then
                echo "ERROR: could not determine a hash for $name ($url @ $rev)" >&2
                rm -f "$acc" "$seen"
                exit 1
            fi
            printf '%s %s\n' "$url@$rev" "$hash" >>"$seen"
        else
            echo "  reusing hash for $name (same repo and rev)"
        fi

        jq --arg n "$name" --arg h "$hash" '. + {($n): $h}' "$acc" >"$acc.tmp"
        mv "$acc.tmp" "$acc"
    done <<ENTRIES
$entries
ENTRIES

    jq -S '.' "$acc" >git-hashes.json
    rm -f "$acc" "$seen"
    echo "Wrote git-hashes.json:"
    cat git-hashes.json
}

main() {
    set -e

    update_version "linux"

    if $only_check && $ci; then
        echo "should_update=false" >>"$GITHUB_OUTPUT"
    fi

    # Check if there are changes
    if ! git diff --exit-code >/dev/null; then
        # Prepare commit message
        init_message="chore(update):"
        message="$init_message"

        message="$message upgrade to $commit_version"

        echo "commit_message=$message" >>"$GITHUB_OUTPUT"
    fi
}

main
