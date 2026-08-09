#!/usr/bin/env bash
# Sets up everything needed to build and deploy this project on a fresh Linux
# machine: the right Godot, its export templates, the Android SDK, a debug
# keystore, and a `phone` helper for wireless debugging.
#
# Safe to re-run. Every step checks whether it is already done and skips.
#
#   bash tools/setup-dev-env.sh
#
# What it deliberately does NOT do: touch anything as root, install system
# packages, or take actions on your phone. See docs/dev-setup.md for the handful
# of steps that have to happen on the device itself.

set -euo pipefail

# Keep these in step with the engine version the project targets. Everything
# else is derived from them. See docs/dev-setup.md for how to re-derive the
# Android numbers if the Godot version changes.
GODOT_VERSION="4.6.1-stable"
GODOT_SHORT="4.6"
ANDROID_PLATFORM="35"
ANDROID_BUILD_TOOLS="35.0.1"
CMDLINE_TOOLS_BUILD="13114758"

GODOT_DIR="$HOME/.local/share/godot-versions"
GODOT_BIN="$HOME/.local/bin/godot-$GODOT_SHORT"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION/-/.}"
KEYSTORE="$HOME/.local/share/godot/keystores/debug.keystore"
SDK="$HOME/Android/Sdk"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say()  { printf '\n\033[1;35m==>\033[0m %s\n' "$1"; }
ok()   { printf '    \033[32mok\033[0m   %s\n' "$1"; }
skip() { printf '    \033[90mskip\033[0m %s\n' "$1"; }
warn() { printf '    \033[33mwarn\033[0m %s\n' "$1"; }
die()  { printf '\n\033[1;31mfailed:\033[0m %s\n' "$1" >&2; exit 1; }

# --- prerequisites ----------------------------------------------------------

say "Checking prerequisites"
for cmd in curl unzip java keytool; do
    command -v "$cmd" >/dev/null || die "$cmd is not installed. Install it and re-run."
done
ok "curl, unzip, java, keytool"

JAVA_MAJOR="$(java -version 2>&1 | head -1 | grep -oE '[0-9]+' | head -1)"
[ "${JAVA_MAJOR:-0}" -ge 17 ] || die "Java 17 or newer is required (found $JAVA_MAJOR). Godot's Android export will not work with less."
JDK_PATH="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
[ -x "$JDK_PATH/bin/keytool" ] || die "Could not locate a full JDK from $(command -v java). Install a JDK, not just a JRE."
ok "JDK $JAVA_MAJOR at $JDK_PATH"

case "$(uname -m)" in
    x86_64) ;;
    *) warn "This script downloads x86_64 Linux builds. On $(uname -m) you will need different URLs." ;;
esac

# --- Godot ------------------------------------------------------------------

say "Godot $GODOT_VERSION"
if [ -x "$GODOT_BIN" ] && "$GODOT_BIN" --version 2>/dev/null | grep -q "^${GODOT_VERSION%-stable}"; then
    skip "already installed: $("$GODOT_BIN" --version)"
else
    mkdir -p "$GODOT_DIR" "$HOME/.local/bin"
    url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    curl -# -L -o "$WORK/godot.zip" "$url"
    unzip -q -o "$WORK/godot.zip" -d "$WORK"
    mv "$WORK/Godot_v${GODOT_VERSION}_linux.x86_64" "$GODOT_DIR/godot-${GODOT_VERSION%-stable}"
    chmod +x "$GODOT_DIR/godot-${GODOT_VERSION%-stable}"
    ln -sfn "$GODOT_DIR/godot-${GODOT_VERSION%-stable}" "$GODOT_BIN"
    ok "installed as $GODOT_BIN"
fi

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) warn "$HOME/.local/bin is not on your PATH; godot-$GODOT_SHORT will not be found until it is." ;;
esac

# --- export templates -------------------------------------------------------

