// Fills the LOCAL Firebase emulators with a demo tour, for trying the app
// (and its security rules) without touching the real project.
//
//   firebase emulators:start --only auth,firestore,storage --project demo-taka-koi
//   node seed_emulator.mjs
//   flutter run --dart-define=USE_EMULATORS=true      (or build web with it)
//
// Sign in as any demo member below with DEMO_PASSWORD. These accounts exist
// only in the emulator.

process.env.FIRESTORE_EMULATOR_HOST ??= 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= 'localhost:9099';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

export const DEMO_PASSWORD = 'demo-pass-2468';

const app = initializeApp({ projectId: 'demo-taka-koi' });
const auth = getAuth(app);
const db = getFirestore(app);

const HOUR = 3600 * 1000;
const DAY = 24 * HOUR;
const now = Date.now();
const ts = (msAgo) => Timestamp.fromMillis(now - msAgo);

const people = {
  nafis: { name: 'Nafis Rahman', email: 'nafis@taka.test', bkash: '01811111111' },
  tasnim: { name: 'Tasnim Akter', email: 'tasnim@taka.test', bkash: '01712345678' },
  rafi: { name: 'Rafi Hasan', email: 'rafi@taka.test', bkash: null },
  anika: { name: 'Anika Chowdhury', email: 'anika@taka.test', bkash: '01999999999' },
};
const ids = Object.keys(people);
const first = (uid) => people[uid].name.split(' ')[0];

const GID = 'g-coxs';
const OLD = 'g-sylhet';
const CODE = 'TK7Q2M';

async function seedUsers() {
  for (const [uid, p] of Object.entries(people)) {
    try { await auth.deleteUser(uid); } catch { /* first run */ }
    await auth.createUser({ uid, email: p.email, password: DEMO_PASSWORD, displayName: p.name, emailVerified: true });
    await db.doc(`users/${uid}`).set({
      uid, name: p.name, email: p.email, avatarUrl: '', bkashNumber: p.bkash,
      activeGroupId: GID, createdAt: ts(30 * DAY),
    });
  }
}

const member = (uid, joinedAgo, approved = true) => ({
  name: people[uid].name, avatarUrl: '', joinedAt: ts(joinedAgo), hasApprovedExpense: approved,
});

function expense({ by, amount, comment, splits, ago, status = 'approved', approvals = {}, address, splitType = 'equal' }) {
  const entries = Object.fromEntries(Object.entries(splits).map(([uid, amt]) => [uid, { name: people[uid].name, amount: amt }]));
  return {
    loggedBy: by, loggedByName: people[by].name, amount, comment,
    location: address ? { latitude: 21.4272, longitude: 92.0058, address } : null,
    splitType, splits: entries, loggerIncluded: by in splits, status,
    createdAt: ts(ago), approvedAt: status === 'approved' ? ts(ago - HOUR) : null,
    approvals, rejectionReasons: {},
  };
}

