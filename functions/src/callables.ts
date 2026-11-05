import { onCall, type CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { db, auth } from "./lib/admin.js";
import { fail } from "./lib/errors.js";
import { getRouteProvider } from "./lib/routes.js";
import * as crews from "./logic/crews.js";
import { computeRoute as computeRouteLogic } from "./logic/routing.js";
import { updateProfile as updateProfileLogic } from "./logic/profile.js";
import { deleteAccount as deleteAccountLogic } from "./logic/account.js";
import { seedDemo as seedDemoLogic } from "./logic/demo.js";

const routesKey = defineSecret("GOOGLE_ROUTES_API_KEY");
const seedSecret = defineSecret("SEED_SECRET");

function uidOf(req: CallableRequest): string {
  if (!req.auth) fail("unauthenticated", "sign in first");
  return req.auth.uid;
}

export const createCrew = onCall((req) => crews.createCrew(db, uidOf(req), req.data));
export const joinCrew = onCall((req) => crews.joinCrew(db, uidOf(req), req.data));
export const leaveCrew = onCall(async (req) => {
  await crews.leaveCrew(db, uidOf(req), req.data);
  return { ok: true };
});
export const removeMember = onCall(async (req) => {
  await crews.removeMember(db, uidOf(req), req.data);
  return { ok: true };
});
export const linkLegacyMember = onCall(async (req) => {
  await crews.linkLegacyMember(db, uidOf(req), req.data);
  return { ok: true };
});
export const computeRoute = onCall({ secrets: [routesKey] }, (req) =>
  computeRouteLogic(db, getRouteProvider(routesKey.value()), uidOf(req), req.data),
);
export const updateProfile = onCall(async (req) => {
  await updateProfileLogic(db, uidOf(req), req.data);
  return { ok: true };
});
export const deleteAccount = onCall(async (req) => {
  await deleteAccountLogic(db, auth, uidOf(req));
  return { ok: true };
});
export const seedDemo = onCall({ secrets: [seedSecret] }, (req) => {
  uidOf(req);
  const data = req.data as { secret?: string; ownerEmail?: string };
  if (!data?.secret || data.secret !== seedSecret.value()) fail("permission-denied", "bad secret");
  if (!data.ownerEmail) fail("invalid-argument", "ownerEmail required");
  return seedDemoLogic(db, auth, { ownerEmail: data.ownerEmail });
});
