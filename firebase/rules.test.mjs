// Security rules tests. Run with: cd firebase && npm install && npm test
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, getDocs, collection, Timestamp } from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { test, before, after, beforeEach } from 'node:test';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-productivity-go',
    firestore: { rules: readFileSync(new URL('./firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const row = (uid, day, minutes = 50) => ({ uid, day, minutes, sessions: 2, streak: 3, rank: 1 });

// Seeds accepted friendship asha <-> ben through the rules-free path.
async function friendsAB() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/asha/links/ben'), { state: 'accepted', name: 'Ben' });
    await setDoc(doc(db, 'users/ben/links/asha'), { state: 'accepted', name: 'Asha' });
  });
}
async function seedDay(uid, day, minutes) {
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), `users/${uid}/days/${day}`), row(uid, day, minutes)));
}

test('signed-out users can do nothing', async () => {
  await assertFails(getDoc(doc(anon(), 'users/asha')));
  await assertFails(setDoc(doc(anon(), 'users/asha'), { name: 'A', code: 'ABCDEFGH' }));
  await assertFails(getDoc(doc(anon(), 'codes/ABCDEFGH')));
});

test('unknown paths are closed', async () => {
  await assertFails(setDoc(doc(as('asha'), 'anything/else'), { a: 1 }));
  await assertFails(getDoc(doc(as('asha'), 'anything/else')));
});

test('profile: owner writes it, strangers cannot read it, friends can', async () => {
  const a = as('asha');
  await assertSucceeds(setDoc(doc(a, 'users/asha'), { name: 'Asha', code: 'ABCDEFGH' }));
  await assertFails(setDoc(doc(as('ben'), 'users/asha'), { name: 'Evil', code: 'ABCDEFGH' }));
  await assertFails(getDoc(doc(as('ben'), 'users/asha')));
  await friendsAB();
  await assertSucceeds(getDoc(doc(as('ben'), 'users/asha')));
  await assertFails(setDoc(doc(a, 'users/asha'), { name: 'Asha', code: 'ABCDEFGH', email: 'a@b.c' }), 'no extra fields');
  await assertFails(setDoc(doc(a, 'users/asha'), { name: '', code: 'ABCDEFGH' }));
  await assertFails(setDoc(doc(a, 'users/asha'), { name: 'Asha', code: 'SHORT' }));
});

test('codes can be read one at a time but never listed, and cannot be stolen', async () => {
  await assertSucceeds(setDoc(doc(as('asha'), 'codes/ABCDEFGH'), { uid: 'asha' }));
  await assertSucceeds(getDoc(doc(as('ben'), 'codes/ABCDEFGH')));
  await assertFails(getDocs(collection(as('ben'), 'codes')));
  await assertFails(setDoc(doc(as('ben'), 'codes/ABCDEFGH'), { uid: 'ben' }), 'cannot overwrite');
  await assertFails(setDoc(doc(as('ben'), 'codes/ZZZZZZZZ'), { uid: 'asha' }), 'cannot claim for someone else');
  await assertFails(deleteDoc(doc(as('ben'), 'codes/ABCDEFGH')));
  await assertSucceeds(deleteDoc(doc(as('asha'), 'codes/ABCDEFGH')));
});

test('friend request: ask, accept, and the asker completes their side', async () => {
  const a = as('asha'), b = as('ben');
  await assertSucceeds(setDoc(doc(a, 'users/asha/links/ben'), { state: 'requested', name: 'Ben' }));
  await assertSucceeds(setDoc(doc(a, 'users/ben/links/asha'), { state: 'pending', name: 'Asha' }));
  await assertFails(getDoc(doc(a, 'users/ben/links/asha')), 'cannot read the other side');
  await assertSucceeds(getDoc(doc(b, 'users/ben/links/asha')));
  // Asha cannot accept on Ben's behalf, and cannot complete her side before Ben accepts.
  await assertFails(updateDoc(doc(a, 'users/ben/links/asha'), { state: 'accepted' }));
  await assertFails(updateDoc(doc(a, 'users/asha/links/ben'), { state: 'accepted' }));
  await assertSucceeds(updateDoc(doc(b, 'users/ben/links/asha'), { state: 'accepted' }));
  await assertSucceeds(updateDoc(doc(a, 'users/asha/links/ben'), { state: 'accepted' }));
});

