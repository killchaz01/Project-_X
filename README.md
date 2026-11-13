# EverStrong (working name)

An iPhone and iPad app that brings together guided workouts, medicine reminders and staying in touch with family. It is designed to be easy to use for older adults and anyone who wants big, clear, simple screens.

| Tab | What it does |
|---|---|
| **Today** | Greeting, the big green **I'm OK today** button, the next medicine due, today's suggested workout, and photo buttons to call family. |
| **Workouts** | Programs for **Strong Over 50**, **Postpartum Recovery**, **Fitness Race Prep** (Hyrox-style hybrid racing) and **General Fitness**, plus **micro-workouts** of 5 minutes or less. A guided player gives a large countdown and reads each step aloud. |
| **Form Check** | On-device AI uses the camera and Apple's Vision body-pose model to count squat reps. It gives spoken tips on depth and posture. Video is never recorded or uploaded. |
| **Medicines** | Add medicines with one or more daily times. The app sends a reminder notification and has a large **Taken** button. |
| **Family** | Large photo tiles; tap one to call that person. Choose who gets your daily check-in text. |

When you first open the app, it asks what you're training for. That choice sets which program the Today screen suggests. Everything else stays available to everyone.

### Built for older users
- Every button is at least 72 points tall and has strong contrast.
- **Extra large text** option, plus full support for the iPhone's text size settings.
- Spoken coaching during workouts and form checks, which can be turned off.
- Plain language and one main action per screen.
- Labelled for VoiceOver.

### Privacy
All data stays on the device and is stored with SwiftData. There are no accounts, servers, analytics or ads. The App Store privacy label can say **Data Not Collected**.

---

## Building the app (needs a Mac)

1. Install **Xcode** from the Mac App Store.
2. Install XcodeGen: `brew install xcodegen` (Homebrew is at https://brew.sh).
3. In this folder, run `xcodegen`. This creates `EverStrong.xcodeproj`.
4. Open `EverStrong.xcodeproj`. Select the **EverStrong** target, open **Signing & Capabilities**, and choose your Team.
5. In `project.yml`, change `PRODUCT_BUNDLE_IDENTIFIER` from `com.example.everstrong` to your own ID, e.g. `com.yourname.everstrong`. Then run `xcodegen` again.
6. Choose an iPhone simulator and press ⌘R to run. Press ⌘U to run the tests.

> Form check needs a **real iPhone**, because the simulator has no camera. Sending check-in texts and placing calls also only work on a real iPhone. You can run on your own iPhone for free with a personal Apple ID before you pay for the developer program.

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
  Models/                   SwiftData models (profile, medicines, family, check-ins, workout log)
  Data/                     Exercise and workout content
  Services/                 Notifications, speech, pose maths, camera and form check, workout timer
  Views/                    SwiftUI screens, one folder per tab
  Resources/                App icon, accent colour, privacy manifest
EverStrongTests/            Unit tests (pose maths, rep counting, workout timing, content)
docs/                       App Store listing draft and privacy policy
```

## Known limitations and ideas for later
- **Automatic alert if no check-in.** Today, check-ins are texts the user sends. Alerting family automatically when nobody checks in needs a small server and push notifications. This is a good candidate for a paid upgrade.
- Form check covers squatting movements only (squat, sit-to-stand, wall ball). Next: lunges, push-ups and balance.
- Import family from the Contacts app.
- Apple Health sync for workouts, and an Apple Watch app.
- Subscriptions via StoreKit, if you choose that pricing model.
- The app name **EverStrong** is a placeholder. Check that it is available in App Store Connect and isn't someone else's trademark.