say "Export templates"
if [ -f "$TEMPLATE_DIR/android_debug.apk" ]; then
    skip "already installed ($(ls "$TEMPLATE_DIR" | wc -l) files)"
else
    url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
    warn "this is about 1.2 GB and will take a while"
    curl -# -L -o "$WORK/templates.tpz" "$url"
    unzip -tq "$WORK/templates.tpz" >/dev/null 2>&1 || die "The template download is corrupt. Re-run to try again."
    unzip -q "$WORK/templates.tpz" -d "$WORK/tpl"
    mkdir -p "$(dirname "$TEMPLATE_DIR")"
    rm -rf "$TEMPLATE_DIR"
    mv "$WORK/tpl/templates" "$TEMPLATE_DIR"
    ok "installed to $TEMPLATE_DIR"
fi

# --- Android SDK ------------------------------------------------------------

say "Android SDK"
SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
if [ -x "$SDKMANAGER" ]; then
    skip "command-line tools already present"
else
    mkdir -p "$SDK/cmdline-tools"
    url="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_BUILD}_latest.zip"
    curl -# -L -o "$WORK/cmdline.zip" "$url"
    unzip -q -o "$WORK/cmdline.zip" -d "$WORK/cmdline"
    rm -rf "$SDK/cmdline-tools/latest"
    mv "$WORK/cmdline/cmdline-tools" "$SDK/cmdline-tools/latest"
    ok "command-line tools installed"
fi

export ANDROID_HOME="$SDK"
export ANDROID_SDK_ROOT="$SDK"

if [ -x "$SDK/platform-tools/adb" ] \
   && [ -d "$SDK/platforms/android-$ANDROID_PLATFORM" ] \
   && [ -d "$SDK/build-tools/$ANDROID_BUILD_TOOLS" ]; then
    skip "platform $ANDROID_PLATFORM, build-tools $ANDROID_BUILD_TOOLS, platform-tools"
else
    yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
    "$SDKMANAGER" "platform-tools" \
        "platforms;android-$ANDROID_PLATFORM" \
        "build-tools;$ANDROID_BUILD_TOOLS" >/dev/null
    ok "platform $ANDROID_PLATFORM, build-tools $ANDROID_BUILD_TOOLS, platform-tools"
fi

for f in "platform-tools/adb" \
         "build-tools/$ANDROID_BUILD_TOOLS/apksigner" \
         "build-tools/$ANDROID_BUILD_TOOLS/zipalign" \
         "platforms/android-$ANDROID_PLATFORM/android.jar"; do
    [ -e "$SDK/$f" ] || die "Expected $SDK/$f after install, but it is missing."
done
ok "every component Godot checks for is present"

# --- debug keystore ---------------------------------------------------------

say "Debug keystore"
if [ -f "$KEYSTORE" ]; then
    skip "already exists"
else
    mkdir -p "$(dirname "$KEYSTORE")"
    keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
        -keystore "$KEYSTORE" -storepass android \
        -dname "CN=Android Debug,O=Android,C=US" -validity 9999 \
        -deststoretype pkcs12 >/dev/null 2>&1
    ok "created at $KEYSTORE"
fi

# --- Godot editor settings --------------------------------------------------

say "Godot editor settings"
SETTINGS="$HOME/.config/godot/editor_settings-$GODOT_SHORT.tres"
if [ ! -f "$SETTINGS" ]; then
    # The file only appears once the editor has run once. A headless import is
    # enough to create it and is quicker than opening the GUI.
    "$GODOT_BIN" --headless --quit >/dev/null 2>&1 || true
fi
if [ -f "$SETTINGS" ]; then
    python3 - "$SETTINGS" "$SDK" "$JDK_PATH" "$KEYSTORE" <<'PY'
