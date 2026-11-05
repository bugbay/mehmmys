import { db, auth } from "./setup.js";
import { seedDemo } from "../src/logic/demo.js";
import { isValidInviteCode } from "../src/lib/inviteCode.js";

it("seeds one demo crew idempotently", async () => {
  const first = await seedDemo(db, auth, { ownerEmail: "review@mehmmys.app" });
  const second = await seedDemo(db, auth, { ownerEmail: "review@mehmmys.app" });
  expect(second.crewId).toBe(first.crewId);
  expect(isValidInviteCode(first.inviteCode)).toBe(true);
  expect((await db.doc(`inviteCodes/${first.inviteCode}`).get()).get("crewId")).toBe(first.crewId);

  const owner = await auth.getUserByEmail("review@mehmmys.app");
  const crews = await db.collection("crews").where("ownerUid", "==", owner.uid).get();
  expect(crews.size).toBe(1);
  expect(crews.docs[0].get("name")).toBe("Demo Crew");

  const members = await db.collection(`crews/${first.crewId}/members`).get();
  const drivers = members.docs.filter((d) => d.get("role") === "driver");
  expect(drivers.map((d) => d.get("displayName")).sort()).toEqual(["Leo", "Manan", "Shannon"]);
  expect(Object.fromEntries(drivers.map((d) => [d.get("displayName"), d.get("mehmmys")]))).toEqual({ Leo: 2, Shannon: 1, Manan: 0 });
  expect(members.docs.find((d) => d.id === owner.uid)?.get("mehmmys")).toBe(0);
  expect(first.driverUids).toHaveLength(3);

  expect((await db.collection(`crews/${first.crewId}/places`).get()).size).toBe(3);
  expect((await db.collection(`crews/${first.crewId}/rides`).get()).size).toBe(2);
  expect((await db.collection(`crews/${first.crewId}/activity`).get()).size).toBe(2);
});
