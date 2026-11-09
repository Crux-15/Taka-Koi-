// One-off migration for the security-rules release. Safe to run more than once.
//
// What it does:
//   1. groups:        adds `memberIds` (the plain member list tour history is
//                     queried by) to every group that's missing it or out of step.
//   2. groupCodes:    registers the join code of every active group whose code
//                     hasn't expired, so it keeps working.
//   3. bkashRequests: for requests accepted under the old app, copies the
//                     owner's bKash number onto the request, because the new
//                     rules stop anyone else reading their profile.
//
// It only reads and writes Firestore; it doesn't touch Auth or delete anything.
//
// Usage (from rules_test/):
//   Dry run (prints what would change):
//     GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json npm run migrate
//   Apply:
//     GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json npm run migrate -- --apply
//
// The service account key comes from Firebase console → Project settings →
// Service accounts → Generate new private key. Keep it out of git.

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { pathToFileURL } from 'node:url';

const PROJECT_ID = 'tourexpensetracker-33c77';

function sameMembers(memberIds, members) {
  if (!Array.isArray(memberIds)) return false;
  const keys = Object.keys(members ?? {});
  return memberIds.length === keys.length && keys.every((k) => memberIds.includes(k));
}

/**
 * Runs the migration against [db]. Returns counts of what changed (or would).
 */
export async function migrate(db, { apply = false, log = console.log } = {}) {
  const counts = { memberIds: 0, groupCodes: 0, bkashNumbers: 0 };
  const now = Timestamp.now();

  // 1 + 2: groups
  const groups = await db.collection('groups').get();
  for (const doc of groups.docs) {
    const g = doc.data();
    const members = g.members ?? {};

    if (!sameMembers(g.memberIds, members)) {
      counts.memberIds++;
      log(`groups/${doc.id}: set memberIds (${Object.keys(members).length} members)`);
      if (apply) await doc.ref.update({ memberIds: Object.keys(members) });
    }

    const code = g.groupCode;
    const expires = g.groupCodeExpiresAt;
    const live = g.status === 'active' && code && expires && expires.toMillis() > now.toMillis();
    if (live) {
      const codeRef = db.collection('groupCodes').doc(code);
      const existing = await codeRef.get();
      if (!existing.exists) {
        counts.groupCodes++;
        log(`groupCodes/${code}: register for group ${doc.id}`);
        if (apply) await codeRef.create({ groupId: doc.id, expiresAt: expires });
      }
    }
  }

  // 3: bKash numbers shared under the old app
  const accepted = await db.collection('bkashRequests').where('status', '==', 'accepted').get();
  for (const doc of accepted.docs) {
    const r = doc.data();
    if (Object.prototype.hasOwnProperty.call(r, 'number')) continue;
    const owner = await db.collection('users').doc(r.targetId).get();
    const number = owner.exists ? (owner.data().bkashNumber ?? null) : null;
    counts.bkashNumbers++;
    log(`bkashRequests/${doc.id}: copy ${number ? 'number' : '(none set)'} from users/${r.targetId}`);
    if (apply) await doc.ref.update({ number: number && String(number).trim() ? String(number).trim() : null });
  }

  return counts;
}

// ── CLI ───────────────────────────────────────────────────────────────────────
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const apply = process.argv.includes('--apply');
  initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const counts = await migrate(getFirestore(), { apply });
  console.log(
    `\n${apply ? 'Done' : 'Dry run, nothing written'}: ` +
    `${counts.memberIds} group member lists, ${counts.groupCodes} join codes, ` +
    `${counts.bkashNumbers} shared bKash numbers.` +
    (apply ? '' : '\nRun again with --apply to make these changes.'),
  );
}
