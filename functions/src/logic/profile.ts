import type { Firestore } from "firebase-admin/firestore";
import { fail } from "../lib/errors.js";
import { userRef } from "../lib/firestore.js";

const COLOR = /^#[0-9A-Fa-f]{6}$/;
const BATCH_LIMIT = 450;

function graphemes(s: string): number {
  return [...new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(s)].length;
}

export async function updateProfile(
  db: Firestore,
  uid: string,
  input: { displayName: string; emoji: string; color: string },
): Promise<void> {
  const displayName = typeof input?.displayName === "string" ? input.displayName.trim() : "";
  const emoji = typeof input?.emoji === "string" ? input.emoji.trim() : "";
  const color = typeof input?.color === "string" ? input.color : "";
  if (displayName.length < 1 || displayName.length > 30) fail("invalid-argument", "name must be 1-30 characters");
  const n = graphemes(emoji);
  if (n < 1 || n > 2) fail("invalid-argument", "pick one emoji");
  if (!COLOR.test(color)) fail("invalid-argument", "color must be #RRGGBB");

  const ref = userRef(db, uid);
  if (!(await ref.get()).exists) fail("failed-precondition", "create your profile first");
  const fields = { displayName, emoji, color };
  await ref.update(fields);

  const members = await db.collectionGroup("members").where("uid", "==", uid).get();
  for (let i = 0; i < members.docs.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    members.docs.slice(i, i + BATCH_LIMIT).forEach((d) => batch.update(d.ref, fields));
    await batch.commit();
  }
}
