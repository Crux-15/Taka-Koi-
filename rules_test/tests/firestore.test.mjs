// Tests for firestore.rules. Run from rules_test/: `npm test`.
//
// Cast: alice is the tour admin and logs expenses, bob and carol are members,
// mallory is a verified user outside the tour, dave hasn't verified his email.

import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const GID = 'group-1';
const CODE = 'ABC234';
const HOUR = 3600 * 1000;
const DAY = 24 * HOUR;

let env;

before(async () => {
  setLogLevel('silent'); // denied writes are expected; don't log each one
  env = await initializeTestEnvironment({
    projectId: 'demo-taka-koi',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await seedGroup();
});

// ── Helpers ───────────────────────────────────────────────────────────────────

const as = (uid) => env.authenticatedContext(uid, { email_verified: true }).firestore();
const unverified = (uid) => env.authenticatedContext(uid, { email_verified: false }).firestore();

async function seed(path, data) {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));
}

async function read(path) {
  let data;
  await env.withSecurityRulesDisabled(async (ctx) => {
    data = (await getDoc(doc(ctx.firestore(), path))).data();
  });
  return data;
}

const member = (name, hasApprovedExpense = false) => ({
  name,
  avatarUrl: '',
  joinedAt: Timestamp.now(),
  hasApprovedExpense,
});

async function seedGroup(overrides = {}) {
  await seed(`groups/${GID}`, {
    name: 'Cox\'s Bazar',
    adminId: 'alice',
    creatorId: 'alice',
    currency: 'BDT',
    currencySymbol: '৳',
    status: 'active',
    groupCode: CODE,
    groupCodeExpiresAt: Timestamp.fromMillis(Date.now() + HOUR),
    lastActivityAt: Timestamp.now(),
    createdAt: Timestamp.now(),
    inactivatedAt: null,
    inactivatedBy: null,
    members: { alice: member('Alice'), bob: member('Bob'), carol: member('Carol') },
    memberIds: ['alice', 'bob', 'carol'],
    ...overrides,
  });
  await seed(`groupCodes/${CODE}`, {
    groupId: GID,
    expiresAt: Timestamp.fromMillis(Date.now() + HOUR),
  });
}

const pendingExpense = (overrides = {}) => ({
  loggedBy: 'alice',
  loggedByName: 'Alice',
  amount: 90,
  comment: 'Dinner',
  location: null,
  splitType: 'equal',
  splits: {
    alice: { name: 'Alice', amount: 30 },
    bob: { name: 'Bob', amount: 30 },
    carol: { name: 'Carol', amount: 30 },
  },
  loggerIncluded: true,
  status: 'pending',
  createdAt: Timestamp.now(),
  approvedAt: null,
  approvals: { bob: 'pending', carol: 'pending' },
  rejectionReasons: {},
  ...overrides,
});

const debt = (expenseId, from, amount, overrides = {}) => ({
  fromUserId: from,
  fromUserName: from,
  toUserId: 'alice',
  toUserName: 'Alice',
  sourceExpenseId: expenseId,
  originalAmount: amount,
  remainingAmount: amount,
  status: 'active',
  createdAt: Timestamp.now(),
  settledAt: null,
  ...overrides,
});

const payment = (overrides = {}) => ({
  fromUserId: 'bob',
  fromUserName: 'Bob',
  toUserId: 'alice',
  toUserName: 'Alice',
  debtId: 'e1_bob',
  amount: 10,
  bkashNumber: null,
  status: 'pending',
  rejectionNote: null,
  loggedAt: Timestamp.now(),
  approvedAt: null,
  resubmittedAt: null,
  ...overrides,
});

const notification = (overrides = {}) => ({
  senderId: 'bob',
  targetUserId: 'alice',
  groupId: GID,
  groupName: 'Cox\'s Bazar',
  type: 'expense_pending_approval',
  referenceId: 'e1',
  message: 'Hello',
  isRead: false,
  createdAt: Timestamp.now(),
  ...overrides,
});

// ── Profile photos ────────────────────────────────────────────────────────────

describe('profile photos', () => {
  const photo = (size = 20000) => ({ data: 'A'.repeat(size), updatedAt: serverTimestamp() });

  test('you can set your own photo, even before verifying', async () => {
    await assertSucceeds(setDoc(doc(unverified('dave'), 'avatars/dave'), photo()));
    await assertSucceeds(setDoc(doc(as('bob'), 'avatars/bob'), photo()));
  });

  test('not someone else\'s, not a huge one, nothing extra', async () => {
    await assertFails(setDoc(doc(as('mallory'), 'avatars/bob'), photo()));
    await assertFails(setDoc(doc(as('bob'), 'avatars/bob'), photo(200000)));
    await assertFails(setDoc(doc(as('bob'), 'avatars/bob'), { ...photo(), secret: 'x' }));
  });

  test('verified users can see a photo; nobody can list them all', async () => {
    await seed('avatars/bob', { data: 'AAAA', updatedAt: Timestamp.now() });
    await assertSucceeds(getDoc(doc(as('carol'), 'avatars/bob')));
    await assertFails(getDoc(doc(unverified('dave'), 'avatars/bob')));
    await assertFails(getDocs(collection(as('carol'), 'avatars')));
  });
});

