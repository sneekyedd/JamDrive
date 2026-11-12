# JamDrive

An iPhone app that turns your music up as you drive faster and back down as you slow down. It works with Spotify and any other music app.

- **Parked:** 25% volume (4 of 16 clicks)
- **80 mph:** 100% volume
- **In between:** volume climbs in a straight line and fades smoothly, with no sudden jumps
- All three numbers can be changed in Settings (the slider icon, top right)

## Using it

1. Start Spotify.
2. Open JamDrive and tap **START**. A small notice reminds you to set your car stereo to the loudest level you'd want at top speed, since JamDrive controls the phone's volume.
3. Switch back to Spotify or Maps. JamDrive keeps running in the background, and a blue location indicator shows at the top of the screen.
4. Tap **STOP** when you arrive. Location tracking turns off and the volume stays where it was.

Tap **MPH** under the speed to switch to km/h.

> ⚠️ Set things up **before** you start driving, and test it as a passenger first.

## Installing it on your iPhone (first time)

You need the Mac, Xcode (free from the Mac App Store) and your iPhone's USB cable.

1. **Get the code onto your Mac.** Open **Terminal** and run:
   ```bash
   git clone -b claude/wonderful-bardeen-34hll5 https://github.com/sneekyedd/JamDrive.git
   ```
   This creates a `JamDrive` folder in your home folder.
2. **Open the project.** Double-click `JamDrive/JamDrive.xcodeproj`. It opens in Xcode.
3. **Sign in with your Apple ID.** In Xcode, go to **Xcode → Settings → Accounts**, click **+**, and add your Apple ID. A free account works.
4. **Choose your signing team.** In the left sidebar, click the blue **JamDrive** project icon, then the **JamDrive** target, then the **Signing & Capabilities** tab. Under **Team**, pick *Your Name (Personal Team)*.
   - If Xcode says the bundle identifier is taken, change `com.sneekyedd.JamDrive` to something unique, like `com.yourname.jamdrive`.
5. **Connect your iPhone** with the cable. Unlock it and tap **Trust** if it asks.
6. **Turn on Developer Mode** on the iPhone: **Settings → Privacy & Security → Developer Mode → On**. The phone restarts. This option only appears after the phone has been connected to Xcode once.
7. **Run it.** At the top of the Xcode window, choose your iPhone from the device menu, then press the ▶︎ **Run** button (or ⌘R).
8. **Trust the app the first time.** If the iPhone says "Untrusted Developer", go to **Settings → General → VPN & Device Management**, tap your Apple ID, and tap **Trust**. Then open JamDrive again.
9. When JamDrive asks for location access, choose **Allow While Using App**.

**Note:** With a free Apple account, apps you install yourself stop opening after **7 days**. When that happens, plug in the phone and press ▶︎ Run in Xcode again. A paid developer account ($99/year) extends this to a year.

## How it works

| File | What it does |
|---|---|
| `JamDrive/SpeedTracker.swift` | Gets GPS readings, which include your speed, from iOS |
| `JamDrive/DriveSettings.swift` | Stores your settings and turns a speed into a volume |
| `JamDrive/DriveController.swift` | Runs a drive: smooths the speed and fades the volume 20 times a second |
| `JamDrive/SystemVolume.swift` | Changes the phone's volume (see the note below) |
| `JamDrive/ContentView.swift` | The main dashboard screen |
| `JamDrive/VolumeMeter.swift` | The 16-column volume bar and visualizer |
| `JamDrive/SettingsView.swift` | The settings screen |

**About the volume trick.** Apple doesn't give apps an official way to change the phone's main volume. JamDrive uses a common workaround: it places Apple's own volume slider on screen, nearly invisible, and moves it from code. This works today, but a future iOS update could break it. It's also why this approach probably wouldn't pass App Store review as is.

**About the visualizer.** iOS doesn't let one app listen to another app's audio, so the bouncing bars are animation, not Spotify's actual sound. They only bounce while a drive is running and music is playing. The number of lit columns always shows the real volume.

**About the volume buttons.** JamDrive assumes it is in charge of the volume. If you press the side buttons during a drive, JamDrive sets its own level again the next time your speed changes.
