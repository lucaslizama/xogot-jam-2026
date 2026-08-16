#!/usr/bin/env bash
# Cut a release: bump the version the project records, commit it, tag it and
# push. One command, so the number in the project and the tag cannot drift.
#
#   bash tools/release.sh 0.8.0
#
# Pushing the tag is what publishes. The workflow runs the tests first and
# refuses to publish if any of them fail, so a red build cannot go out.
#
# ## Publishing a build exported from Xogot instead
#
# Xogot exports the game on the iPad, and that build can go to itch from here
# rather than being rebuilt in the cloud. It takes two commands, and the order
# matters:
#
#   bash tools/release.sh 0.8.0 --prepare          # bump, commit, push
#   ... pull in Xogot, export the Web preset, bring the folder over ...
#   bash tools/release.sh 0.8.0 --build path/to/web
#
# Two steps because the version the game shows in its corner is baked into the
# .pck when the export runs. Bumping after the export would publish a build that
# names the previous release, which is the exact confusion that label was added
# to end: an evening was lost to art that was already out and a browser serving
# yesterday's build. So --prepare moves the number first, Xogot exports with it,
# and --build refuses if the two disagree.
#
# What --build gives up is the safety net. The cloud build runs the three suites
# and will not publish if any of them fail; nothing here can run them, because
# this machine has no Godot and Xogot has no command line. Run them on whatever
# machine does have Godot, or accept that you are publishing untested. It says so
# out loud rather than pretending.

set -euo pipefail

itch_target="lucaslizama/pizza-flicker"
itch_channel="html5"

version=""
mode="tag"
build_dir=""

while [ $# -gt 0 ]; do
    case "$1" in
        --prepare) mode="prepare" ;;
        --build)
            mode="build"
            shift
            build_dir="${1:-}"
            if [ -z "$build_dir" ]; then
                echo "--build needs the folder Xogot exported into." >&2
                exit 1
            fi
            ;;
        -*)
            echo "unknown option: $1" >&2
            exit 1
            ;;
        *) version="$1" ;;
    esac
    shift
done

if [ -z "$version" ]; then
    echo "usage: bash tools/release.sh 0.8.0" >&2
    echo "       bash tools/release.sh 0.8.0 --prepare" >&2
    echo "       bash tools/release.sh 0.8.0 --build build/web" >&2
    exit 1
fi

if ! printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "The version has to look like 0.8.0: three numbers, dots between, no leading v." >&2
    echo "That is also what the workflow's tag filter matches, so anything else" >&2
    echo "would tag quietly and publish nothing." >&2
    exit 1
fi

cd "$(dirname "$0")/.."

# BSD sed takes the argument after -i as a backup suffix and GNU sed does not, so
# `sed -i "s|...|"` eats the expression on a Mac and fails with an undefined
# label. Writing to a temporary file and moving it over behaves the same on both,
# which matters because this project is developed on macOS and built on Linux.
edit_in_place() {
    local expression="$1" file="$2"
    local temp
    temp="$(mktemp)"
    sed "$expression" "$file" > "$temp"
    mv "$temp" "$file"
}

recorded_version() {
    sed -n 's|^config/version="\(.*\)"$|\1|p' project.godot | head -1
}

stamp_version() {
    if grep -q '^config/version=' project.godot; then
        edit_in_place "s|^config/version=.*|config/version=\"${version}\"|" project.godot
    else
        edit_in_place "s|^config/name=|config/version=\"${version}\"\nconfig/name=|" project.godot
    fi
}

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "The working tree has uncommitted changes. Commit or stash them first, so" >&2
    echo "the tag points at something that actually exists on the branch." >&2
    exit 1
fi

# Untracked files are not "changes" to git, so the check above waves them through.
# That is how a release goes out missing a whole new scene: the menu references
# scenes/ui/settings.tscn, the file was never added, and the published game does
# not open at all. Silence is not consent here.
untracked="$(git ls-files --others --exclude-standard)"
if [ -n "$untracked" ]; then
    echo "These files are not in git, so they will not be in the build:" >&2
    printf '  %s\n' $untracked >&2
    echo "Add them or ignore them, then run this again. A scene that references a" >&2
    echo "file nobody else has does not load, which breaks the game outright." >&2
    exit 1
fi

