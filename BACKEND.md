# Backend

The app is local-first and ships with no server. Features that need one are built
against the `Backend` interface in `lib/core/backend.dart` and run on `LocalBackend`,
which reports "not connected" and never invents data. Their screens exist and say so.

To make any of them real you need to create the things below and write a class that
implements `Backend`, then pass it to `backendProvider` in `lib/main.dart`.

| Feature | What you must create | Keys or settings to add |
| --- | --- | --- |
| 70 Gifted freeze | A shared store where two users can see each other (see "Accounts and buddies") | Same as buddies |
| 123 Shared due date (live) | Same as buddies | Same as buddies |
| 131 GitHub sync, 383 Commit mirror | Nothing to host. The public GitHub API works without a key at low volume: `GET https://api.github.com/users/<name>/events/public`. Add the `INTERNET` permission to `AndroidManifest.xml`. For private repos create a fine-grained personal access token with read-only "Contents" and "Metadata". | Optional `GITHUB_TOKEN`, stored on the phone only, never in the repo |
| 146 Cloud backup, 479 | A Firebase project (Storage or Firestore) or a Supabase project with one bucket | `google-services.json` in `android/app/` for Firebase, or `SUPABASE_URL` and `SUPABASE_ANON_KEY` |
| 478 Google login | A Firebase project with Google sign-in enabled, and the debug and release SHA-1 fingerprints registered | `google-services.json` |

| 326 two-way buddy, 328 to 330, 332 to 335, 339, 340, 344, 345, 348, 350 (squads, shared rooms, who is working, leaderboards, duels, cheers, verified proof, mentor access, group board) | Accounts and buddies: a Firebase project with Authentication (Google sign-in) and Firestore, or Supabase with Auth and Postgres. Collections: `users`, `buddies` (pairs), `squads`, `presence` (who is in a session), `days` (one row per user per day: sessions, minutes, streak), `cheers`. Security rules so a user reads only rows of people who accepted them. | `google-services.json`, or `SUPABASE_URL` and `SUPABASE_ANON_KEY` |
| 331 Body doubling with video inside the app | A video service account (Jitsi is free and needs none; Daily or Agora need a key) | Optional `VIDEO_API_KEY` |
| 337 Money stakes that really move money | A payment provider account (Razorpay or UPI collect) and a server to hold and release stakes. Not recommended for a student app. | Provider key and secret, on the server only |
| 380 Problem count sync | LeetCode and Codeforces public profile endpoints (Codeforces has an official API with no key; LeetCode has only an unofficial GraphQL endpoint) | None for Codeforces |

| 526 Coach chat, 532 Stuck helper, 533 Notes Q&A, 534 Quiz maker, 544 Resume bullets, 546 Roadmap generator, 154 AI splitter, 449 AI summary | An Anthropic API account, and a small server (Cloud Function or Supabase Edge Function) that holds the key and forwards requests. Never ship the key inside the APK. | `ANTHROPIC_API_KEY` on the server only; `COACH_URL` in the app |
| 537 Photo to text, 536 content tagging | Google ML Kit text recognition (on-device library, no key) added to `pubspec.yaml`; handwriting quality is limited | None |
| 515 Google Tasks import, 516 Calendar connect | Google Cloud project with the Tasks API enabled and an OAuth client for Android. Calendar can instead use the on-device calendar permission with no server. | OAuth client ID (SHA-1 registered) |
| 423 Group study session, 466 Buddy nudges | Same buddy and squad store as above, plus Firebase Cloud Messaging for nudges | `google-services.json` |

More rows are added as later batches reach features that need a server.
