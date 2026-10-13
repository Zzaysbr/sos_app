import path from 'node:path';
import { fileURLToPath } from 'node:url';

import fs from 'node:fs';

import {
  afterAll,
  beforeAll,
  beforeEach,
  describe,
  it,
} from 'vitest';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const currentDirectory = path.dirname(fileURLToPath(import.meta.url));
const rulesPath = path.join(currentDirectory, 'firestore.rules');

const projectId = 'demo-off-grid-sos';
const ownerId = 'test2';
const otherId = 'test1';
const sosId = 'sos-test-document';

let testEnv;

const sosData = {
  id: sosId,
  ownerId,
  type: 'emergency',
  message: 'Test SOS',
  latitude: 14.0,
  longitude: 100.0,
  status: 'active',
  createdAt: new Date('2026-10-01T10:00:00Z'),
  updatedAt: new Date('2026-10-01T10:00:00Z'),
};

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(rulesPath, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'sos', sosId),
      sosData,
    );
  });
});

afterAll(async () => {
  await testEnv?.cleanup();
});

describe('Firestore SOS Security Rules', () => {
  it('owner can read own SOS', async () => {
    const db = testEnv.authenticatedContext(ownerId).firestore();

    await assertSucceeds(
      getDoc(doc(db, 'sos', sosId)),
    );
  });

  it('another user cannot read SOS', async () => {
    const db = testEnv.authenticatedContext(otherId).firestore();

    await assertFails(
      getDoc(doc(db, 'sos', sosId)),
    );
  });

  it('another user cannot update SOS', async () => {
    const db = testEnv.authenticatedContext(otherId).firestore();

    await assertFails(
      updateDoc(doc(db, 'sos', sosId), {
        message: 'Unauthorized change',
        updatedAt: new Date(),
      }),
    );
  });

  it('another user cannot delete SOS', async () => {
    const db = testEnv.authenticatedContext(otherId).firestore();

    await assertFails(
      deleteDoc(doc(db, 'sos', sosId)),
    );
  });

  it('unauthenticated user cannot read SOS', async () => {
    const db = testEnv.unauthenticatedContext().firestore();

    await assertFails(
      getDoc(doc(db, 'sos', sosId)),
    );
  });

  it('owner can update own SOS', async () => {
    const db = testEnv.authenticatedContext(ownerId).firestore();

    await assertSucceeds(
      updateDoc(doc(db, 'sos', sosId), {
        message: 'Updated by owner',
        updatedAt: new Date(),
      }),
    );
  });

  it('user cannot create SOS with another owner ID', async () => {
    const db = testEnv.authenticatedContext(otherId).firestore();

    await assertFails(
      setDoc(doc(db, 'sos', 'forged-sos'), {
        ...sosData,
        id: 'forged-sos',
        ownerId,
      }),
    );
  });

  it('owner can query SOS filtered by ownerId', async () => {
    const db = testEnv.authenticatedContext(ownerId).firestore();

    const sosQuery = query(
        collection(db, 'sos'),
        where('ownerId', '==', ownerId),
    );

    await assertSucceeds(getDocs(sosQuery));
    });
});