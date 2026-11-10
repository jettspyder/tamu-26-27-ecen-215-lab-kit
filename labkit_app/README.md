# ECEN 215 Lab Kit app

Flutter app that walks students through the ECEN 215 lab procedures step by step and
controls the Lab Kit (DC outputs, DMM, wave gen, scope). This first build uses a
**simulated kit**, so it runs without any hardware.

## One-time setup (Windows)

1. **Git**: install from https://git-scm.com/download/win (all default options).
2. **Google Chrome**: you probably already have it.
3. **VS Code (Windows version)**: https://code.visualstudio.com. During install, tick
   "Add to PATH" and "Add 'Open with Code' action".
4. **Flutter**:
   - Open VS Code → Extensions (Ctrl+Shift+X) → search **Flutter** → Install
     (it installs the Dart extension too).
   - Press **Ctrl+Shift+P**, type **Flutter: New Project**. When VS Code says the
     Flutter SDK wasn't found, click **Download SDK** and pick a folder such as
     `C:\Users\<you>\dev`. Let it finish, and click **Add SDK to PATH** when asked.
     (You can cancel the "new project" afterwards. You only needed the SDK.)
   - Close and reopen VS Code, open a terminal (Ctrl+`) and run `flutter doctor`.
     You only need the **Chrome** line to be a green check for now. Android and
     Visual Studio warnings can be ignored.

## Run the app

1. Unzip this folder somewhere easy, e.g. `Documents\labkit_app`.
2. In VS Code: **File → Open Folder…** → pick `labkit_app`.
3. Open a terminal (Ctrl+`) and run these, one at a time:

   ```
   flutter create --platforms=web,android,ios .
   flutter pub get
   flutter run -d chrome
   ```

   The first command adds the standard platform folders (web, android, ios). It only
   needs to be run once and won't overwrite the app's code. Note the `.` at the end.

Chrome opens with the app inside a phone-sized frame. While it's running, press **r**
in the terminal after a code change to reload, or **q** to quit.

If something fails, copy the full error text from the terminal and send it over.

## Where things are

| Folder / file | What it holds |
|---|---|
| `lib/labs/lab1.dart` | Every Lab 1 step: text, wire colors, breadboard rows, warnings, report questions |
| `lib/labs/catalog.dart` | The list of all 9 labs (add new labs here) |
| `lib/kit/kit_service.dart` | Wire colors, DC outputs, meter modes, and the simulated kit |
| `lib/screens/` | Home, lab walkthrough, Saved, Instruments, Connect, Help |
| `lib/navigation/swipe_route.dart` | Page transition timings |
| `lib/widgets/diagrams.dart` | Breadboard, schematic and part drawings |
| `lib/theme.dart` | Colors and fonts |

## Bluetooth (next step)

All screens talk to `KitService`. To use the real kit, add a Bluetooth class that
implements the same methods (connect, setRail, setMeter, setWave, allOff, readMeter,
readRail) using the nRF52832's BLE service, then swap it in `lib/main.dart`. This needs
the firmware's service and characteristic UUIDs.

## Hosting (later)

`flutter build web` puts a ready-to-upload website in `build/web`. Upload it to
GitHub Pages, Firebase Hosting or Netlify for a link students can add to their home screen.