// ── Users ─────────────────────────────────────────────────────────────────────

describe('users', () => {
  test('anyone signed in can create their own profile, even before verifying', async () => {
    await assertSucceeds(setDoc(doc(unverified('dave'), 'users/dave'), { uid: 'dave', name: 'Dave' }));
  });

  test('a profile (and its bKash number) is private to its owner', async () => {
    await seed('users/carol', { uid: 'carol', name: 'Carol', bkashNumber: '01700000000' });
    await assertSucceeds(getDoc(doc(as('carol'), 'users/carol')));
    await assertFails(getDoc(doc(as('bob'), 'users/carol')));
  });

  test('nobody can edit someone else\'s profile', async () => {
    await seed('users/carol', { uid: 'carol', name: 'Carol', activeGroupId: GID });
    await assertFails(updateDoc(doc(as('alice'), 'users/carol'), { activeGroupId: null }));
    await assertSucceeds(updateDoc(doc(as('carol'), 'users/carol'), { activeGroupId: null }));
  });

  test('you can\'t create a profile for someone else', async () => {
    await assertFails(setDoc(doc(as('mallory'), 'users/bob'), { uid: 'bob', name: 'Bob' }));
  });
});

// ── Email verification ────────────────────────────────────────────────────────

describe('unverified accounts', () => {
  test('can\'t read or write tour data', async () => {
    await seedGroup({
      members: { alice: member('Alice'), dave: member('Dave') },
      memberIds: ['alice', 'dave'],
    });
    await assertFails(getDoc(doc(unverified('dave'), `groups/${GID}`)));
    await assertFails(setDoc(doc(unverified('dave'), `groups/${GID}/expenses/e9`), pendingExpense({
      loggedBy: 'dave',
      splits: { dave: { name: 'Dave', amount: 10 } },
      approvals: {},
      status: 'approved',
    })));
  });
});

// ── Groups ────────────────────────────────────────────────────────────────────

describe('reading groups', () => {
  test('members can read their group, outsiders can\'t', async () => {
    await assertSucceeds(getDoc(doc(as('bob'), `groups/${GID}`)));
    await assertFails(getDoc(doc(as('mallory'), `groups/${GID}`)));
  });

  test('tour history can only list your own groups', async () => {
    const mine = query(collection(as('bob'), 'groups'), where('memberIds', 'array-contains', 'bob'));
    await assertSucceeds(getDocs(mine));
    const everything = query(collection(as('bob'), 'groups'), where('status', '==', 'inactive'));
    await assertFails(getDocs(everything));
  });
});

describe('creating a group', () => {
  async function createGroup(db, { adminId = 'mallory', withCode = true, code = 'NEW234' } = {}) {
    const batch = writeBatch(db);
    batch.set(doc(db, 'groups/g2'), {
      name: 'New trip',
      adminId,
      creatorId: adminId,
      currency: 'BDT',
      currencySymbol: '৳',
      status: 'active',
      groupCode: code,
      groupCodeExpiresAt: Timestamp.fromMillis(Date.now() + HOUR),
      lastActivityAt: serverTimestamp(),
      createdAt: Timestamp.now(),
      inactivatedAt: null,
      inactivatedBy: null,
      members: { [adminId]: member('Me') },
      memberIds: [adminId],
    });
    if (withCode) {
      batch.set(doc(db, `groupCodes/${code}`), {
        groupId: 'g2',
        expiresAt: Timestamp.fromMillis(Date.now() + HOUR),
      });
    }
    return batch.commit();
  }

  test('you can create a group you administer, with its join code', async () => {
    await assertSucceeds(createGroup(as('mallory')));
  });

  test('you can\'t make someone else the admin', async () => {
    await assertFails(createGroup(as('mallory'), { adminId: 'bob' }));
  });

  test('the join code must be registered in the same write', async () => {
    await assertFails(createGroup(as('mallory'), { withCode: false }));
  });

  test('an existing join code can\'t be taken over', async () => {
    await assertFails(createGroup(as('mallory'), { code: CODE }));
  });
});

