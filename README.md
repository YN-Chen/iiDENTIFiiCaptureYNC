# iiDENTIFii Capture

A small iOS app that captures a photo (a selfie or an ID document), saves it on the
device straight away, and then uploads it to a backend in a way that survives the
messy real world like bad Wi-Fi, the app getting killed, the phone going to sleep.

The short version of what it does: **once you've taken a photo, it will never just
quietly disappear.** Whatever happens to the app whether killed, backgrounded, offline, the
photo either gets uploaded, or sits visibly as "pending"/"failed" until it does.

## Setup / Running the app

- Requires Xcode with iOS 26 SDK or newer.
- Open `iiDENTIFiiCaptureYNC/iiDENTIFiiCaptureYNC.xcodeproj` in Xcode.
- Pick a simulator or your own device as the run destination, and hit Run.
  - **On the simulator**: there's no camera, so use "Choose from Library" instead of
    "Take Photo" — the app hides the camera option automatically when it detects
    there isn't one.
  - **On a real device**: both camera and photo library work. You'll need to select
    your own signing team in Xcode's Signing & Capabilities tab first.
- There's no real backend involved. The app runs its own tiny local server on the
  phone/simulator and uploads to that instead.
- To run the unit tests: open the project in Xcode and press ⌘U, or select the
  `iiDENTIFiiCaptureYNCTests` scheme and run it.

## Debug Menu — simulating a failed upload

**Shake the device** (or Cmd+Ctrl+Z on the simulator, which triggers a shake) to open
a small Debug Menu with one toggle: **"Force uploads to fail (500)."**

Turning it on makes every upload attempt fail on purpose, so you can watch a capture
land in the "Failed" state and try the manual **Retry** button, without needing a real
network problem or editing any code. Turn it off again and uploads go back to normal.

This is purely a testing convenience for seeing the fail state.

## Architecture

The app is built around three pieces, matching the shape the assessment brief itself
suggested:

```
Capture  →  Local Persistence Queue  →  Upload Manager  →  Mock Backend
```

**1. Capture** — the user taps "+", picks the camera or photo library, and gets back
an image. Before that image touches anything else, it's shrunk down and compressed
so we're not holding a big file size photo in memory or sending it over the
network needlessly and only then handed off to be saved.

**2. Local Persistence Queue** — the very first thing that happens to a captured
photo is that it's written to disk via Core Data and marked **"pending."** This
happens *before* any attempt to upload it. That ordering is intentional so that if the
app dies one second later, the photo is already safe on disk, waiting to be tried
again.

Each saved photo has a status that moves through:

```
pending → uploading → uploaded
                    ↘ failed (can be retried manually, which sends it back to uploading)
```

**3. Upload Manager** — a single component responsible for looking at whatever is
sitting in "pending," and trying to upload it. It's triggered automatically by
several different events (app launch, app coming back to the foreground, network
coming back, a periodic background check), and also by a manual tap on "Retry."

## Concurrency & threading

- **Reading and writing the saved photos happens off the main thread.** There are two
  "workspaces" Core Data calls them contexts, one for the screen to read from, one
  for everything else to write to. Writes made in the background workspace
  automatically show up on screen without any extra code, because Core Data merges
  them for us.

- **Only one thing is allowed to decide "should this photo upload right now?" at a
  time.** This matters because several different triggers can all fire close
  together, for example the network coming back online at the exact same moment
  you tap Retry. Without care, both could try to upload the same photo at once,
  causing a duplicate. To prevent that, all of this decision making lives inside a
  single Swift `actor` `UploadManager`, which is a language feature that guarantees
  only one piece of its code runs at a time. It's the same photo being tracked in one
  shared list of "things currently uploading," so a second attempt at the same photo
  is simply turned away.

- **Shrinking/compressing a photo happens off the main thread too**, so tapping the
  camera button never causes the UI to freeze, even for a large image.

- **The one part of the app that deliberately does *not* use the same approach as
  everything else is the mock server** (see below) — it's built the more old-fashioned
  way, using a dedicated background queue, because the networking library it's built
  on `Network.framework` expects to be used that way. Mixing that with the rest of
  the app's approach would have added complexity for no real benefit.

## Resilience strategy

- **The app gets killed while a photo is mid-upload, deliberately or by iOS running
  low on memory.** The next time the app starts up, it always double checks: "is
  anything stuck showing as 'uploading'?" If so, that can only mean the app died
  before finishing so it's reset back to "pending" and retried automatically. No
  exceptions to take out guesswork.

