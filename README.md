# EverStrong (working name)

A simple, guided workout app for iPhone and iPad. It is designed to be easy to use for older adults and anyone who wants big, clear, simple screens.

| Tab | What it does |
|---|---|
| **Today** | A greeting, today's suggested micro-workout and program workout, and this week's progress. |
| **Workouts** | Programs for **Strong Over 50**, **Postpartum Recovery**, **Fitness Race Prep** (hybrid fitness racing) and **General Fitness**, plus **micro-workouts** of 5 minutes or less. A guided player gives a large countdown and reads each step aloud. Every exercise has an easier option. |
| **Form Check** | On-device AI uses the camera and Apple's Vision body-pose model to count reps for **squats, lunges and push-ups** and to time **single-leg balance** holds. It gives spoken tips on depth and posture. Video is never recorded or uploaded. It can also be started from any exercise in a workout. |
| **Progress** | Active days this week against a weekly goal, workout streak, minutes moved and recent workouts. |

When you first open the app, it asks what you're training for. That choice sets which program the Today screen suggests. All programs stay available to everyone.

An optional daily notification reminds the user to work out. The time can be changed, or the reminder turned off, in Settings.

### Built for older users
- Every button is at least 72 points tall and has strong contrast.
- **Extra large text** option, plus full support for the iPhone's text size settings.
- Spoken coaching during workouts and form checks, which can be turned off.
- Plain language and one main action per screen.
- Labelled for VoiceOver.

### Safety
- Exercise disclaimers in onboarding and on every workout.
- Postpartum workouts stay locked until the user confirms their doctor or midwife has cleared them.

### Privacy
All data stays on the device and is stored with SwiftData. There are no accounts, servers, analytics or ads. The only permissions are the camera (for form checks) and notifications (for the optional reminder). The App Store privacy label can say **Data Not Collected**.

---

## Building the app (needs a Mac)

1. Install **Xcode** from the Mac App Store. Open it once and let it install the iOS components.
2. Install Homebrew from https://brew.sh, then XcodeGen: `brew install xcodegen`.
3. Download this repository (the `claude/youthful-einstein-g7prmv` branch) and open Terminal in its folder.
4. Run `xcodegen`. This creates `EverStrong.xcodeproj`.
5. Open `EverStrong.xcodeproj`. Select the **EverStrong** target, open **Signing & Capabilities**, and choose your Team (your free Apple ID is enough for testing).
6. In `project.yml`, change `PRODUCT_BUNDLE_IDENTIFIER` from `com.example.everstrong` to your own ID, e.g. `com.yourname.everstrong`. Then run `xcodegen` again.
7. Choose an iPhone simulator and press ⌘R to run. Press ⌘U to run the tests.

> Form check needs a **real iPhone**, because the simulator has no camera. You can run on your own iPhone for free with a personal Apple ID before you pay for the developer program.

Requires iOS 17 or later.

## Publishing on the App Store

1. **Join the Apple Developer Program** at https://developer.apple.com/programs/enroll/. It costs **$99 per year**.
   - **Individual**: quickest, usually approved in 1–2 days. Your personal name is shown as the seller.
   - **Organization**: shows your company name, but needs a registered business and a free **D-U-N-S number**, which can take 1–2 weeks.
2. In **App Store Connect** (https://appstoreconnect.apple.com), create the app with the same bundle ID.
3. Publish the privacy policy in `docs/PRIVACY_POLICY.md` at a public web address. GitHub Pages works.
4. Fill in the listing using `docs/APP_STORE_LISTING.md`.
5. Take screenshots on the largest iPhone simulator (6.9") and an iPad (13").
6. In Xcode, choose **Product → Archive → Distribute App → App Store Connect**.
7. Test with **TestFlight**, ideally with a few people over 50, then submit for review.

See `docs/APP_STORE_LISTING.md` for review risks and how this app addresses them.

## Project layout

```
project.yml                 XcodeGen project definition
EverStrong/
  App/                      App entry point, settings keys
  Models/                   SwiftData models (profile, workout log)
  Data/                     Exercise and workout content
  Services/                 Reminder, speech, pose maths, camera and form check, workout timer, progress maths
  Views/                    SwiftUI screens
  Resources/                App icon, accent colour, privacy manifest
EverStrongTests/            Unit tests (pose maths, rep counting, balance timing, workout timing, progress, content)
docs/                       App Store listing draft and privacy policy
```

## Known limitations and ideas for later
- Form check thresholds (how deep counts as a rep, how much lean triggers a tip) are sensible starting values. They need tuning with real people on a real iPhone.
- Longer, week-by-week programs for each focus.
- Apple Health sync for workouts, and an Apple Watch app.
- Payments via StoreKit, once the pricing model is chosen.
- Medicine reminders, one-tap family calling and a daily "I'm OK" check-in were built and then removed to keep the first release focused. They remain in the git history (commit `1074e09` and the one after it) and could return as a separate companion app.
- The app name **EverStrong** is a placeholder. Check that it is available in App Store Connect and isn't someone else's trademark.
