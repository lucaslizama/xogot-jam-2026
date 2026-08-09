#!/usr/bin/env bash
# Cut a release: bump the version the project records, commit it, tag it and
# push. One command, so the number in the project and the tag cannot drift.
#
#   bash tools/release.sh 0.8.0
#
# Pushing the tag is what publishes. The workflow runs the tests first and
# refuses to publish if any of them fail, so a red build cannot go out.

set -euo pipefail

version="${1:-}"
if [ -z "$version" ]; then
    echo "usage: bash tools/release.sh 0.8.0" >&2
    exit 1
fi

if ! printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "The version has to look like 0.8.0: three numbers, dots between, no leading v." >&2
    echo "That is also what the workflow's tag filter matches, so anything else" >&2
    echo "would tag quietly and publish nothing." >&2
    exit 1
fi

cd "$(dirname "$0")/.."

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "The working tree has uncommitted changes. Commit or stash them first, so" >&2
    echo "the tag points at something that actually exists on the branch." >&2
    exit 1
fi

if git rev-parse "$version" >/dev/null 2>&1; then
    echo "Tag $version already exists. Pick the next number." >&2
    exit 1
fi

previous="$(sed -n 's|^config/version="\(.*\)"$|\1|p' project.godot)"
if grep -q '^config/version=' project.godot; then
    sed -i "s|^config/version=.*|config/version=\"${version}\"|" project.godot
else
    sed -i "s|^config/name=|config/version=\"${version}\"\nconfig/name=|" project.godot
fi
printf 'version: %s -> %s\n' "${previous:-none}" "$version"

git add project.godot
git commit -q -m "Release $version"
git tag -a "$version" -m "Pizza Flicker $version"

git push origin HEAD
git push origin "$version"

cat <<EOF

Tagged and pushed. The workflow is running the tests and, if they pass, will put
this on itch.io named $version.

  gh run watch --repo lucaslizama/xogot-jam-2026
EOF