- **The user backgrounds the app while a photo is mid-upload.**
  Rather than hoping iOS gives the app enough time to finish, the app proactively
  cancels that upload the instant it's told it's being backgrounded, and puts the
  photo back to "pending" right then and there. This means it doesn't matter whether
  iOS later fully closes the app or just leaves it in asuspended state either way, nothing is
  left in a half-finished state.

- **There's no internet connection.** The app checks the phone's real network status
  before even attempting an upload. This mattered specifically because the mock server used for this demo
  lives on the phone itself, so switching on Airplane Mode does not, by itself, stop
  the app from reaching it. By explicitly checking real connectivity first, Airplane Mode behaves the
  way you'd expect, the photo just waits, and resumes automatically the
  moment the connection comes back.

- **An upload genuinely fails** It's marked "Failed," shown with
  a Retry button, and also retried automatically later with an increasing wait
  in between attempts 2s, then 4s, 8s, and so on, capped at a minute so a flaky
  connection doesn't get hammered with retries.

- **The user never reopens the app at all.** As a last resort, iOS is asked to
  occasionally wake the app up in the background to check for anything still
  pending. This is best effort only as iOS decides when that actually happens,
  based on things like battery and how often the app is normally used so it's a
  Extra safety net, not something the app depends on.

## Trade-offs & known limitations

Given the 4-hour time box, some choices were made deliberately in favor of
simplicity, and are worth being upfront about:

- **The backend is fake.** There's no real iiDENTIFii server here, the app runs its
  own tiny local HTTP server and talks to that instead, since the goal was to
  demonstrate the pipeline, not build a real backend.
- **No true "background upload."** iOS has a mechanism to let a single upload keep
  running even after the app is fully closed. This app doesn't use it deliberately
  because the app already handles "killed mid-upload" a different way (reset and
  retry from scratch next time), so adding that extra mechanism on top would just be
  solving the same problem twice.
- **A rare, accepted risk: a duplicate send.** If the app crashes at the exact
  moment the server received the photo but before the app recorded that success
  locally, the retry logic will send that same photo again. Preventing this
  completely would mean giving each photo a unique ID the server can use to ignore
  repeats.
- **The background "wake up and check" feature is best-effort**, as mentioned above
  it's an extra safety net, it is not a guarantee.
- **The camera only works on a real device**, not the simulator the app detects this and only offers the photo library option
  when there's no camera available.
- **The Debug Menu is a testing tool only** and has no bearing on the real upload
  logic as it just makes the mock server throw a 500 on purpose so the Failed/Retry
  path can be seen without waiting for a real failure.

## Testing

- **Persistence** — saving a photo correctly, and that fetching "give me all the
  pending ones" actually filters correctly.
- **Retry timing** — the increasing wait between retries, tested directly with
  fake timestamps.
- **The crash-recovery sweep** — that anything stuck at "uploading" really does get
  reset to "pending" on startup, and that everything else is left alone.
- **The Upload Manager itself** — using a fake stand in for both the network call and
  the "is there a connection" check rather than hitting the real mock server, so
  these tests are fast and don't depend on timing. This covers: successful uploads,
  failed uploads, connectivity being off, retrying a failed item bypassing the
  normal wait, two triggers racing each other and *not* causing a duplicate upload,
  and backgrounding correctly resetting an in-flight upload.

Run them with ⌘U in Xcode, or via the `iiDENTIFiiCaptureYNCTests` scheme.

## Manual QA performed

Beyond the automated tests, the following was also checked by hand on a real iPhone,
since some of this is hard to fully simulate:

- Took a real photo with the camera — captured, uploaded, showed up correctly.
- Force-quit the app while a photo was mid-upload, then reopened it — the photo
  correctly went back to "pending" and re-uploaded on its own.
- Backgrounded the app (just hit Home) mid-upload — confirmed, via temporary logging,
  that the app deterministically cancels and resets the photo the moment it's
  backgrounded, rather than relying on luck.
- Turned on Airplane Mode (with Wi-Fi also off) before capturing a photo — it
  correctly stayed at "pending" and never uploaded. Turning the connection back on
  made it upload automatically, with no action needed.
- Used the Debug Menu to force a failure, saw the photo land in "Failed," then
  reverted and tapped Retry — it uploaded successfully.