test('a pending request cannot overwrite an existing link or a block', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'users/ben/links/asha'), { state: 'blocked', name: 'Asha' }));
  await assertFails(setDoc(doc(as('asha'), 'users/ben/links/asha'), { state: 'pending', name: 'Asha' }));
  await assertFails(setDoc(doc(as('asha'), 'users/asha/links/ben'), { state: 'requested', name: 'Ben' }), 'blocked people cannot ask');
});

test('nobody can forge an accepted link for themselves', async () => {
  await assertFails(setDoc(doc(as('asha'), 'users/asha/links/ben'), { state: 'accepted', name: 'Ben' }));
  await assertFails(setDoc(doc(as('asha'), 'users/ben/links/asha'), { state: 'accepted', name: 'Asha' }));
});

test('mute, block and unfriend', async () => {
  await friendsAB();
  await assertSucceeds(updateDoc(doc(as('ben'), 'users/ben/links/asha'), { state: 'muted' }));
  await assertSucceeds(getDoc(doc(as('asha'), 'users/ben')).catch(() => null));
  await assertSucceeds(updateDoc(doc(as('ben'), 'users/ben/links/asha'), { state: 'blocked' }));
  await assertFails(getDoc(doc(as('asha'), 'users/ben')));
  await assertSucceeds(deleteDoc(doc(as('asha'), 'users/ben/links/asha')), 'either side can remove its own trace');
});

test('day rows: only the owner writes, only numbers are accepted', async () => {
  const a = as('asha');
  await assertSucceeds(setDoc(doc(a, 'users/asha/days/20400'), row('asha', 20400)));
  await assertFails(setDoc(doc(as('ben'), 'users/asha/days/20401'), row('asha', 20401)));
  await assertFails(setDoc(doc(a, 'users/asha/days/20402'), { ...row('asha', 20402), projectName: 'Secret thesis' }), 'no project names');
  await assertFails(setDoc(doc(a, 'users/asha/days/20402'), { ...row('asha', 20402), note: 'my note' }), 'no notes');
  await assertFails(setDoc(doc(a, 'users/asha/days/20402'), { ...row('asha', 20402), photo: 'x' }), 'no photos');
  await assertFails(setDoc(doc(a, 'users/asha/days/20402'), { uid: 'asha', day: 20402, minutes: 50 }), 'all fields needed');
  await assertFails(setDoc(doc(a, 'users/asha/days/20403'), row('asha', 20404)), 'id must match the day');
  await assertFails(setDoc(doc(a, 'users/asha/days/20405'), row('ben', 20405)), 'uid must be yours');
  await assertFails(setDoc(doc(a, 'users/asha/days/20406'), row('asha', 20406, 9999)), 'at most 1440 minutes');
  await assertFails(setDoc(doc(a, 'users/asha/days/20407'), { ...row('asha', 20407), minutes: '50' }), 'numbers only');
});

test('day rows are readable by friends only', async () => {
  await seedDay('asha', 20400, 50);
  await assertSucceeds(getDoc(doc(as('asha'), 'users/asha/days/20400')));
  await assertFails(getDoc(doc(as('ben'), 'users/asha/days/20400')), 'not friends yet');
  await friendsAB();
  await assertSucceeds(getDoc(doc(as('ben'), 'users/asha/days/20400')));
  await assertFails(getDoc(doc(as('cara'), 'users/asha/days/20400')));
  await assertFails(getDocs(collection(as('cara'), 'users/asha/days')));
});

test('one-sided friendship is not enough to read', async () => {
  await seedDay('asha', 20400, 50);
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/asha/links/ben'), { state: 'accepted', name: 'Ben' });
    await setDoc(doc(ctx.firestore(), 'users/ben/links/asha'), { state: 'pending', name: 'Asha' });
  });
  await assertFails(getDoc(doc(as('ben'), 'users/asha/days/20400')));
});

