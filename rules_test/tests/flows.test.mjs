// End-to-end "contract" tests: one tour from start to finish, sending exactly
// the writes the app's services send (same documents, fields and batches; see
// the lib/services/*.dart function named in each step), against the real
// firestore.rules. If a service and the rules ever disagree, a feature breaks
// in the app; this catches it.
//
// Run from rules_test/: `npm test`.

import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  Timestamp,
  arrayRemove,
  arrayUnion,
  collection,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const HOUR = 3600 * 1000;
const DAY = 24 * HOUR;
const GID = 'tour-1';
const names = { alice: 'Alice Akter', bob: 'Bob Biswas', carol: 'Carol Chowdhury', dave: 'Dave Das' };

let env;
// One database handle per user: transactions and batches can't mix handles.
const dbs = {};
const as = (uid) => (dbs[uid] ??= env.authenticatedContext(uid, { email_verified: true }).firestore());
const asUnverified = (uid) => env.authenticatedContext(uid, { email_verified: false }).firestore();
const read = async (path) => {
  let data;
  await env.withSecurityRulesDisabled(async (ctx) => { data = (await getDoc(doc(ctx.firestore(), path))).data(); });
  return data;
};

before(async () => {
  setLogLevel('silent');
  env = await initializeTestEnvironment({
    projectId: 'demo-taka-koi-flows',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

// ── Payloads, mirroring lib/models/*.toMap() ──────────────────────────────────
const member = (uid, extra = {}) => ({
  name: names[uid], avatarUrl: '', joinedAt: Timestamp.now(), hasApprovedExpense: false, ...extra,
});

const expenseDoc = ({ by, amount, comment, splits, splitType = 'equal' }) => {
  const others = Object.keys(splits).filter((u) => u !== by);
  const solo = others.length === 0;
  return {
    loggedBy: by, loggedByName: names[by], amount, comment, location: null, splitType,
    splits: Object.fromEntries(Object.entries(splits).map(([u, a]) => [u, { name: names[u], amount: a }])),
    loggerIncluded: by in splits,
    status: solo ? 'approved' : 'pending',
    createdAt: Timestamp.now(),
    approvedAt: solo ? Timestamp.now() : null,
    approvals: solo ? {} : Object.fromEntries(others.map((u) => [u, 'pending'])),
    rejectionReasons: {},
  };
};

const notification = (from, to, type, ref, message) => ({
  senderId: from, targetUserId: to, groupId: GID, groupName: 'Cox\'s Bazar', type, referenceId: ref,
  message, isRead: false, createdAt: Timestamp.now(),
});

// ── Service operations (same writes as the Dart services) ─────────────────────

/** ExpenseService.logExpense */
async function logExpense(uid, id, data) {
  const db = as(uid);
  const batch = writeBatch(db);
  batch.set(doc(db, `groups/${GID}/expenses/${id}`), data);
  const solo = Object.keys(data.approvals).length === 0;
  batch.update(doc(db, `groups/${GID}`), {
    lastActivityAt: serverTimestamp(),
    ...(solo ? {} : { [`members.${uid}.hasApprovedExpense`]: true }),
  });
  await batch.commit();
  // audit log (fire-and-forget in the app)
  const audit = doc(collection(db, `groups/${GID}/auditLog`));
  await setDoc(audit, { action: data.status, actorId: uid, referenceId: id, dataHash: 'x', timestamp: Timestamp.now() });
}

/** ExpenseService.approveExpense (transaction) */
async function approveExpense(uid, id) {
  const db = as(uid);
  return runTransaction(db, async (tx) => {
    const expRef = doc(db, `groups/${GID}/expenses/${id}`);
    const groupRef = doc(db, `groups/${GID}`);
    const exp = (await tx.get(expRef)).data();
    const group = (await tx.get(groupRef)).data();
    const approvals = { ...exp.approvals, [uid]: 'approved' };
    const allDone = Object.values(approvals).every((v) => v === 'approved');
    const inGroup = uid in group.members;
    if (!allDone) {
      tx.update(expRef, { [`approvals.${uid}`]: 'approved' });
      if (inGroup) tx.update(groupRef, { [`members.${uid}.hasApprovedExpense`]: true });
      return 'recorded';
    }
    tx.update(expRef, { [`approvals.${uid}`]: 'approved', status: 'approved', approvedAt: Timestamp.now() });
    for (const [u, s] of Object.entries(exp.splits)) {
      if (u === exp.loggedBy) continue;
      const cents = Math.round(s.amount * 100);
      if (cents <= 0) continue;
      tx.set(doc(db, `groups/${GID}/debts/${id}_${u}`), {
        fromUserId: u, fromUserName: s.name, toUserId: exp.loggedBy, toUserName: exp.loggedByName,
        sourceExpenseId: id, originalAmount: cents / 100, remainingAmount: cents / 100,
        status: 'active', createdAt: Timestamp.now(), settledAt: null,
      });
    }
    if (inGroup) {
      tx.update(groupRef, { lastActivityAt: serverTimestamp(), [`members.${uid}.hasApprovedExpense`]: true });
    }
    return 'finalised';
  });
}

/** ExpenseService.rejectExpense */
const rejectExpense = (uid, id, reason) => runTransaction(as(uid), async (tx) => {
  const ref = doc(as(uid), `groups/${GID}/expenses/${id}`);
  await tx.get(ref);
  tx.update(ref, { [`approvals.${uid}`]: 'rejected', ...(reason ? { [`rejectionReasons.${uid}`]: reason } : {}) });
});

/** ExpenseService.requestAgain */
const requestAgain = (uid, id, target) => runTransaction(as(uid), async (tx) => {
  const ref = doc(as(uid), `groups/${GID}/expenses/${id}`);
  await tx.get(ref);
  tx.update(ref, {
    [`approvals.${target}`]: 'pending', [`rejectionReasons.${target}`]: deleteField(), requestedAgainFor: target,
  });
});

/** ExpenseService.editAndRequestAgain */
const editAndRequestAgain = (uid, id, target, newAmount) => runTransaction(as(uid), async (tx) => {
  const db = as(uid);
  const ref = doc(db, `groups/${GID}/expenses/${id}`);
  const exp = (await tx.get(ref)).data();
  const oldCents = Math.round(exp.splits[target].amount * 100);
  const loggerCents = exp.splits[uid] ? Math.round(exp.splits[uid].amount * 100) : 0;
  const newCents = Math.round(newAmount * 100);
  const splits = { ...exp.splits, [target]: { name: exp.splits[target].name, amount: newCents / 100 } };
  splits[uid] = { name: names[uid], amount: (loggerCents - (newCents - oldCents)) / 100 };
  tx.update(ref, {
    splits, [`approvals.${target}`]: 'pending', [`rejectionReasons.${target}`]: deleteField(), requestedAgainFor: target,
  });
});

/** DebtService.logPayment */
async function logPayment(uid, payId, debtId, toUid, amount) {
  const db = as(uid);
  const batch = writeBatch(db);
  batch.set(doc(db, `groups/${GID}/payments/${payId}`), {
    fromUserId: uid, fromUserName: names[uid], toUserId: toUid, toUserName: names[toUid], debtId, amount,
    bkashNumber: null, status: 'pending', rejectionNote: null, loggedAt: Timestamp.now(), approvedAt: null, resubmittedAt: null,
  });
  batch.update(doc(db, `groups/${GID}`), { lastActivityAt: serverTimestamp() });
  await batch.commit();
}

/** DebtService.approvePayment (transaction) */
const approvePayment = (uid, payId) => runTransaction(as(uid), async (tx) => {
  const db = as(uid);
  const payRef = doc(db, `groups/${GID}/payments/${payId}`);
  const pay = (await tx.get(payRef)).data();
  const debtRef = doc(db, `groups/${GID}/debts/${pay.debtId}`);
  const debt = (await tx.get(debtRef)).data();
  const remaining = Math.round(debt.remainingAmount * 100) - Math.round(pay.amount * 100);
  tx.update(payRef, { status: 'approved', approvedAt: Timestamp.now() });
  tx.update(debtRef, {
    remainingAmount: remaining / 100,
    status: remaining === 0 ? 'settled' : 'active',
    ...(remaining === 0 ? { settledAt: Timestamp.now() } : {}),
  });
  tx.update(doc(db, `groups/${GID}`), { lastActivityAt: serverTimestamp() });
  return remaining / 100;
});

/** DebtService.rejectPayment */
const rejectPayment = (uid, payId, note) =>
  updateDoc(doc(as(uid), `groups/${GID}/payments/${payId}`), { status: 'rejected', rejectionNote: note });

/** NotificationService.send */
const notify = (from, to, type, ref, message) =>
  setDoc(doc(collection(as(from), 'notifications')), notification(from, to, type, ref, message));

/** GroupService.joinGroup (the write part; the code lookup is tested separately) */
async function join(uid, code) {
  const db = as(uid);
  const batch = writeBatch(db);
  batch.update(doc(db, `groups/${GID}`), {
    [`members.${uid}`]: { ...member(uid), joinCode: code },
    memberIds: arrayUnion(uid),
    lastActivityAt: serverTimestamp(),
  });
  batch.update(doc(db, `users/${uid}`), { activeGroupId: GID });
  await batch.commit();
}

// ── The story ─────────────────────────────────────────────────────────────────
test('a whole tour, through the app\'s own writes', async (t) => {
  const code1 = 'TK7Q2M';
  const code2 = 'NEW234';

  await t.test('register: a new user creates their profile before verifying (AuthService.createUserDoc)', async () => {
    for (const uid of Object.keys(names)) {
      await assertSucceeds(setDoc(doc(asUnverified(uid), `users/${uid}`), {
        uid, name: names[uid], email: `${uid}@taka.test`, avatarUrl: '', bkashNumber: null,
        activeGroupId: null, createdAt: Timestamp.now(),
      }));
    }
    await assertFails(getDoc(doc(asUnverified('dave'), 'groupCodes/ANYTHING')));
  });

  await t.test('set a profile photo (AvatarService.save) and use it on the profile', async () => {
    await assertSucceeds(setDoc(doc(as('alice'), 'avatars/alice'), { data: 'A'.repeat(25000), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), { avatarUrl: 'fs:alice' }));
    assert.equal((await assertSucceeds(getDoc(doc(as('bob'), 'avatars/alice')))).data().data.length, 25000);
  });

  await t.test('create a tour (GroupService.createGroup)', async () => {
    const db = as('alice');
    const batch = writeBatch(db);
    const expiresAt = Timestamp.fromMillis(Date.now() + HOUR);
    batch.set(doc(db, `groups/${GID}`), {
      name: 'Cox\'s Bazar', adminId: 'alice', creatorId: 'alice', currency: 'BDT', currencySymbol: '৳',
      status: 'active', groupCode: code1, groupCodeExpiresAt: expiresAt, lastActivityAt: serverTimestamp(),
      createdAt: Timestamp.now(), inactivatedAt: null, inactivatedBy: null,
      members: { alice: member('alice') }, memberIds: ['alice'],
    });
    batch.set(doc(db, `groupCodes/${code1}`), { groupId: GID, expiresAt });
    batch.update(doc(db, 'users/alice'), { activeGroupId: GID });
    await assertSucceeds(batch.commit());
  });

  await t.test('join with the code; outsiders can look the code up but not read the tour', async () => {
    const codeDoc = await assertSucceeds(getDoc(doc(as('bob'), `groupCodes/${code1}`)));
    assert.equal(codeDoc.data().groupId, GID);
    await assertFails(getDoc(doc(as('bob'), `groups/${GID}`)));
    await assertSucceeds(join('bob', code1));
    await assertSucceeds(join('carol', code1));
    await assertFails(join('dave', 'WRONG1'));
  });

  await t.test('new join code; the old one stops working (GroupService.refreshGroupCode)', async () => {
    const db = as('alice');
    const batch = writeBatch(db);
    const expiresAt = Timestamp.fromMillis(Date.now() + HOUR);
    batch.delete(doc(db, `groupCodes/${code1}`));
    batch.set(doc(db, `groupCodes/${code2}`), { groupId: GID, expiresAt });
    batch.update(doc(db, `groups/${GID}`), { groupCode: code2, groupCodeExpiresAt: expiresAt });
    await assertSucceeds(batch.commit());
    await assertFails(join('dave', code1));
    await assertSucceeds(join('dave', code2));
  });

  await t.test('the admin removes a member with no expenses (GroupService.removeMember)', async () => {
    await assertSucceeds(updateDoc(doc(as('alice'), `groups/${GID}`), {
      'members.dave': deleteField(), memberIds: arrayRemove('dave'),
    }));
    await assertFails(getDoc(doc(as('dave'), `groups/${GID}`)));
  });

  await t.test('log a shared expense and notify the others', async () => {
    await assertSucceeds(logExpense('alice', 'dinner', expenseDoc({
      by: 'alice', amount: 300, comment: 'Dinner', splits: { alice: 100, bob: 100, carol: 100 },
    })));
    await assertSucceeds(notify('alice', 'bob', 'expense_pending_approval', 'dinner', 'Approve ৳100.00'));
    await assertSucceeds(notify('alice', 'carol', 'expense_pending_approval', 'dinner', 'Approve ৳100.00'));
  });

  await t.test('approve, reject with a reason, ask again, then the last approval creates the debts', async () => {
    assert.equal(await assertSucceeds(approveExpense('bob', 'dinner')), 'recorded');
    await assertSucceeds(rejectExpense('carol', 'dinner', 'I only had tea'));
    await assertSucceeds(requestAgain('alice', 'dinner', 'carol'));
    assert.equal(await assertSucceeds(approveExpense('carol', 'dinner')), 'finalised');
    const exp = await read(`groups/${GID}/expenses/dinner`);
    assert.equal(exp.status, 'approved');
    assert.equal((await read(`groups/${GID}/debts/dinner_bob`)).remainingAmount, 100);
    assert.equal((await read(`groups/${GID}/debts/dinner_carol`)).toUserId, 'alice');
  });

  await t.test('approvals made offline: everyone approves but nobody is "last"; the logger finishes it', async () => {
    await assertSucceeds(logExpense('alice', 'boat', expenseDoc({
      by: 'alice', amount: 90, comment: 'Boat', splits: { alice: 30, bob: 30, carol: 30 },
    })));
    // Each phone saw the other still pending, so both queued a plain approval.
    await assertSucceeds(updateDoc(doc(as('bob'), `groups/${GID}/expenses/boat`), { 'approvals.bob': 'approved' }));
    await assertSucceeds(updateDoc(doc(as('carol'), `groups/${GID}/expenses/boat`), { 'approvals.carol': 'approved' }));
    assert.equal((await read(`groups/${GID}/expenses/boat`)).status, 'pending');
    // Not anyone can finish it, only the logger (ExpenseService.finaliseIfAllApproved).
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}/expenses/boat`), { status: 'approved', approvedAt: Timestamp.now() }));
    const db = as('alice');
    await assertSucceeds(runTransaction(db, async (tx) => {
      const ref = doc(db, `groups/${GID}/expenses/boat`);
      const exp = (await tx.get(ref)).data();
      tx.update(ref, { status: 'approved', approvedAt: Timestamp.now() });
      for (const [u, sp] of Object.entries(exp.splits)) {
        if (u === 'alice') continue;
        tx.set(doc(db, `groups/${GID}/debts/boat_${u}`), {
          fromUserId: u, fromUserName: sp.name, toUserId: 'alice', toUserName: names.alice, sourceExpenseId: 'boat',
          originalAmount: sp.amount, remainingAmount: sp.amount, status: 'active', createdAt: Timestamp.now(), settledAt: null,
        });
      }
      tx.update(doc(db, `groups/${GID}`), { lastActivityAt: serverTimestamp() });
    }));
    assert.equal((await read(`groups/${GID}/debts/boat_carol`)).remainingAmount, 30);
  });

  await t.test('custom split: change a rejected share and ask again (ExpenseService.editAndRequestAgain)', async () => {
    await assertSucceeds(logExpense('bob', 'tickets', expenseDoc({
      by: 'bob', amount: 100, comment: 'Tickets', splitType: 'custom', splits: { bob: 70, alice: 30 },
    })));
    await assertSucceeds(rejectExpense('alice', 'tickets', 'Mine was 20'));
    await assertSucceeds(editAndRequestAgain('bob', 'tickets', 'alice', 20));
    await assertSucceeds(approveExpense('alice', 'tickets'));
    assert.equal((await read(`groups/${GID}/debts/tickets_alice`)).remainingAmount, 20);
  });

  await t.test('pay in parts; the receiver confirms or rejects; the debt settles at zero', async () => {
    await assertSucceeds(logPayment('bob', 'p1', 'dinner_bob', 'alice', 60));
    assert.equal(await assertSucceeds(approvePayment('alice', 'p1')), 40);
    await assertFails(logPayment('bob', 'p2', 'dinner_bob', 'alice', 50)); // more than what's left
    await assertSucceeds(logPayment('bob', 'p2', 'dinner_bob', 'alice', 40));
    await assertFails(approvePayment('bob', 'p2'));                        // only the receiver confirms
    await assertSucceeds(rejectPayment('alice', 'p2', 'Not received yet'));
    await assertSucceeds(logPayment('bob', 'p3', 'dinner_bob', 'alice', 40));
    assert.equal(await assertSucceeds(approvePayment('alice', 'p3')), 0);
    assert.equal((await read(`groups/${GID}/debts/dinner_bob`)).status, 'settled');
    await assertSucceeds(notify('alice', 'bob', 'payment_approved', 'p3', 'Confirmed'));
  });

  await t.test('bKash: ask, accept (number shared privately), decline, update', async () => {
    const id = `${GID}_carol_alice`;
    await assertSucceeds(setDoc(doc(as('carol'), `bkashRequests/${id}`), {
      groupId: GID, requesterId: 'carol', requesterName: names.carol, targetId: 'alice', targetName: names.alice,
      status: 'pending', createdAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(as('alice'), `bkashRequests/${id}`), {
      status: 'accepted', number: '01700000000', respondedAt: serverTimestamp(),
    }));
    assert.equal((await assertSucceeds(getDoc(doc(as('carol'), `bkashRequests/${id}`)))).data().number, '01700000000');
    await assertFails(getDoc(doc(as('bob'), `bkashRequests/${id}`)));
    await assertFails(getDoc(doc(as('carol'), 'users/alice')));

    // Alice changes her number in her profile; it follows to what she shared (AuthService.updateSharedBkash).
    await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), { bkashNumber: '01800000000' }));
    const shared = await assertSucceeds(getDocs(query(collection(as('alice'), 'bkashRequests'),
      where('targetId', '==', 'alice'), where('status', '==', 'accepted'))));
    const batch = writeBatch(as('alice'));
    shared.docs.forEach((d) => batch.update(doc(as('alice'), `bkashRequests/${d.id}`), { number: '01800000000' }));
    await assertSucceeds(batch.commit());

    const id2 = `${GID}_bob_alice`;
    await assertSucceeds(setDoc(doc(as('bob'), `bkashRequests/${id2}`), {
      groupId: GID, requesterId: 'bob', requesterName: names.bob, targetId: 'alice', targetName: names.alice,
      status: 'pending', createdAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(as('alice'), `bkashRequests/${id2}`), {
      status: 'declined', number: deleteField(), respondedAt: serverTimestamp(),
    }));
  });

  await t.test('notifications: the receiver reads, marks read and deletes; nobody else can', async () => {
    const mine = await assertSucceeds(getDocs(query(collection(as('bob'), 'notifications'), where('targetUserId', '==', 'bob'))));
    assert.ok(mine.size >= 2);
    const first = mine.docs[0].id;
    await assertSucceeds(updateDoc(doc(as('bob'), `notifications/${first}`), { isRead: true }));
    await assertFails(updateDoc(doc(as('carol'), `notifications/${first}`), { isRead: true }));
  });

  await t.test('a member asks to leave and the admin approves (GroupService.approveLeave)', async () => {
    await assertSucceeds(setDoc(doc(as('carol'), `groups/${GID}/leaveRequests/carol`), {
      memberId: 'carol', memberName: names.carol, status: 'pending', requestedAt: Timestamp.now(),
    }));
    const pending = await assertSucceeds(getDocs(query(collection(as('alice'), `groups/${GID}/leaveRequests`),
      where('status', '==', 'pending'))));
    assert.equal(pending.size, 1);
    const db = as('alice');
    const batch = writeBatch(db);
    batch.update(doc(db, `groups/${GID}`), { 'members.carol': deleteField(), memberIds: arrayRemove('carol') });
    batch.delete(doc(db, `groups/${GID}/leaveRequests/carol`));
    await assertSucceeds(batch.commit());
    // Carol's own app clears her active tour (GroupService.clearActiveGroup).
    await assertSucceeds(updateDoc(doc(as('carol'), 'users/carol'), { activeGroupId: null }));
  });

  await t.test('hand over admin, then the new admin deletes an untouched expense', async () => {
    await assertSucceeds(updateDoc(doc(as('alice'), `groups/${GID}`), { adminId: 'bob' }));
    await assertSucceeds(logExpense('alice', 'water', expenseDoc({
      by: 'alice', amount: 50, comment: 'Water', splits: { alice: 25, bob: 25 },
    })));
    await assertSucceeds(approveExpense('bob', 'water'));
    const db = as('bob');
    const batch = writeBatch(db);
    batch.delete(doc(db, `groups/${GID}/expenses/water`));
    batch.delete(doc(db, `groups/${GID}/debts/water_bob`));
    await assertSucceeds(batch.commit());
  });

  await t.test('the admin ends the tour and tells everyone (GroupService.deactivateGroup)', async () => {
    await assertSucceeds(updateDoc(doc(as('bob'), `groups/${GID}`), {
      status: 'inactive', inactivatedAt: serverTimestamp(), inactivatedBy: 'admin',
    }));
    const db = as('bob');
    const batch = writeBatch(db);
    for (const to of ['alice', 'bob']) batch.set(doc(collection(db, 'notifications')), notification('bob', to, 'group_ended', GID, 'Ended'));
    await assertSucceeds(batch.commit());
    await assertFails(logExpense('alice', 'late', expenseDoc({ by: 'alice', amount: 10, comment: 'Late', splits: { alice: 5, bob: 5 } })));
  });

  await t.test('debts can still be settled after the tour ends', async () => {
    // Alice still owes Bob ৳20 for the tickets.
    await assertSucceeds(logPayment('alice', 'p4', 'tickets_alice', 'bob', 20));
    assert.equal(await assertSucceeds(approvePayment('bob', 'p4')), 0);
  });

  await t.test('tour history, then hiding the tour (GroupService.fetchUserGroupHistory / removeFromHistory)', async () => {
    const mine = await assertSucceeds(getDocs(query(collection(as('alice'), 'groups'), where('memberIds', 'array-contains', 'alice'))));
    assert.equal(mine.size, 1);
    await assertFails(getDocs(query(collection(as('alice'), 'groups'), where('status', '==', 'inactive'))));
    await assertSucceeds(updateDoc(doc(as('alice'), `groups/${GID}`), {
      'members.alice': deleteField(), memberIds: arrayRemove('alice'),
    }));
  });

  await t.test('idle tours end automatically, but only after 4 days (GroupService.autoEndIfIdle)', async () => {
    const make = (id, ago) => env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), `groups/${id}`), {
      name: id, adminId: 'alice', creatorId: 'alice', currency: 'BDT', currencySymbol: '৳', status: 'active',
      groupCode: 'IDLE23', groupCodeExpiresAt: Timestamp.now(), lastActivityAt: Timestamp.fromMillis(Date.now() - ago),
      createdAt: Timestamp.now(), inactivatedAt: null, inactivatedBy: null,
      members: { alice: member('alice'), bob: member('bob') }, memberIds: ['alice', 'bob'],
    }));
    await make('idle', 5 * DAY);
    await make('busy', 2 * DAY);
    const end = (id) => runTransaction(as('bob'), async (tx) => {
      const ref = doc(as('bob'), `groups/${id}`);
      await tx.get(ref);
      tx.update(ref, { status: 'inactive', inactivatedAt: serverTimestamp(), inactivatedBy: 'system' });
    });
    await assertSucceeds(end('idle'));
    await assertFails(end('busy'));
  });
});
