import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as functionsV1 from "firebase-functions/v1";
import { db } from "./lib/admin.js";
import { getPushSender } from "./lib/push.js";
import { applyRideCreated } from "./logic/rides.js";
import { applyRequestCreated, applyRequestClaimed } from "./logic/requests.js";
import { applyRedemptionCreated } from "./logic/redemptions.js";
import { cleanupUser } from "./logic/account.js";

export const onRideCreated = onDocumentCreated("crews/{crewId}/rides/{rideId}", (event) =>
  applyRideCreated(db, getPushSender(), event.params.crewId, event.params.rideId),
);

export const onRequestCreated = onDocumentCreated("crews/{crewId}/requests/{requestId}", (event) =>
  applyRequestCreated(db, getPushSender(), event.params.crewId, event.params.requestId),
);

export const onRequestUpdated = onDocumentUpdated("crews/{crewId}/requests/{requestId}", async (event) => {
  const before = event.data?.before.get("claimedBy") ?? null;
  const after = event.data?.after.get("claimedBy") ?? null;
  if (before !== null || after === null) return;
  await applyRequestClaimed(db, getPushSender(), event.params.crewId, event.params.requestId);
});

export const onRedemptionCreated = onDocumentCreated("crews/{crewId}/redemptions/{redemptionId}", (event) =>
  applyRedemptionCreated(db, getPushSender(), event.params.crewId, event.params.redemptionId),
);

export const onUserDeleted = functionsV1
  .region("us-central1")
  .auth.user()
  .onDelete((user) => cleanupUser(db, user.uid));