describe('join codes', () => {
  test('can be looked up one at a time but never listed', async () => {
    await assertSucceeds(getDoc(doc(as('mallory'), `groupCodes/${CODE}`)));
    await assertFails(getDocs(collection(as('mallory'), 'groupCodes')));
  });

  test('only the admin can register a new code for a group', async () => {
    const refresh = (uid) => {
      const db = as(uid);
      const batch = writeBatch(db);
      batch.delete(doc(db, `groupCodes/${CODE}`));
      batch.set(doc(db, 'groupCodes/XYZ789'), {
        groupId: GID,
        expiresAt: Timestamp.fromMillis(Date.now() + HOUR),
      });
      batch.update(doc(db, `groups/${GID}`), {
        groupCode: 'XYZ789',
        groupCodeExpiresAt: Timestamp.fromMillis(Date.now() + HOUR),
      });
      return batch.commit();
    };
    await assertFails(refresh('bob'));
    await assertSucceeds(refresh('alice'));
  });
});

describe('joining a group', () => {
  function join(uid, { code = CODE, extra = {} } = {}) {
    const db = as(uid);
    const batch = writeBatch(db);
    batch.update(doc(db, `groups/${GID}`), {
      [`members.${uid}`]: { ...member('Joiner'), joinCode: code },
      memberIds: arrayUnion(uid),
      lastActivityAt: serverTimestamp(),
      ...extra,
    });
    return batch.commit();
  }

  test('works with the current code', async () => {
    await assertSucceeds(join('mallory'));
    const group = await read(`groups/${GID}`);
    if (!group.memberIds.includes('mallory')) throw new Error('mallory was not added');
  });

  test('fails with the wrong code', async () => {
    await assertFails(join('mallory', { code: 'WRONG1' }));
  });

  test('fails once the code has expired', async () => {
    await seedGroup({ groupCodeExpiresAt: Timestamp.fromMillis(Date.now() - 1000) });
    await assertFails(join('mallory'));
  });

  test('fails for an ended tour', async () => {
    await seedGroup({ status: 'inactive' });
    await assertFails(join('mallory'));
  });

  test('you can only add yourself', async () => {
    const db = as('mallory');
    await assertFails(updateDoc(doc(db, `groups/${GID}`), {
      'members.eve': { ...member('Eve'), joinCode: CODE },
      memberIds: arrayUnion('eve'),
    }));
  });

  test('you can\'t join as someone with approved expenses (so you can\'t be removed)', async () => {
    const db = as('mallory');
    await assertFails(updateDoc(doc(db, `groups/${GID}`), {
      'members.mallory': { ...member('M', true), joinCode: CODE },
      memberIds: arrayUnion('mallory'),
    }));
  });

  test('you can\'t change anything else while joining', async () => {
    await assertFails(join('mallory', { extra: { adminId: 'mallory' } }));
  });
});