async function seedActiveTour() {
  const batch = db.batch();
  const g = db.doc(`groups/${GID}`);
  batch.set(g, {
    name: 'Cox\'s Bazar Getaway', adminId: 'nafis', creatorId: 'nafis', currency: 'BDT', currencySymbol: '৳',
    status: 'active', groupCode: CODE, groupCodeExpiresAt: Timestamp.fromMillis(now + HOUR),
    lastActivityAt: ts(2 * HOUR), createdAt: ts(3 * DAY), inactivatedAt: null, inactivatedBy: null,
    members: { nafis: member('nafis', 3 * DAY), tasnim: member('tasnim', 3 * DAY), rafi: member('rafi', 3 * DAY), anika: member('anika', 2 * DAY) },
    memberIds: ids,
  });
  batch.set(db.doc(`groupCodes/${CODE}`), { groupId: GID, expiresAt: Timestamp.fromMillis(now + HOUR) });

  const ex = {
    bus: expense({ by: 'nafis', amount: 3200, comment: 'Green Line bus tickets', ago: 3 * DAY, address: 'Arambagh, Dhaka',
      splits: { nafis: 800, tasnim: 800, rafi: 800, anika: 800 } }),
    hotel: expense({ by: 'tasnim', amount: 12000, comment: 'Sea Pearl resort, 2 nights', ago: 2 * DAY + 5 * HOUR, address: 'Kolatoli Rd, Cox\'s Bazar',
      splits: { nafis: 3000, tasnim: 3000, rafi: 3000, anika: 3000 } }),
    dinner: expense({ by: 'rafi', amount: 2840, comment: 'Seafood dinner at Poushee', ago: 2 * DAY, splitType: 'custom', address: 'Sugandha Point, Cox\'s Bazar',
      splits: { nafis: 760, tasnim: 640, rafi: 720, anika: 720 } }),
    tuktuk: expense({ by: 'nafis', amount: 600, comment: 'Tuk-tuk to Himchari', ago: DAY + 3 * HOUR, address: 'Marine Drive, Cox\'s Bazar',
      splits: { nafis: 300, anika: 300 } }),
    kayak: expense({ by: 'tasnim', amount: 1800, comment: 'Kayaking at Inani', ago: 5 * HOUR, status: 'pending', address: 'Inani Beach',
      splits: { tasnim: 600, nafis: 600, rafi: 600 }, approvals: { nafis: 'pending', rafi: 'approved' } }),
    snacks: expense({ by: 'nafis', amount: 450, comment: 'Coconuts and jhalmuri', ago: 2 * HOUR, status: 'pending', address: 'Laboni Beach',
      splits: { nafis: 225, anika: 225 }, approvals: { anika: 'pending' } }),
  };
  for (const [id, data] of Object.entries(ex)) batch.set(db.doc(`groups/${GID}/expenses/${id}`), data);

  // A debt for every non-payer share of every approved expense.
  for (const [id, data] of Object.entries(ex)) {
    if (data.status !== 'approved') continue;
    for (const [uid, s] of Object.entries(data.splits)) {
      if (uid === data.loggedBy) continue;
      const settled = id === 'bus' && uid === 'rafi';
      batch.set(db.doc(`groups/${GID}/debts/${id}_${uid}`), {
        fromUserId: uid, fromUserName: people[uid].name, toUserId: data.loggedBy, toUserName: data.loggedByName,
        sourceExpenseId: id, originalAmount: s.amount, remainingAmount: settled ? 0 : s.amount,
        status: settled ? 'settled' : 'active', createdAt: data.approvedAt, settledAt: settled ? ts(DAY) : null,
      });
    }
  }

  const pay = (id, from, to, debtId, amount, status, ago) => batch.set(db.doc(`groups/${GID}/payments/${id}`), {
    fromUserId: from, fromUserName: people[from].name, toUserId: to, toUserName: people[to].name, debtId, amount,
    bkashNumber: null, status, rejectionNote: null, loggedAt: ts(ago), approvedAt: status === 'approved' ? ts(ago - HOUR) : null, resubmittedAt: null,
  });
  pay('p1', 'rafi', 'nafis', 'bus_rafi', 800, 'approved', DAY + 2 * HOUR);
  pay('p2', 'anika', 'nafis', 'bus_anika', 500, 'pending', 3 * HOUR);
  pay('p3', 'nafis', 'tasnim', 'hotel_nafis', 1000, 'pending', 4 * HOUR);

  const notif = (id, from, to, type, ref, message, ago, isRead = false) => batch.set(db.doc(`notifications/${id}`), {
    senderId: from, targetUserId: to, groupId: GID, groupName: 'Cox\'s Bazar Getaway', type, referenceId: ref, message, isRead, createdAt: ts(ago),
  });
  notif('n1', 'tasnim', 'nafis', 'expense_pending_approval', 'kayak', 'Tasnim Akter wants to split an expense of ৳600.00 with you. Tap to approve or reject.', 5 * HOUR);
  notif('n2', 'anika', 'nafis', 'payment_pending', 'p2', 'Anika Chowdhury has logged a payment of ৳500.00 to you. Please review.', 3 * HOUR);
  notif('n3', 'rafi', 'nafis', 'bkash_requested', 'rafi', 'Rafi Hasan is requesting your bKash number', 90 * 60 * 1000);
  notif('n4', 'tasnim', 'nafis', 'bkash_accepted', 'tasnim', 'Tasnim Akter shared their bKash number with you', DAY, true);
  notif('n5', 'rafi', 'nafis', 'payment_approved', 'p1', 'Rafi Hasan logged ৳800.00 and you confirmed it.', DAY + HOUR, true);

  batch.set(db.doc(`bkashRequests/${GID}_rafi_nafis`), {
    groupId: GID, requesterId: 'rafi', requesterName: people.rafi.name, targetId: 'nafis', targetName: people.nafis.name,
    status: 'pending', createdAt: ts(90 * 60 * 1000),
  });
  batch.set(db.doc(`bkashRequests/${GID}_nafis_tasnim`), {
    groupId: GID, requesterId: 'nafis', requesterName: people.nafis.name, targetId: 'tasnim', targetName: people.tasnim.name,
    status: 'accepted', number: people.tasnim.bkash, createdAt: ts(2 * DAY), respondedAt: ts(DAY),
  });
  await batch.commit();
}

async function seedPastTour() {
  const batch = db.batch();
  batch.set(db.doc(`groups/${OLD}`), {
    name: 'Sylhet Tea Trail', adminId: 'tasnim', creatorId: 'tasnim', currency: 'BDT', currencySymbol: '৳',
    status: 'inactive', groupCode: 'SY3T8A', groupCodeExpiresAt: ts(60 * DAY),
    lastActivityAt: ts(55 * DAY), createdAt: ts(62 * DAY), inactivatedAt: ts(54 * DAY), inactivatedBy: 'admin',
    members: { tasnim: member('tasnim', 62 * DAY), nafis: member('nafis', 62 * DAY), rafi: member('rafi', 61 * DAY) },
    memberIds: ['tasnim', 'nafis', 'rafi'],
  });
  const e = (id, by, amount, comment, splits, ago) => batch.set(db.doc(`groups/${OLD}/expenses/${id}`),
    expense({ by, amount, comment, splits, ago, address: 'Sreemangal, Sylhet' }));
  e('train', 'tasnim', 2100, 'Parabat Express tickets', { tasnim: 700, nafis: 700, rafi: 700 }, 61 * DAY);
  e('cottage', 'nafis', 7500, 'Tea-garden cottage', { tasnim: 2500, nafis: 2500, rafi: 2500 }, 60 * DAY);
  e('jeep', 'rafi', 1500, 'Jeep to Lawachara', { tasnim: 500, nafis: 500, rafi: 500 }, 59 * DAY);
  await batch.commit();
}

await seedUsers();
await seedActiveTour();
await seedPastTour();
console.log(`Seeded the emulators. Sign in as ${Object.values(people).map((p) => p.email).join(', ')} with the DEMO_PASSWORD in this file.`);
process.exit(0);
