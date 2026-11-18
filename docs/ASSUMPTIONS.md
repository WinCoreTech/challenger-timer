# Assumptions

Where a request had two readings, both are written here with the one chosen and why.

## Rename (Part B of the 18 Nov 2026 prompt)
- **Name:** "Productivity Go". Slogan: "Start in 2 minutes. Stay for the streak."
  Reading A: change the name everywhere, including code identifiers and the package id.
  Reading B: change only what a user can see. **Chose B.** Changing the Android
  applicationId would stop new builds installing over old ones, and the Dart package
  name and Kotlin package are invisible. Kept: `com.wincoretech.challenger_timer`,
  the repo name, the Dart package `challenger_timer`, and the class name `ChallengerApp`.
- **Old backups:** files made by earlier builds say "Productivity Challenger Timer".
  They must still load, so the loader accepts both names. New files say "Productivity Go".
- **Deep link:** `productivitygo://start` is the new link. `challengertimer://start` still
  works, because someone may already have written it to an NFC tag.
- **Logo:** the three SVGs in the prompt were used exactly. The in-app mark is drawn in
  code from the same numbers, so no SVG package is needed.
- **Palette:** the brand orange (#FF6A1F), amber and navies replace the earlier orange and
  navy. The light theme is derived from the dark one and follows automatically.

## Autonomy (Part A)
- The prompt says to use parallel subagents on worktrees. Earlier in this project three
  helper agents stopped on a usage limit before producing code, so work is done in the
  main session in small, tested slices.
- "Phase 4 without google-services.json" is built against a local fake backend, with
  security rules, as the prompt describes. See OWNER_TODO.md.
- The prompt arrived cut off in the middle of section 5.4. Sections 5.1 to 5.3 and the
  rest were already built in earlier phases; nothing in the cut-off part changes that work.
- **"Challenge timer"** is also the title of section 4 of FEATURES.md (features 76 to 100).
  That is a generic feature-group name, not the product name, so it was left alone.
- BUILD_PROMPT.md, PROGRESS.md and DECISIONS.md are history and keep the old name where
  they describe the past. FEATURES.md's title and README were updated.