describe('member updates', () => {
  test('a member can record activity with the server clock', async () => {
    await assertSucceeds(updateDoc(doc(as('bob'), `groups/${GID}`), { lastActivityAt: serverTimestamp() }));
  });

  test('activity can\'t be backdated (that would end the tour early)', async () => {
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}`), {
      lastActivityAt: Timestamp.fromMillis(Date.now() - 10 * DAY),
    }));
  });

  test('a member can mark only their own approved-expense flag', async () => {
    await assertSucceeds(updateDoc(doc(as('bob'), `groups/${GID}`), { 'members.bob.hasApprovedExpense': true }));
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}`), { 'members.carol.hasApprovedExpense': true }));
  });

  test('members can\'t rename each other or change tour settings', async () => {
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}`), { 'members.carol.name': 'Rude' }));
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}`), { adminId: 'bob' }));
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}`), { name: 'Mine now' }));
  });

  test('outsiders can\'t write at all', async () => {
    await assertFails(updateDoc(doc(as('mallory'), `groups/${GID}`), { lastActivityAt: serverTimestamp() }));
  });

  test('groups can\'t be deleted', async () => {
    await assertFails(deleteDoc(doc(as('alice'), `groups/${GID}`)));
  });
});

describe('admin actions', () => {
  const remove = (uid, who) => updateDoc(doc(as(uid), `groups/${GID}`), {
    [`members.${who}`]: deleteField(),
    memberIds: arrayRemove(who),
  });

  test('the admin can remove a member with no approved expenses', async () => {
    await assertSucceeds(remove('alice', 'bob'));
  });

  test('a member can\'t remove anyone', async () => {
    await assertFails(remove('bob', 'carol'));
  });

  test('the admin can\'t remove someone with approved expenses...', async () => {
    await seedGroup({
      members: { alice: member('Alice'), bob: member('Bob', true), carol: member('Carol') },
    });
    await assertFails(remove('alice', 'bob'));
  });

  test('...unless they asked to leave', async () => {
    await seedGroup({
      members: { alice: member('Alice'), bob: member('Bob', true), carol: member('Carol') },
    });
    await seed(`groups/${GID}/leaveRequests/bob`, { memberId: 'bob', memberName: 'Bob', status: 'pending' });
    const db = as('alice');
    const batch = writeBatch(db);
    batch.update(doc(db, `groups/${GID}`), { 'members.bob': deleteField(), memberIds: arrayRemove('bob') });
    batch.delete(doc(db, `groups/${GID}/leaveRequests/bob`));
    await assertSucceeds(batch.commit());
  });

  test('admin can hand over to a member, not an outsider', async () => {
    await assertFails(updateDoc(doc(as('alice'), `groups/${GID}`), { adminId: 'mallory' }));
    await assertSucceeds(updateDoc(doc(as('alice'), `groups/${GID}`), { adminId: 'bob' }));
  });

  test('admin can end the tour; members can\'t end it as "admin"', async () => {
    const end = (uid) => updateDoc(doc(as(uid), `groups/${GID}`), {
      status: 'inactive',
      inactivatedAt: serverTimestamp(),
      inactivatedBy: 'admin',
    });
    await assertFails(end('bob'));
    await assertSucceeds(end('alice'));
  });
});

describe('auto-ending an idle tour', () => {
  const autoEnd = (uid) => updateDoc(doc(as(uid), `groups/${GID}`), {
    status: 'inactive',
    inactivatedAt: serverTimestamp(),
    inactivatedBy: 'system',
  });

  test('is refused while the tour has recent activity', async () => {
    await seedGroup({ lastActivityAt: Timestamp.fromMillis(Date.now() - 3 * DAY) });
    await assertFails(autoEnd('bob'));
  });

  test('is allowed for any member after 4 idle days', async () => {
    await seedGroup({ lastActivityAt: Timestamp.fromMillis(Date.now() - 5 * DAY) });
    await assertSucceeds(autoEnd('bob'));
  });

  test('isn\'t allowed for outsiders', async () => {
    await seedGroup({ lastActivityAt: Timestamp.fromMillis(Date.now() - 5 * DAY) });
    await assertFails(autoEnd('mallory'));
  });
});

describe('leaving an ended tour (hide from history)', () => {
  const leave = (uid) => updateDoc(doc(as(uid), `groups/${GID}`), {
    [`members.${uid}`]: deleteField(),
    memberIds: arrayRemove(uid),
  });

  test('works once the tour has ended', async () => {
    await seedGroup({ status: 'inactive' });
    await assertSucceeds(leave('bob'));
  });

  test('isn\'t a way to leave an active tour', async () => {
    await assertFails(leave('bob'));
  });
});

describe('older groups without memberIds', () => {
  test('any member can fill it in correctly', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), `groups/${GID}`), { memberIds: deleteField() }));
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}`), { memberIds: ['bob'] }));
    await assertSucceeds(updateDoc(doc(as('bob'), `groups/${GID}`), { memberIds: ['alice', 'bob', 'carol'] }));
  });
});

// ── Expenses ──────────────────────────────────────────────────────────────────

