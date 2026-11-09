# Firestore rules: tests and migration

`firestore.rules` (in the project root) is the app's real
security: the app can be modified, the rules can't. This folder tests them
against the local Firebase emulators and holds the one-off data migration.

## Run the tests

Needs Node 18+, Java 11+ and the Firebase CLI (`npm i -g firebase-tools`).

```bash
cd rules_test
npm install
npm test
```

On Windows the Firestore emulator sometimes keeps running after the tests
finish. If the next run says "port taken", stop the leftover `java` process
listening on port 8080.

## What the tests cover

- `tests/firestore.test.mjs`: each rule, allowed and refused cases.
- `tests/flows.test.mjs`: one whole tour, step by step, sending the same
  writes as the app's services (`lib/services/*.dart`): sign up, start a
  tour, join by code, new code, add and approve or reject expenses, change a
  share, pay in parts, confirm or reject payments, bKash sharing, leave,
  remove, hand over admin, delete, end the tour, settle after it ended, tour
  history and auto-ending. If a service and the rules ever disagree, a
  feature would break in the app; this test fails first.
- `tests/migrate.test.mjs`: the one-off data migration.

## Releasing the rules

Older versions of the app don't work under these rules (for example, they
join tours by searching all groups and stamp activity with the phone's clock).
So:

1. Ship the new app version and get everyone to update.
2. Run the migration: a dry run first, then `--apply` (see the top of `migrate.mjs`).
3. Deploy the rules from the project root:
   ```bash
   firebase deploy --only firestore:rules
   ```

People who signed up with email before this release are asked to confirm their
email (Firebase sends a link) the next time they sign in.

## Things to keep in step with the app

- **Split size:** the rules add an expense's shares up one by one (the rules
  language has no loops), so an expense can be split between at most 50
  people. `MAX_SPLIT` in `firestore.rules` and `AppConstants.maxSplitMembers`
  in the app must match. Raising it means adding terms to `splitsTotal()`.
