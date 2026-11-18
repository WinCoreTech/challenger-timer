# Owner to-do

Things only the owner can do. Each has the default that was applied so work continued.

1. **Run the phone checklist** (end of PROGRESS.md) on the newest APK. Nothing native has
   ever run on a device. *Default applied:* every native feature is marked "built, untested".
2. **Check the name "Productivity Go".** Play Store availability and trademark have NOT
   been checked. The name is generic and may be taken or hard to protect.
   *Default applied:* used as the name everywhere; it is one constant in `lib/brand.dart`
   plus `android:label` in the manifest.
3. **Look at the launcher icon, themed icon, notification icon and launch screen on a real
   phone.** They are generated from `brand/*.svg`. *Default applied:* listed in the phone checklist.
4. **If Android shortens the launcher label** ("Productivity Go" is 15 characters), tell me
   what it shows. *Default applied:* full name kept.
5. **Create a Firebase project** and add `android/app/google-services.json`. Exact steps will
   be in `docs/FIREBASE_SETUP.md`. *Default applied:* all social features run against a local
   fake and are marked "awaiting Firebase file".
6. **A release signing key**, when you want a Play Store build. *Default applied:* debug
   keys only; builds from different CI runs may not install over each other.
7. **Firebase:** follow `docs/FIREBASE_SETUP.md` (45 minutes). Phase 4 logic and the security
   rules are done and tested; only the connection is missing.