test('nudges: friends only, one per day, fixed lines, id carries the day', async () => {
  await friendsAB();
  const a = as('asha');
  const n = { from: 'asha', to: 'ben', day: 20400, line: 1 };
  await assertSucceeds(setDoc(doc(a, 'nudges/asha_ben_20400'), n));
  await assertFails(setDoc(doc(a, 'nudges/asha_ben_20400'), n), 'second nudge the same day (doc exists)');
  await assertFails(setDoc(doc(a, 'nudges/asha_ben_20401'), { ...n, day: 20401, text: 'you are lazy' }), 'no free text');
  await assertFails(setDoc(doc(a, 'nudges/asha_ben_20401'), { ...n, day: 20401, line: 7 }));
  await assertFails(setDoc(doc(a, 'nudges/anything'), { ...n, day: 20402 }), 'id must follow the pattern');
  await assertFails(setDoc(doc(as('cara'), 'nudges/cara_ben_20400'), { from: 'cara', to: 'ben', day: 20400, line: 0 }), 'not friends');
  await assertFails(setDoc(doc(as('ben'), 'nudges/asha_ben_20402'), { ...n, day: 20402 }), 'cannot forge the sender');
  await assertSucceeds(getDoc(doc(as('ben'), 'nudges/asha_ben_20400')));
  await assertFails(getDoc(doc(as('cara'), 'nudges/asha_ben_20400')));
  await assertSucceeds(deleteDoc(doc(as('ben'), 'nudges/asha_ben_20400')));
});

const past = Timestamp.fromMillis(Date.now() - 3600_000);
const future = Timestamp.fromMillis(Date.now() + 3600_000);

test('duels: create, answer and settle with the real numbers only', async () => {
  await friendsAB();
  await assertFails(setDoc(doc(as('cara'), 'duels/d0'), { from: 'cara', to: 'asha', day: 20400, state: 'invited', endsAt: past }), 'not friends');
  await assertFails(setDoc(doc(as('asha'), 'duels/d1'), { from: 'asha', to: 'ben', day: 20400, state: 'active', endsAt: past }), 'must start invited');
  await assertSucceeds(setDoc(doc(as('asha'), 'duels/d1'), { from: 'asha', to: 'ben', day: 20400, state: 'invited', endsAt: past }));
  await assertFails(updateDoc(doc(as('asha'), 'duels/d1'), { state: 'active' }), 'the sender cannot accept for the friend');
  await assertFails(updateDoc(doc(as('ben'), 'duels/d1'), { state: 'finished', fromMinutes: 1, toMinutes: 99 }), 'cannot skip the answer');
  await assertSucceeds(updateDoc(doc(as('ben'), 'duels/d1'), { state: 'active' }));
  await seedDay('asha', 20400, 75);
  await seedDay('ben', 20400, 50);
  await assertFails(updateDoc(doc(as('asha'), 'duels/d1'), { state: 'finished', fromMinutes: 500, toMinutes: 50 }), 'inflated numbers');
  await assertSucceeds(updateDoc(doc(as('asha'), 'duels/d1'), { state: 'finished', fromMinutes: 75, toMinutes: 50 }));
  await assertFails(getDoc(doc(as('cara'), 'duels/d1')));
});

test('a duel cannot be settled before it ends', async () => {
  await friendsAB();
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'duels/d2'), { from: 'asha', to: 'ben', day: 20400, state: 'active', endsAt: future }));
  await assertFails(updateDoc(doc(as('asha'), 'duels/d2'), { state: 'finished', fromMinutes: 0, toMinutes: 0 }));
});

test('deleting an account: a person can remove their own data and their trace in others\' lists', async () => {
  await friendsAB();
  await seedDay('asha', 20400, 50);
  const a = as('asha');
  await assertSucceeds(deleteDoc(doc(a, 'users/asha/days/20400')));
  await assertSucceeds(deleteDoc(doc(a, 'users/asha/links/ben')));
  await assertSucceeds(deleteDoc(doc(a, 'users/ben/links/asha')), 'the entry others hold about me');
  await assertSucceeds(deleteDoc(doc(a, 'users/asha')));
  await assertFails(deleteDoc(doc(as('ben'), 'users/asha/days/20400')));
});
