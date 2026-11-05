import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

export const PROJECT_ID = "mehmmy-rewards";
process.env.GCLOUD_PROJECT ??= PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";

const app = getApps()[0] ?? initializeApp({ projectId: PROJECT_ID });
export const db = getFirestore(app);
export const auth = getAuth(app);

export async function clearFirestore(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  const res = await fetch(
    `http://${host}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  if (!res.ok) throw new Error(`clearFirestore failed: ${res.status}`);
}

export async function clearAuth(): Promise<void> {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  await fetch(`http://${host}/emulator/v1/projects/${PROJECT_ID}/accounts`, { method: "DELETE" });
}

beforeEach(async () => {
  await clearFirestore();
  await clearAuth();
});
