#!/usr/bin/env bash
# Check that project.godot still says what it is supposed to say.
#
# A running Godot editor writes project.godot back out from its own in-memory
# settings whenever it saves. An editor that was opened before someone else
# changed a setting therefore reverts that change, with no error, no prompt and
# nothing obvious in the diff. It has happened repeatedly on this project: the
# theme was lost twice, the version was rolled back a release, and the main scene
# stayed pointed at the game long after there was a menu in front of it.
#
# Every line below is here because losing it cost real time. Run it any time, and
# it runs on its own as a pre-commit hook and in CI.
#
#     bash tools/check-project-settings.sh [--skip-version] [path to a project.godot]
#
# The path is for the hook, which checks the staged copy rather than the one on
# disk. Without it the project next to this script is checked. --skip-version is
# for the release workflow, which overwrites the version with the tag it is
# building anyway, and whose shallow checkout has no tags to compare against.
#
# When a value is meant to change, change it here in the same commit. This file
# is the record of what the settings are for.

set -uo pipefail

skip_version=0
if [ "${1:-}" = "--skip-version" ]; then
    skip_version=1
    shift
fi

repo="$(cd "$(dirname "$0")/.." && pwd)"
file="${1:-$repo/project.godot}"
if [ ! -f "$file" ]; then
    echo "check-project-settings: no such file: $file" >&2
    exit 2
fi

failures=0
checked=0

# Report a setting that is missing or has drifted. `why` is printed with it,
# because a bare key name does not tell the next person what breaks.
expect() {
    local key="$1" value="$2" why="$3"
    local found
    checked=$((checked + 1))
    found="$(sed -n "s|^${key}=\(.*\)$|\1|p" "$file" | head -1)"
    if [ -z "$found" ]; then
        printf '  MISSING  %s=%s\n           %s\n' "$key" "$value" "$why"
        failures=$((failures + 1))
    elif [ "$found" != "$value" ]; then
        printf '  CHANGED  %s\n           is   %s\n           want %s\n           %s\n' \
            "$key" "$found" "$value" "$why"
        failures=$((failures + 1))
    fi
}

# --- what the game needs to be the game -------------------------------------

expect 'run/main_scene' '"res://scenes/main_menu.tscn"' \
    'Without this the game launches straight into a street and nobody sees the menu.'

expect 'window/handheld/orientation' '1' \
    'Godot 4 wants the int. The string "portrait" is the Godot 3 spelling and is ignored, which shipped the game landscape on a phone.'

expect 'renderer/rendering_method' '"mobile"' \
    'The project targets phones. The desktop renderer is not what it is tuned or tested against.'

expect 'textures/vram_compression/import_etc2_astc' 'true' \
    'The Android export fails with an empty error message without it, and the command line will not name the reason.'

expect 'window/size/viewport_width' '1170' \
    'The whole layout, and every measurement in the art brief, is in this space.'
expect 'window/size/viewport_height' '2532' \
    'The whole layout, and every measurement in the art brief, is in this space.'

expect 'window/stretch/mode' '"canvas_items"' \
    'Anything else rescales the UI against the street and the two stop lining up.'

expect 'window/stretch/aspect' '"expand"' \
    'Phones are not all 19.5:9. Keeping the aspect letterboxes the ones that are not.'
expect 'window/stretch/aspect.web' '"keep"' \
    'The browser frame is whatever itch was told to make it, so there the aspect is held instead.'

expect 'pointing/emulate_touch_from_mouse' 'true' \
    'The game is touch only. Without this it cannot be played, or tested, with a mouse.'

# --- shape rather than an exact value ---------------------------------------

# Not pinned to a number, since it moves every release. Two things are still
# worth saying about it: a version that is not three numbers publishes nothing at
# all, because the tag filter that triggers a release will not match it, and it
# must never go backwards. A stale editor rolled it from 0.11.0 to 0.10.0 once
# already, which left the repository disagreeing with a tag that was already out.
version="$(sed -n 's|^config/version="\(.*\)"$|\1|p' "$file" | head -1)"
checked=$((checked + 1))
if [ "$skip_version" = 1 ]; then
    checked=$((checked - 1))
elif [ -z "$version" ]; then
    printf '  MISSING  config/version\n           release.sh bumps from this, and the build on itch is named after it.\n'
    failures=$((failures + 1))
elif ! printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    printf '  CHANGED  config/version\n           is   "%s"\n           want three numbers with dots between, no leading v\n' "$version"
    failures=$((failures + 1))
else
    # Compared against the tags rather than a number written down here, so that
    # cutting a release does not mean editing this file too. A fresh clone with no
    # tags fetched has nothing to compare against, and says nothing.
    latest="$(git -C "$repo" tag --list '[0-9]*.[0-9]*.[0-9]*' 2>/dev/null \
        | sort -V | tail -1)"
    checked=$((checked + 1))
    if [ -n "$latest" ] && [ "$version" != "$latest" ]; then
        # sort -V puts the smaller first, so if the recorded version sorts first
        # it is behind the newest release. Being ahead is normal: that is what an
        # unreleased bump looks like.
        if [ "$(printf '%s\n%s\n' "$version" "$latest" | sort -V | head -1)" = "$version" ]; then
            printf '  BEHIND   config/version\n           is   "%s"\n           but  %s is already tagged and published\n' \
                "$version" "$latest"
            failures=$((failures + 1))
        fi
    fi
fi

# --- verdict ----------------------------------------------------------------

if [ "$failures" -gt 0 ]; then
    printf '\nproject.godot has drifted in %d place(s).\n' "$failures"
    cat <<'EOF'

Almost always this is an editor that was open from before someone else's change,
writing its own older settings back over the file. Close the editor, put the
values back, and reopen it. If the change was deliberate, update the expected
value in tools/check-project-settings.sh in the same commit.
EOF
    exit 1
fi

echo "project.godot: $checked settings present and unchanged."
exit 0
