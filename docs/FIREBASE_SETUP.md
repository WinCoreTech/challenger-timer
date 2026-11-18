# Firebase setup (for friends, sync and duels)

The app already contains the friend, duel, nudge and board logic, the security rules and
their tests. What it does not have is **your** Firebase project. Until you add the file in
step 7, every social feature shows "not connected" and shares nothing.

Time: about 45 minutes. You need a Google account.

1. Go to https://console.firebase.google.com and choose **Add project**. Name it
   `productivity-go`. You can switch Google Analytics off.
2. In the project, open **Build, Authentication, Get started**, then **Sign-in method**, then
   switch on **Google**. Choose a support email.
3. Open **Build, Firestore Database, Create database**. Pick **Production mode** and the
   region closest to you (for India: `asia-south1`).
4. Open the **Rules** tab of Firestore and replace everything with the contents of
   `firebase/firestore.rules` from this repo. Press **Publish**.
5. Open **Project settings, Your apps, Add app, Android**. Package name:
   `com.wincoretech.challenger_timer` (it is unchanged on purpose). Nickname: Productivity Go.
6. Add the **SHA-1 fingerprint** of the build that will sign in. For the CI debug builds,
   download the debug keystore fingerprint from the GitHub Actions log of the "Build debug
   APK" step, or run `./gradlew signingReport` on a computer with Android Studio. Add every
   fingerprint you will use. Without it, Google sign-in fails with error 10.
7. Download **google-services.json** and put it at `android/app/google-services.json`.
   Do not paste its contents anywhere public. It is not a secret key, but keep it out of
   screenshots. Commit it, or tell me where it is and I will.
8. Tell me "Firebase is connected". The remaining steps are mine: add the Google services
   plugin to Gradle, add the Firebase packages, implement `SocialBackend` with Firestore,
   and run the friends check from `PROGRESS.md`.

## What gets stored (and what never does)
- `users/{uid}`: display name and invite code.
- `users/{uid}/days/{day}`: minutes, sessions, streak, rank. Numbers only.
- `users/{uid}/links/{other}`: how you see each friend (requested, pending, accepted, muted, blocked).
- `nudges` and `duels`: fixed-line nudges and one-day duels.
- **Never stored:** project names, notes, proof text, photos, voice notes, backups.
  The rules reject any document with such a field, and `test/social_test.dart` checks the
  phone never builds one.

## Check the rules yourself
```
cd firebase && npm install && npm test
```
This starts the Firestore emulator and runs 15 tests. CI runs them on every push.

## Delete my data
In the app: Settings, Friends, Delete account. It removes your profile, days, links,
nudges and duels, and your entry in your friends' lists.