describe('logging expenses', () => {
  test('a member can log a split expense waiting for the others', async () => {
    await assertSucceeds(setDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), pendingExpense()));
  });

  test('a solo expense is approved straight away', async () => {
    await assertSucceeds(setDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), pendingExpense({
      splits: { alice: { name: 'Alice', amount: 90 } },
      approvals: {},
      status: 'approved',
    })));
  });

  test('a split expense can\'t skip the others\' approval', async () => {
    await assertFails(setDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), pendingExpense({
      status: 'approved',
      approvals: { bob: 'approved', carol: 'approved' },
    })));
    await assertFails(setDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), pendingExpense({
      approvals: { bob: 'approved', carol: 'pending' },
    })));
    await assertFails(setDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), pendingExpense({
      approvals: { bob: 'pending' },
    })));
  });

  test('the shares have to add up to the total', async () => {
    await assertFails(setDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), pendingExpense({
      splits: {
        alice: { name: 'Alice', amount: 30 },
        bob: { name: 'Bob', amount: 30 },
        carol: { name: 'Carol', amount: 20 },
      },
    })));
    await assertFails(setDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), pendingExpense({ amount: 120 })));
    // an uneven split in whole cents is fine
    await assertSucceeds(setDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), pendingExpense({
      amount: 100,
      splits: {
        alice: { name: 'Alice', amount: 33.34 },
        bob: { name: 'Bob', amount: 33.33 },
        carol: { name: 'Carol', amount: 33.33 },
      },
    })));
  });

  test('an expense can be split between up to 50 people', async () => {
    const ids = ['alice', ...Array.from({ length: 50 }, (_, i) => `m${i}`)];
    await seedGroup({
      members: Object.fromEntries(ids.map((id) => [id, member(id)])),
      memberIds: ids,
    });
    const split = (people) => pendingExpense({
      amount: people.length,
      splits: Object.fromEntries(people.map((id) => [id, { name: id, amount: 1 }])),
      approvals: Object.fromEntries(people.filter((id) => id !== 'alice').map((id) => [id, 'pending'])),
    });
    await assertSucceeds(setDoc(doc(as('alice'), `groups/${GID}/expenses/e50`), split(ids.slice(0, 50))));
    await assertFails(setDoc(doc(as('alice'), `groups/${GID}/expenses/e51`), split(ids)));
  });

  test('you can\'t log in someone else\'s name', async () => {
    await assertFails(setDoc(doc(as('bob'), `groups/${GID}/expenses/e1`), pendingExpense()));
  });

  test('you can\'t charge people outside the tour', async () => {
    await assertFails(setDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), pendingExpense({
      splits: { alice: { name: 'A', amount: 45 }, mallory: { name: 'M', amount: 45 } },
      approvals: { mallory: 'pending' },
    })));
  });

  test('outsiders can\'t log or read expenses', async () => {
    await assertFails(setDoc(doc(as('mallory'), `groups/${GID}/expenses/e1`), pendingExpense({ loggedBy: 'mallory' })));
    await seed(`groups/${GID}/expenses/e1`, pendingExpense());
    await assertFails(getDoc(doc(as('mallory'), `groups/${GID}/expenses/e1`)));
  });

  test('nothing can be logged once a tour has ended', async () => {
    await seedGroup({ status: 'inactive' });
    await assertFails(setDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), pendingExpense()));
  });
});