# --- prepare: move the number so Xogot can export carrying it ----------------

if [ "$mode" = "prepare" ]; then
    previous="$(recorded_version)"
    if [ "$previous" = "$version" ]; then
        echo "project.godot already records $version. Nothing to prepare; export in"
        echo "Xogot and then run --build."
        exit 0
    fi
    stamp_version
    printf 'version: %s -> %s\n' "${previous:-none}" "$version"
    git add project.godot
    git commit -q -m "Set version $version"
    git push origin HEAD
    cat <<EOF

Pushed. Now in Xogot: pull, then export the Web preset as a **release** build.
A debug export puts the tuning sliders in front of players.

Bring the exported folder to this machine and finish with:

  bash tools/release.sh $version --build path/to/web
EOF
    exit 0
fi

if git rev-parse "$version" >/dev/null 2>&1; then
    echo "Tag $version already exists. Pick the next number." >&2
    exit 1
fi

# --- build: publish what Xogot exported --------------------------------------

if [ "$mode" = "build" ]; then
    if [ ! -d "$build_dir" ]; then
        echo "No such folder: $build_dir" >&2
        exit 1
    fi

    # itch serves index.html and nothing else, so a build exported under another
    # name loads a blank page with no error anybody will see.
    for required in index.html index.wasm index.pck; do
        if [ ! -s "$build_dir/$required" ]; then
            echo "$build_dir is missing $required, or it is empty." >&2
            echo "Export the Web preset with index.html as the file name: itch looks" >&2
            echo "for exactly that and serves a blank page otherwise." >&2
            exit 1
        fi
    done

    recorded="$(recorded_version)"
    if [ "$recorded" != "$version" ]; then
        echo "project.godot records ${recorded:-nothing}, but you are releasing $version." >&2
        echo "The version is baked into the .pck at export time, so this build would" >&2
        echo "show ${recorded:-nothing} in its corner while the tag said $version." >&2
        echo "Run --prepare first, pull in Xogot, and export again." >&2
        exit 1
    fi

    # An export older than the newest source file is last week's game. Nothing
    # about the folder says so, and the version now matches either way, so the
    # only tell is the clock.
    newest_source="$(find scenes scripts data sounds sprites shaders fonts project.godot \
        -type f -newer "$build_dir/index.pck" -print -quit 2>/dev/null || true)"
    if [ -n "$newest_source" ]; then
        echo "The export is older than $newest_source." >&2
        echo "Export again in Xogot before publishing; this one predates a change." >&2
        exit 1
    fi

    if ! command -v butler >/dev/null 2>&1; then
        echo "butler is not on the PATH, and it is what talks to itch." >&2
        echo "  brew install butler        (or https://itch.io/docs/butler/)" >&2
        echo "  butler login               (once, opens a browser)" >&2
        exit 1
    fi

    echo "publishing ${build_dir} to ${itch_target}:${itch_channel} as ${version}"
    butler push "$build_dir" "${itch_target}:${itch_channel}" --userversion "$version"
    butler status "${itch_target}:${itch_channel}"

    # Tagged after the push, not before: a tag is a claim that this version is
    # out, and until butler returns it is not.
    git tag -a "$version" -m "Pizza Flicker $version"
    git push origin "$version"

    cat <<EOF

Published from the Xogot export and tagged $version.

The tag also starts the workflow, which builds the game again with Godot and runs
the three test suites. It no longer publishes on its own, so it cannot overwrite
what you just pushed; what it can do is tell you the tests passed.

  gh run watch --repo lucaslizama/xogot-jam-2026
EOF
    exit 0
fi

# --- tag: the cloud builds and publishes -------------------------------------

previous="$(recorded_version)"
stamp_version
printf 'version: %s -> %s\n' "${previous:-none}" "$version"

git add project.godot
git commit -q -m "Release $version"
git tag -a "$version" -m "Pizza Flicker $version"

git push origin HEAD
git push origin "$version"

cat <<EOF

Tagged and pushed. The workflow is running the tests and building the game, and
will not publish on its own. Publish it from the Actions tab: run the workflow by
hand with publish set to true, or push a build exported from Xogot with

  bash tools/release.sh $version --build path/to/web

  gh run watch --repo lucaslizama/xogot-jam-2026
EOF
