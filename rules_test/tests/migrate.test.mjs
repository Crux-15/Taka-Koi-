// Runs migrate.mjs against the Firestore emulator. Run from rules_test/: `npm test`.

import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import { migrate } from '../migrate.mjs';

let app;
let db;

before(() => {
  app = initializeApp({ projectId: 'demo-taka-koi' }, 'migrate-test');
  db = getFirestore(app);
});

after(async () => {
  await deleteApp(app);
});

test('backfills memberIds, registers live codes and copies shared bKash numbers', async () => {
  const hour = 3600 * 1000;
  await db.doc('groups/old-active').set({
    status: 'active',
    groupCode: 'LIVE23',
    groupCodeExpiresAt: Timestamp.fromMillis(Date.now() + hour),
    members: { a: { name: 'A' }, b: { name: 'B' } },
  });
  await db.doc('groups/old-ended').set({
    status: 'inactive',
    groupCode: 'DEAD23',
    groupCodeExpiresAt: Timestamp.fromMillis(Date.now() - hour),
    members: { a: { name: 'A' } },
  });
  await db.doc('users/b').set({ uid: 'b', bkashNumber: '01700000000' });
  await db.doc('bkashRequests/old-active_a_b').set({
    groupId: 'old-active', requesterId: 'a', targetId: 'b', status: 'accepted',
  });

  const dry = await migrate(db, { apply: false, log: () => {} });
  assert.deepEqual(dry, { memberIds: 2, groupCodes: 1, bkashNumbers: 1 });
  assert.equal((await db.doc('groups/old-active').get()).data().memberIds, undefined);

  await migrate(db, { apply: true, log: () => {} });
  assert.deepEqual((await db.doc('groups/old-active').get()).data().memberIds.sort(), ['a', 'b']);
  assert.deepEqual((await db.doc('groups/old-ended').get()).data().memberIds, ['a']);
  assert.equal((await db.doc('groupCodes/LIVE23').get()).data().groupId, 'old-active');
  assert.equal((await db.doc('groupCodes/DEAD23').get()).exists, false);
  assert.equal((await db.doc('bkashRequests/old-active_a_b').get()).data().number, '01700000000');

  const again = await migrate(db, { apply: true, log: () => {} });
  assert.deepEqual(again, { memberIds: 0, groupCodes: 0, bkashNumbers: 0 });
});