describe('approving expenses', () => {
  beforeEach(async () => {
    await seed(`groups/${GID}/expenses/e1`, pendingExpense());
  });

  test('you can approve your own share', async () => {
    await assertSucceeds(updateDoc(doc(as('bob'), `groups/${GID}/expenses/e1`), { 'approvals.bob': 'approved' }));
  });

  test('you can\'t approve for someone else, and the logger can\'t approve for anyone', async () => {
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}/expenses/e1`), { 'approvals.carol': 'approved' }));
    await assertFails(updateDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), { 'approvals.bob': 'approved' }));
  });

  test('you can\'t change your share while approving', async () => {
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}/expenses/e1`), {
      'approvals.bob': 'approved',
      'splits.bob.amount': 1,
    }));
  });

  function finalise(uid, { createOwnDebt = true, debts = ['bob', 'carol'] } = {}) {
    const db = as(uid);
    const batch = writeBatch(db);
    batch.update(doc(db, `groups/${GID}/expenses/e1`), {
      [`approvals.${uid}`]: 'approved',
      status: 'approved',
      approvedAt: Timestamp.now(),
    });
    for (const who of debts) {
      if (who === uid && !createOwnDebt) continue;
      batch.set(doc(db, `groups/${GID}/debts/e1_${who}`), debt('e1', who, 30));
    }
    return batch.commit();
  }

  test('the last approval finalises the expense and creates the debts', async () => {
    await seed(`groups/${GID}/expenses/e1`, pendingExpense({ approvals: { bob: 'approved', carol: 'pending' } }));
    await assertSucceeds(finalise('carol'));
  });

  test('finalising must create your own debt', async () => {
    await seed(`groups/${GID}/expenses/e1`, pendingExpense({ approvals: { bob: 'approved', carol: 'pending' } }));
    await assertFails(finalise('carol', { createOwnDebt: false }));
  });

  test('you can\'t finalise while someone else hasn\'t approved', async () => {
    await assertFails(finalise('carol'));
  });

  test('you can reject your own share with a reason', async () => {
    await assertSucceeds(updateDoc(doc(as('bob'), `groups/${GID}/expenses/e1`), {
      'approvals.bob': 'rejected',
      'rejectionReasons.bob': 'Wrong amount',
    }));
  });

  test('you can\'t reject for someone else', async () => {
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}/expenses/e1`), {
      'approvals.carol': 'rejected',
    }));
  });

  test('the logger can finish an expense everyone already approved (offline approvals), others can\'t', async () => {
    await seed(`groups/${GID}/expenses/e1`, pendingExpense({ approvals: { bob: 'approved', carol: 'approved' } }));
    const finish = { status: 'approved', approvedAt: Timestamp.now() };
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}/expenses/e1`), finish));
    await assertSucceeds(updateDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), finish));
  });

  test('...but not while someone still has to approve', async () => {
    await seed(`groups/${GID}/expenses/e1`, pendingExpense({ approvals: { bob: 'approved', carol: 'pending' } }));
    await assertFails(updateDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), { status: 'approved', approvedAt: Timestamp.now() }));
  });

  test('a finalised expense can\'t be changed', async () => {
    await seed(`groups/${GID}/expenses/e1`, pendingExpense({
      status: 'approved',
      approvals: { bob: 'approved', carol: 'approved' },
    }));
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}/expenses/e1`), { 'approvals.bob': 'rejected' }));
  });
});

describe('the logger asking again', () => {
  beforeEach(async () => {
    await seed(`groups/${GID}/expenses/e1`, pendingExpense({
      approvals: { bob: 'rejected', carol: 'approved' },
      rejectionReasons: { bob: 'Too much' },
    }));
  });

  test('can reset one member to pending', async () => {
    await assertSucceeds(updateDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), {
      'approvals.bob': 'pending',
      'rejectionReasons.bob': deleteField(),
      requestedAgainFor: 'bob',
    }));
  });

  test('can\'t mark anyone approved', async () => {
    await assertFails(updateDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), {
      'approvals.bob': 'approved',
      requestedAgainFor: 'bob',
    }));
  });

  test('can change the share of the member being asked again', async () => {
    await assertSucceeds(updateDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), {
      'splits.bob': { name: 'Bob', amount: 20 },
      'splits.alice': { name: 'Alice', amount: 40 },
      'approvals.bob': 'pending',
      'rejectionReasons.bob': deleteField(),
      requestedAgainFor: 'bob',
    }));
  });

  test('can\'t change a share without the logger\'s share making up the difference', async () => {
    await assertFails(updateDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), {
      'splits.bob': { name: 'Bob', amount: 20 },
      'approvals.bob': 'pending',
      'rejectionReasons.bob': deleteField(),
      requestedAgainFor: 'bob',
    }));
  });

  test('can\'t quietly change the share of someone who already approved', async () => {
    await assertFails(updateDoc(doc(as('alice'), `groups/${GID}/expenses/e1`), {
      'splits.bob': { name: 'Bob', amount: 20 },
      'splits.carol': { name: 'Carol', amount: 50 },
      'approvals.bob': 'pending',
      requestedAgainFor: 'bob',
    }));
  });

  test('other members can\'t do it', async () => {
    await assertFails(updateDoc(doc(as('carol'), `groups/${GID}/expenses/e1`), {
      'approvals.bob': 'pending',
      requestedAgainFor: 'bob',
    }));
  });
});

describe('deleting expenses', () => {
  test('only the admin can delete, together with untouched debts', async () => {
    await seed(`groups/${GID}/expenses/e1`, pendingExpense({ status: 'approved' }));
    await seed(`groups/${GID}/debts/e1_bob`, debt('e1', 'bob', 30));
    const del = (uid) => {
      const db = as(uid);
      const batch = writeBatch(db);
      batch.delete(doc(db, `groups/${GID}/expenses/e1`));
      batch.delete(doc(db, `groups/${GID}/debts/e1_bob`));
      return batch.commit();
    };
    await assertFails(del('bob'));
    await assertSucceeds(del('alice'));
  });

  test('a partly paid debt can\'t be deleted', async () => {
    await seed(`groups/${GID}/expenses/e1`, pendingExpense({ status: 'approved' }));
    await seed(`groups/${GID}/debts/e1_bob`, debt('e1', 'bob', 30, { remainingAmount: 10 }));
    const db = as('alice');
    const batch = writeBatch(db);
    batch.delete(doc(db, `groups/${GID}/expenses/e1`));
    batch.delete(doc(db, `groups/${GID}/debts/e1_bob`));
    await assertFails(batch.commit());
  });
});

// ── Debts ─────────────────────────────────────────────────────────────────────

describe('debts', () => {
  test('can\'t be made up outside finalising an expense', async () => {
    await seed(`groups/${GID}/expenses/e1`, pendingExpense({
      status: 'approved',
      approvals: { bob: 'approved', carol: 'approved' },
    }));
    await assertFails(setDoc(doc(as('alice'), `groups/${GID}/debts/e1_bob`), debt('e1', 'bob', 30)));
    await assertFails(setDoc(doc(as('alice'), `groups/${GID}/debts/fake_bob`), debt('fake', 'bob', 500)));
  });

  test('must match the member\'s share', async () => {
    await seed(`groups/${GID}/expenses/e1`, pendingExpense({ approvals: { bob: 'approved', carol: 'pending' } }));
    const db = as('carol');
    const batch = writeBatch(db);
    batch.update(doc(db, `groups/${GID}/expenses/e1`), {
      'approvals.carol': 'approved',
      status: 'approved',
      approvedAt: Timestamp.now(),
    });
    batch.set(doc(db, `groups/${GID}/debts/e1_carol`), debt('e1', 'carol', 30));
    batch.set(doc(db, `groups/${GID}/debts/e1_bob`), debt('e1', 'bob', 300));
    await assertFails(batch.commit());
  });

  test('the debtor can\'t reduce or settle their own debt', async () => {
    await seed(`groups/${GID}/debts/e1_bob`, debt('e1', 'bob', 30));
    await assertFails(updateDoc(doc(as('bob'), `groups/${GID}/debts/e1_bob`), {
      remainingAmount: 0,
      status: 'settled',
    }));
  });

  test('the person owed can reduce it, but never raise it', async () => {
    await seed(`groups/${GID}/debts/e1_bob`, debt('e1', 'bob', 30));
    await assertFails(updateDoc(doc(as('alice'), `groups/${GID}/debts/e1_bob`), { remainingAmount: 300 }));
    await assertSucceeds(updateDoc(doc(as('alice'), `groups/${GID}/debts/e1_bob`), { remainingAmount: 10 }));
  });

  test('outsiders can\'t read debts', async () => {
    await seed(`groups/${GID}/debts/e1_bob`, debt('e1', 'bob', 30));
    await assertFails(getDoc(doc(as('mallory'), `groups/${GID}/debts/e1_bob`)));
  });
});

// ── Payments ──────────────────────────────────────────────────────────────────

describe('payments', () => {
  beforeEach(async () => {
    await seed(`groups/${GID}/debts/e1_bob`, debt('e1', 'bob', 30));
  });

  test('you can log a payment against your own debt', async () => {
    await assertSucceeds(setDoc(doc(as('bob'), `groups/${GID}/payments/p1`), payment()));
  });

  test('not more than is owed', async () => {
    await assertFails(setDoc(doc(as('bob'), `groups/${GID}/payments/p1`), payment({ amount: 31 })));
  });

  test('not against someone else\'s debt, or to the wrong person', async () => {
    await assertFails(setDoc(doc(as('carol'), `groups/${GID}/payments/p1`), payment({ fromUserId: 'carol' })));
    await assertFails(setDoc(doc(as('bob'), `groups/${GID}/payments/p1`), payment({ toUserId: 'carol' })));
  });

  test('a payment can\'t be logged as already approved', async () => {
    await assertFails(setDoc(doc(as('bob'), `groups/${GID}/payments/p1`), payment({ status: 'approved' })));
  });

  function approve(uid, newRemaining) {
    const db = as(uid);
    const batch = writeBatch(db);
    batch.update(doc(db, `groups/${GID}/payments/p1`), { status: 'approved', approvedAt: Timestamp.now() });
    if (newRemaining !== undefined) {
      batch.update(doc(db, `groups/${GID}/debts/e1_bob`), { remainingAmount: newRemaining });
    }
    return batch.commit();
  }

  test('the person paid confirms it and the debt drops by the payment', async () => {
    await seed(`groups/${GID}/payments/p1`, payment());
    await assertSucceeds(approve('alice', 20));
  });

  test('confirming must reduce the debt by exactly the payment', async () => {
    await seed(`groups/${GID}/payments/p1`, payment());
    await assertFails(approve('alice'));
    await assertFails(approve('alice', 25));
  });

  test('the payer can\'t confirm their own payment', async () => {
    await seed(`groups/${GID}/payments/p1`, payment());
    await assertFails(approve('bob', 20));
  });

  test('a payment can only be decided once', async () => {
    await seed(`groups/${GID}/payments/p1`, payment({ status: 'approved' }));
    await assertFails(approve('alice', 20));
  });

  test('the person paid can reject it', async () => {
    await seed(`groups/${GID}/payments/p1`, payment());
    await assertSucceeds(updateDoc(doc(as('alice'), `groups/${GID}/payments/p1`), {
      status: 'rejected',
      rejectionNote: 'Not received',
    }));
  });
});

// ── Leave requests ────────────────────────────────────────────────────────────

describe('leave requests', () => {
  test('you can ask to leave for yourself only', async () => {
    const ask = (uid, who) => setDoc(doc(as(uid), `groups/${GID}/leaveRequests/${who}`), {
      memberId: who,
      memberName: who,
      status: 'pending',
      requestedAt: Timestamp.now(),
    });
    await assertSucceeds(ask('bob', 'bob'));
    await assertFails(ask('bob', 'carol'));
    await assertFails(ask('mallory', 'mallory'));
  });

  test('only the admin can see the list', async () => {
    const pending = (uid) => getDocs(query(
      collection(as(uid), `groups/${GID}/leaveRequests`),
      where('status', '==', 'pending'),
    ));
    await assertSucceeds(pending('alice'));
    await assertFails(pending('bob'));
  });
});

// ── Notifications ─────────────────────────────────────────────────────────────

describe('notifications', () => {
  test('you can notify someone in your tour', async () => {
    await assertSucceeds(setDoc(doc(as('bob'), 'notifications/n1'), notification()));
  });

  test('you can\'t notify strangers, or send from outside the tour', async () => {
    await assertFails(setDoc(doc(as('bob'), 'notifications/n1'), notification({ targetUserId: 'mallory' })));
    await assertFails(setDoc(doc(as('mallory'), 'notifications/n1'), notification({ senderId: 'mallory' })));
  });

  test('you can\'t pretend to be someone else', async () => {
    await assertFails(setDoc(doc(as('bob'), 'notifications/n1'), notification({ senderId: 'alice' })));
  });

  test('the admin can tell someone their leave was approved after removing them', async () => {
    await seedGroup({ members: { alice: member('Alice'), carol: member('Carol') }, memberIds: ['alice', 'carol'] });
    await assertSucceeds(setDoc(doc(as('alice'), 'notifications/n1'), notification({
      senderId: 'alice',
      targetUserId: 'bob',
    })));
  });

  test('you can only read and mark your own', async () => {
    await seed('notifications/n1', notification());
    await assertSucceeds(getDocs(query(collection(as('alice'), 'notifications'), where('targetUserId', '==', 'alice'))));
    await assertFails(getDoc(doc(as('bob'), 'notifications/n1')));
    await assertSucceeds(updateDoc(doc(as('alice'), 'notifications/n1'), { isRead: true }));
    await assertFails(updateDoc(doc(as('alice'), 'notifications/n1'), { message: 'edited' }));
    await assertFails(updateDoc(doc(as('bob'), 'notifications/n1'), { isRead: true }));
  });
});

// ── bKash requests ────────────────────────────────────────────────────────────

describe('bKash number requests', () => {
  const REQ = `${GID}_bob_carol`;
  const request = (overrides = {}) => ({
    groupId: GID,
    requesterId: 'bob',
    requesterName: 'Bob',
    targetId: 'carol',
    targetName: 'Carol',
    status: 'pending',
    createdAt: Timestamp.now(),
    ...overrides,
  });

  test('a member can ask another member', async () => {
    await assertSucceeds(setDoc(doc(as('bob'), `bkashRequests/${REQ}`), request()));
  });

  test('the request can\'t carry a number or claim to be accepted', async () => {
    await assertFails(setDoc(doc(as('bob'), `bkashRequests/${REQ}`), request({ status: 'accepted' })));
    await assertFails(setDoc(doc(as('bob'), `bkashRequests/${REQ}`), request({ number: '017' })));
  });

  test('outsiders can\'t ask, and nobody can ask in someone else\'s name', async () => {
    await assertFails(setDoc(doc(as('mallory'), `bkashRequests/${GID}_mallory_carol`), request({ requesterId: 'mallory' })));
    await assertFails(setDoc(doc(as('alice'), `bkashRequests/${REQ}`), request()));
  });

  test('only the person asked can accept, which shares their number', async () => {
    await seed(`bkashRequests/${REQ}`, request());
    await assertFails(updateDoc(doc(as('bob'), `bkashRequests/${REQ}`), { status: 'accepted', number: '01700000000' }));
    await assertSucceeds(updateDoc(doc(as('carol'), `bkashRequests/${REQ}`), { status: 'accepted', number: '01700000000' }));
  });

  test('only the two people involved can read it', async () => {
    await seed(`bkashRequests/${REQ}`, request({ status: 'accepted', number: '01700000000' }));
    await assertSucceeds(getDoc(doc(as('bob'), `bkashRequests/${REQ}`)));
    await assertSucceeds(getDoc(doc(as('carol'), `bkashRequests/${REQ}`)));
    await assertFails(getDoc(doc(as('alice'), `bkashRequests/${REQ}`)));
  });

  test('the person asked can update the number they shared', async () => {
    await seed(`bkashRequests/${REQ}`, request({ status: 'accepted', number: '01700000000' }));
    const mine = query(
      collection(as('carol'), 'bkashRequests'),
      where('targetId', '==', 'carol'),
      where('status', '==', 'accepted'),
    );
    await assertSucceeds(getDocs(mine));
    await assertSucceeds(updateDoc(doc(as('carol'), `bkashRequests/${REQ}`), { number: '01800000000' }));
  });
});
