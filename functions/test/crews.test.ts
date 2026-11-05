import { db } from "./setup.js";
import { makeUser, makeCrew, makeMember } from "./factories.js";
import { createCrew, joinCrew, leaveCrew, removeMember, linkLegacyMember } from "../src/logic/crews.js";
import { DEFAULT_TIERS } from "../src/lib/defaultTiers.js";

const rejectsWith = (p: Promise<unknown>, code: string) => expect(p).rejects.toMatchObject({ code });

describe("createCrew", () => {
  it("creates crew, owner member, invite code and links the user", async () => {
    const { uid } = await makeUser(db, { displayName: "Mehmed", emoji: "🙋" });
    const { crewId, inviteCode } = await createCrew(db, uid, { name: "  Mehmed's crew " });
    const crew = (await db.doc(`crews/${crewId}`).get()).data()!;
    expect(crew).toMatchObject({ name: "Mehmed's crew", ownerUid: uid, inviteCode, rewardTiers: DEFAULT_TIERS });
    expect((await db.doc(`crews/${crewId}/members/${uid}`).get()).data()).toMatchObject({
      uid, role: "owner", displayName: "Mehmed", emoji: "🙋", mehmmys: 0, meters: 0, rides: 0,
    });
    expect((await db.doc(`inviteCodes/${inviteCode}`).get()).data()).toEqual({ crewId });
    expect((await db.doc(`users/${uid}`).get()).get("ownedCrewId")).toBe(crewId);
  });

  it("rejects blank and overlong names", async () => {
    const { uid } = await makeUser(db);
    await rejectsWith(createCrew(db, uid, { name: "   " }), "invalid-argument");
    await rejectsWith(createCrew(db, uid, { name: "x".repeat(41) }), "invalid-argument");
  });

  it("rejects a second crew for the same owner", async () => {
    const { uid } = await makeUser(db);
    await createCrew(db, uid, { name: "One" });
    await rejectsWith(createCrew(db, uid, { name: "Two" }), "failed-precondition");
  });

  it("rejects a user without a profile", async () => {
    await rejectsWith(createCrew(db, "ghost", { name: "x" }), "failed-precondition");
  });

  it("retries when the generated invite code is taken", async () => {
    const { uid } = await makeUser(db);
    await db.doc("inviteCodes/AAAAAA").set({ crewId: "other" });
    const codes = ["AAAAAA", "BBBBBB"];
    const { inviteCode } = await createCrew(db, uid, { name: "x" }, () => codes.shift()!);
    expect(inviteCode).toBe("BBBBBB");
    expect((await db.doc("inviteCodes/AAAAAA").get()).get("crewId")).toBe("other");
  });
});

describe("joinCrew", () => {
  let ownerUid: string;
  let crewId: string;
  let inviteCode: string;
  beforeEach(async () => {
    ({ uid: ownerUid } = await makeUser(db));
    ({ crewId, inviteCode } = await makeCrew(db, ownerUid, { inviteCode: "AB23CD" }));
  });

  it("normalises the code and joins as driver with a profile copy", async () => {
    const { uid } = await makeUser(db, { displayName: "Leo", emoji: "🐶", color: "#7DD3FC" });
    expect(await joinCrew(db, uid, { code: " ab 23\tcd\n" })).toEqual({ crewId });
    expect((await db.doc(`crews/${crewId}/members/${uid}`).get()).data()).toMatchObject({
      uid, role: "driver", displayName: "Leo", emoji: "🐶", color: "#7DD3FC", mehmmys: 0, meters: 0, rides: 0,
    });
    expect(inviteCode).toBe("AB23CD");
  });

  it("rejects unknown and ambiguous codes as not-found", async () => {
    const { uid } = await makeUser(db);
    await rejectsWith(joinCrew(db, uid, { code: "ZZ23ZZ" }), "not-found");
    await rejectsWith(joinCrew(db, uid, { code: "AB20CD" }), "not-found");
    await rejectsWith(joinCrew(db, uid, { code: "" }), "not-found");
  });

  it("rejects the owner joining their own crew", async () => {
    await rejectsWith(joinCrew(db, ownerUid, { code: "AB23CD" }), "failed-precondition");
  });

  it("rejects an existing member", async () => {
    const { uid } = await makeUser(db);
    await joinCrew(db, uid, { code: "AB23CD" });
    await rejectsWith(joinCrew(db, uid, { code: "AB23CD" }), "already-exists");
  });
});

describe("leaveCrew and removeMember", () => {
  let ownerUid: string;
  let driverUid: string;
  let crewId: string;
  beforeEach(async () => {
    ({ uid: ownerUid } = await makeUser(db));
    ({ uid: driverUid } = await makeUser(db));
    ({ crewId } = await makeCrew(db, ownerUid));
    await makeMember(db, crewId, driverUid);
  });

  it("driver can leave", async () => {
    await leaveCrew(db, driverUid, { crewId });
    expect((await db.doc(`crews/${crewId}/members/${driverUid}`).get()).exists).toBe(false);
  });

  it("owner cannot leave", async () => {
    await rejectsWith(leaveCrew(db, ownerUid, { crewId }), "failed-precondition");
  });

  it("non-member leaving gets not-found", async () => {
    await rejectsWith(leaveCrew(db, "stranger", { crewId }), "not-found");
  });

  it("owner can remove a driver", async () => {
    await removeMember(db, ownerUid, { crewId, memberUid: driverUid });
    expect((await db.doc(`crews/${crewId}/members/${driverUid}`).get()).exists).toBe(false);
  });

  it("driver cannot remove anyone", async () => {
    await rejectsWith(removeMember(db, driverUid, { crewId, memberUid: driverUid }), "permission-denied");
  });

  it("owner cannot remove themselves", async () => {
    await rejectsWith(removeMember(db, ownerUid, { crewId, memberUid: ownerUid }), "failed-precondition");
  });
});

describe("linkLegacyMember", () => {
  let ownerUid: string, leo: string, crewId: string;
  beforeEach(async () => {
    ({ uid: ownerUid } = await makeUser(db));
    ({ uid: leo } = await makeUser(db));
    ({ crewId } = await makeCrew(db, ownerUid));
    await makeMember(db, crewId, leo, { mehmmys: 1, meters: 500, rides: 1 });
    await db.doc(`crews/${crewId}/members/stub1`).set({
      legacy: true, role: "driver", displayName: "Leo", emoji: "🐶", color: "#7DD3FC", mehmmys: 4, meters: 20000, rides: 4,
    });
  });

  it("moves the stub's counters onto the real member and deletes the stub", async () => {
    await linkLegacyMember(db, ownerUid, { crewId, stubId: "stub1", memberUid: leo });
    expect((await db.doc(`crews/${crewId}/members/${leo}`).get()).data()).toMatchObject({ mehmmys: 5, meters: 20500, rides: 5 });
    expect((await db.doc(`crews/${crewId}/members/stub1`).get()).exists).toBe(false);
  });

  it("only the owner can link", async () => {
    await rejectsWith(linkLegacyMember(db, leo, { crewId, stubId: "stub1", memberUid: leo }), "permission-denied");
  });

  it("rejects a non-legacy stub or a missing member", async () => {
    await rejectsWith(linkLegacyMember(db, ownerUid, { crewId, stubId: leo, memberUid: leo }), "failed-precondition");
    await rejectsWith(linkLegacyMember(db, ownerUid, { crewId, stubId: "stub1", memberUid: "ghost" }), "not-found");
  });
});