import re, sys
path, sdk, jdk, keystore = sys.argv[1:5]
text = open(path).read()
wanted = {
    "export/android/android_sdk_path": sdk,
    "export/android/java_sdk_path": jdk,
    "export/android/debug_keystore": keystore,
    "export/android/debug_keystore_pass": "android",
}
for key, value in wanted.items():
    line = f'{key} = "{value}"'
    if re.search(rf'^{re.escape(key)} = ".*"$', text, re.M):
        text = re.sub(rf'^{re.escape(key)} = ".*"$', line, text, flags=re.M)
    else:
        text = text.replace("[resource]\n", "[resource]\n" + line + "\n", 1)
open(path, "w").write(text)
print("    \033[32mok\033[0m   wrote SDK, JDK and keystore paths")
PY
    warn "a RUNNING Godot editor overwrites this file when it saves, and will blank"
    warn "the Java SDK path again. Close the editor before running this, and set"
    warn "Editor Settings > Export > Android > Java SDK Path in the GUI to make it stick."
else
    warn "could not create $SETTINGS; set the Android paths in Editor Settings by hand."
fi

# --- shell helper -----------------------------------------------------------

say "Shell helper"
MARKER="# --- Android SDK (Godot Android exports) ---"
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$rc" ] || continue
    if grep -qF "$MARKER" "$rc"; then
        skip "$(basename "$rc") already has it"
        continue
    fi
    cat >> "$rc" <<'EOF'

# --- Android SDK (Godot Android exports) ---
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$PATH:$ANDROID_HOME/platform-tools"

# Reconnect a phone for wireless debugging.
#
# Android hands out a NEW PORT every time wireless debugging is toggled, so a
# remembered address goes stale. mDNS survives both the IP and the port
# changing, which is why it is asked first.
#
# It also checks the phone actually answers before trying to connect. A phone
# with its wifi radio asleep keeps being advertised over mDNS long after it
# stops responding, so "found it" and "can reach it" are different questions,
# and adb's own message for the second one is a bare "no route to host".
#
#   phone              discover and connect
#   phone 1.2.3.4:5555 connect to a specific address
phone() {
    adb start-server >/dev/null 2>&1
    if [ -n "$1" ]; then
        adb connect "$1"
        return $?
    fi
    if adb devices | grep -qw "device$"; then
        echo "already connected:"
        adb devices | grep -w "device$"
        return 0
    fi

    local svc host
    svc=$(adb mdns services 2>/dev/null | awk '/_adb-tls-connect/ {print $3; exit}')
    if [ -z "$svc" ]; then
        echo "Nothing advertised. Check the phone is awake, on the same wifi, and that"
        echo "Wireless debugging is on. If it has never been paired, see docs/dev-setup.md."
        return 1
    fi

    host=${svc%%:*}
    echo "advertised at $svc"

    local tries=0
    while ! ping -c 1 -W 1 "$host" >/dev/null 2>&1; do
        tries=$((tries + 1))
        if [ "$tries" -ge 8 ]; then
            echo ""
            echo "  $host is advertised but does not answer."
            echo "  That is the wifi radio asleep, not a broken setup: the advertisement"
            echo "  outlives the connection. WAKE THE PHONE SCREEN and run phone again."
            return 1
        fi
        [ "$tries" = 1 ] && printf "  no answer yet, waiting for the radio to wake"
        printf "."
        sleep 1
    done
    [ "$tries" -gt 0 ] && echo " awake"

    adb connect "$svc"
}
EOF
    ok "added to $(basename "$rc")"
done

# --- done -------------------------------------------------------------------

say "Verifying"
"$GODOT_BIN" --version
ok "godot-$GODOT_SHORT works"
"$SDK/platform-tools/adb" --version | head -1
ok "adb works"

cat <<EOF

$(printf '\033[1;32mSetup complete.\033[0m')

Open a new terminal (or source your shell rc) and then:

    godot-$GODOT_SHORT --headless --path . --export-debug "Android" build/android/app.apk
    phone
    adb install -r build/android/app.apk

Steps that can only be done on the phone itself are in docs/dev-setup.md.
EOF
