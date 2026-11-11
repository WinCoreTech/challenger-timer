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

More rows are added as later batches reach features that need a server.
