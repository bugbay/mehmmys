import type { Firestore } from "firebase-admin/firestore";
import { crewRef, memberRef, membersCol, requestRef } from "../lib/firestore.js";
import type { PushSender } from "../lib/push.js";
import { isManager, type CrewDoc, type MemberDoc, type RequestDoc, type RequestWhen } from "../types.js";
import { writeActivityOnce } from "./activity.js";

const WHEN_LABEL: Record<RequestWhen, string> = {
  now: "Now",
  morning: "Morning",
  afternoon: "Afternoon",
  tonight: "Tonight",
};

export async function applyRequestCreated(db: Firestore, push: PushSender, crewId: string, requestId: string): Promise<void> {
  const req = (await requestRef(db, crewId, requestId).get()).data() as RequestDoc | undefined;
  const crew = (await crewRef(db, crewId).get()).data() as CrewDoc | undefined;
  if (!req || !crew || !isManager(crew, req.byUid)) return;
  const owner = (await memberRef(db, crewId, req.byUid).get()).data() as MemberDoc | undefined;
  const wrote = await writeActivityOnce(db, crewId, `request_${requestId}`, "request", req.byUid, owner, {
    fromName: req.fromName,
    toName: req.toName,
    when: req.when,
    requestId,
    public: true,
    involved: [req.byUid],
  });
  if (!wrote) return;

  const members = await membersCol(db, crewId).get();
  const recipients = members.docs
    .filter((d) => d.id !== req.byUid && d.get("legacy") !== true)
    .map((d) => d.id);
  if (recipients.length === 0) return;
  await push.sendToUsers(db, recipients, {
    title: crew.name,
    body: `${owner?.displayName ?? "Your friend"} needs a ride · ${req.fromName} → ${req.toName} · ${WHEN_LABEL[req.when] ?? req.when}`,
    data: { crewId, screen: "ride" },
  });
}

export async function applyRequestClaimed(db: Firestore, push: PushSender, crewId: string, requestId: string): Promise<void> {
  const req = (await requestRef(db, crewId, requestId).get()).data() as RequestDoc | undefined;
  if (!req || !req.claimedBy) return;
  const crew = (await crewRef(db, crewId).get()).data() as CrewDoc | undefined;
  const driver = (await memberRef(db, crewId, req.claimedBy).get()).data() as MemberDoc | undefined;
  if (!crew || !driver) return;
  const wrote = await writeActivityOnce(db, crewId, `claim_${requestId}`, "claim", req.claimedBy, driver, {
    requestId,
    driverName: driver.displayName,
    fromName: req.fromName,
    toName: req.toName,
    public: false,
    involved: [req.claimedBy, req.byUid],
  });
  if (!wrote) return;
  await push.sendToUsers(db, [req.byUid], {
    title: crew.name,
    body: `${driver.displayName}'s got you 🚗`,
    data: { crewId, screen: "activity" },
  });
}
