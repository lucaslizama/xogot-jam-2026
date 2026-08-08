# Setting up a machine to build this

Most of this is automated. Run it from the repository root:

```
bash tools/setup-dev-env.sh
```

It is safe to run more than once; every step checks whether it is already done.
It never uses root, never installs system packages, and never touches a phone.

What it installs, all under your home directory:

- Godot 4.6.1 as a portable binary, reachable as `godot-4.6`
- The matching export templates, which are about 1.2 GB
- The Android SDK: platform 35, build-tools 35.0.1, and platform-tools
- A debug keystore
- A `phone` command for wireless debugging, added to your shell profile

You need `curl`, `unzip`, and a JDK 17 or newer already present. Everything else
it fetches.

To undo it, delete `~/Android/Sdk`, `~/.local/share/godot-versions`,
`~/.local/share/godot/export_templates`, and the block marked
`# --- Android SDK` at the end of your shell profile.

## Why this project pins an old Godot

The project targets Godot 4.6 and is authored in Xogot on an iPad. Opening it in
a newer Godot offers to convert it, which rewrites the engine version recorded
in the project and risks breaking the round trip with Xogot. Always use
`godot-4.6`, never a bare `godot`, which on a typical machine is something
newer.

## The version numbers, and how to change them

The Android numbers are not arbitrary. Godot ships the Gradle configuration it
was built against inside its own Android template, and that file states the SDK
and build-tools versions it expects. Installing anything else produces a warning
and, in some combinations, a failed export.

To find the right numbers for a different Godot version, unpack the Android
source template from the installed export templates and read `config.gradle`:

```
unzip -o ~/.local/share/godot/export_templates/<version>/android_source.zip -d /tmp/gd
grep -E "compileSdk|targetSdk|buildTools" /tmp/gd/config.gradle
```

Then update the variables at the top of the setup script.

## What has to be done on the phone

None of this can be automated from a computer.

**Turn on developer options.** Settings, then About phone, then tap Build number
seven times.

**Turn on wireless debugging.** In Developer options. It is a separate switch
from USB debugging, and having USB debugging on is not enough.

**Pair, once per computer.** Tap "Pair device with pairing code". A dialog shows
an address and a six digit code. On the computer:

```
adb pair 192.168.1.50:37419 123456
```

The trap here catches nearly everyone: the pairing dialog and the main wireless
debugging screen show **different ports**. Pairing uses the port from the popup.
Connecting afterwards uses the port from the main screen. They are never the
same number, and the connecting port changes again every time wireless debugging
is switched off and on.

Once paired, the `phone` command finds the device over mDNS and neither port
matters again.

## When the phone cannot be reached

Phones aggressively power down their wifi radio. A sleeping phone does not
answer, and `adb` reports `no route to host` as though the network were broken.
Wake the screen and try again; that is almost always all it is.

Expect a ping of 40 to 300 milliseconds to a phone on the same wifi. That is
normal for a radio in power saving and does not affect the game once it is
running, only how long installing takes.

If the phone genuinely never answers while awake, check that it is on the same
network and not a guest SSID, since guest networks commonly block devices from
talking to each other.

## Deploying from the editor

With a device connected, Godot's toolbar grows a device button next to the play
controls, which exports and launches in one step. Two things have to be true
first.

The editor has to have been started after the export presets existed, and after
the Android paths were set. An editor that was already open holds a stale copy
of both in memory and will write it back over the files.

Editor Settings, Export, Android, Java SDK Path has to be set in the GUI rather
than only in the file. The setup script writes it, but a running editor blanks it
on its next save, and then exports fail with an unhelpful message.

Turning on "Deploy with Remote Debug" in that same menu sends the game's output
and errors back to the editor console, which is the difference between debugging
on a phone and guessing.

## Two settings that only bite on a real device

Both are already correct in the project and are recorded here because they cost
an evening to find.

Android requires ETC2 or ASTC texture compression. Without
`rendering/textures/vram_compression/import_etc2_astc` enabled, the export is
refused, and the command line reports the refusal with an **empty error
message**. The reason is only legible in the editor's export dialog. If an
Android export ever fails with no explanation, open that dialog first rather than
guessing.

Handheld orientation is an integer in Godot 4, not the string it was in Godot 3.
A leftover `"portrait"` fails to convert and silently falls back to landscape, so
the game looks right everywhere except on the phone.
