import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { after, before, beforeEach, test } from "node:test";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from "firebase/firestore";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";

const projectId = "demo-privatecircle";
const groupId = "group-1";
const meetupId = "meetup-1";
const meetupPath = `groups/${groupId}/meetups/${meetupId}`;
const maximumParticipantUIDs = [
  "owner",
  "participant",
  ...Array.from({ length: 18 }, (_, index) => `member-${index + 1}`),
];
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: { rules: await readFile("firestore.rules", "utf8") },
  });
});

after(async () => {
  await environment.cleanup();
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, `groups/${groupId}`), { name: "테스트 그룹", createdBy: "owner" });
    for (const uid of ["owner", "participant", "other-member", ...maximumParticipantUIDs.slice(2)]) {
      await setDoc(doc(db, `groups/${groupId}/members/${uid}`), { displayName: uid, role: uid === "owner" ? "owner" : "member" });
    }
    await setDoc(doc(db, meetupPath), {
      groupID: groupId,
      title: "토요일 저녁",
      participants: [
        { id: "owner", name: "모임 만든 사람" },
        { id: "participant", name: "참가자" },
      ],
      participantUIDs: ["owner", "participant"],
      candidateIDs: ["candidate-1", "candidate-2"],
      candidateTimes: [
        { id: "candidate-1", startsAt: new Date("2026-10-03T05:00:00.000Z") },
        { id: "candidate-2", startsAt: new Date("2026-10-03T09:00:00.000Z") },
      ],
      status: "planning",
      ownerUID: "owner",
      createdAt: new Date(),
    });
    for (const uid of ["owner", "participant"]) {
      await setDoc(doc(db, `users/${uid}/sharedMeetupRefs/${groupId}_${meetupId}`), {
        groupID: groupId,
        meetupID: meetupId,
        createdAt: new Date(),
      });
    }
    await setDoc(doc(db, `${meetupPath}/availability/participant`), {
      availableCandidateIDs: ["candidate-1"],
      updatedAt: new Date(),
    });
  });
});

function signedIn(uid, emailVerified = true) {
  return environment.authenticatedContext(uid, {
    email: `${uid}@example.com`,
    email_verified: emailVerified,
  }).firestore();
}

test("only participants can read a meetup and its responses", async () => {
  const participantDB = signedIn("participant");
  await assertSucceeds(getDoc(doc(participantDB, meetupPath)));
  await assertFails(getDocs(collection(participantDB, `groups/${groupId}/meetups`)));
  await assertSucceeds(getDocs(collection(participantDB, `${meetupPath}/availability`)));
  const participantReferences = await assertSucceeds(getDocs(collection(participantDB, "users/participant/sharedMeetupRefs")));
  assert.equal(participantReferences.size, 1);

  const otherMemberDB = signedIn("other-member");
  await assertFails(getDoc(doc(otherMemberDB, meetupPath)));
  await assertFails(getDocs(collection(otherMemberDB, `groups/${groupId}/meetups`)));
  await assertFails(getDocs(collection(otherMemberDB, `${meetupPath}/availability`)));
  const otherReferences = await assertSucceeds(getDocs(collection(otherMemberDB, "users/other-member/sharedMeetupRefs")));
  assert.equal(otherReferences.size, 0);

  const outsiderDB = signedIn("outsider");
  await assertFails(getDoc(doc(outsiderDB, meetupPath)));
  await assertFails(getDocs(collection(outsiderDB, `${meetupPath}/availability`)));
  await assertFails(getDoc(doc(signedIn("participant", false), meetupPath)));
});

test("creating a shared meetup atomically grants references only to its group participants", async () => {
  const candidateTimes = [
    { id: "candidate-1", startsAt: new Date("2026-10-03T05:00:00.000Z") },
  ];
  const payload = {
    groupID: groupId,
    title: "새 모임",
    participants: maximumParticipantUIDs.map((id) => ({ id, name: id })),
    participantUIDs: maximumParticipantUIDs,
    candidateIDs: ["candidate-1"],
    candidateTimes,
    status: "planning",
    ownerUID: "owner",
    createdAt: serverTimestamp(),
  };
  const ownerDB = signedIn("owner");
  const batch = writeBatch(ownerDB);
  const newMeetupPath = `groups/${groupId}/meetups/new-meetup`;
  batch.set(doc(ownerDB, newMeetupPath), payload);
  for (const uid of payload.participantUIDs) {
    batch.set(doc(ownerDB, `users/${uid}/sharedMeetupRefs/${groupId}_new-meetup`), {
      groupID: groupId,
      meetupID: "new-meetup",
      createdAt: serverTimestamp(),
    });
  }
  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(doc(signedIn("participant"), newMeetupPath)));

  await assertFails(setDoc(doc(ownerDB, `users/other-member/sharedMeetupRefs/${groupId}_new-meetup`), {
    groupID: groupId,
    meetupID: "new-meetup",
    createdAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(signedIn("outsider"), `groups/${groupId}/meetups/outside-meetup`), payload));
  await assertFails(setDoc(doc(signedIn("owner"), `groups/${groupId}/meetups/missing-owner`), {
    ...payload,
    participants: [{ id: "participant", name: "참가자" }],
    participantUIDs: ["participant"],
  }));
});

test("participants can only write their own candidate response while planning", async () => {
  const participantDB = signedIn("participant");
  await assertSucceeds(setDoc(doc(participantDB, `${meetupPath}/availability/participant`), {
    availableCandidateIDs: ["candidate-2"],
    updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(participantDB, `${meetupPath}/availability/owner`), {
    availableCandidateIDs: ["candidate-1"],
    updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(participantDB, `${meetupPath}/availability/participant`), {
    availableCandidateIDs: ["not-a-candidate"],
    updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(signedIn("other-member"), `${meetupPath}/availability/other-member`), {
    availableCandidateIDs: ["candidate-1"],
    updatedAt: serverTimestamp(),
  }));
});

test("only the meetup owner can confirm one of its candidates", async () => {
  const participantDB = signedIn("participant");
  await assertFails(updateDoc(doc(participantDB, meetupPath), {
    status: "confirmed",
    confirmedCandidateID: "candidate-1",
    confirmedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(signedIn("owner"), meetupPath), {
    status: "confirmed",
    confirmedCandidateID: "not-a-candidate",
    confirmedAt: serverTimestamp(),
  }));

  const ownerDB = signedIn("owner");
  await assertFails(updateDoc(doc(ownerDB, meetupPath), {
    status: "confirmed",
    confirmedCandidateID: "candidate-1",
    confirmedAt: serverTimestamp(),
    title: "Changed title",
  }));
  await assertSucceeds(updateDoc(doc(ownerDB, meetupPath), {
    status: "confirmed",
    confirmedCandidateID: "candidate-1",
    confirmedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(participantDB, `${meetupPath}/availability/participant`), {
    availableCandidateIDs: ["candidate-1"],
    updatedAt: serverTimestamp(),
  }));
});
