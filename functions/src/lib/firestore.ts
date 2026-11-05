import type { Firestore } from "firebase-admin/firestore";

export const userRef = (db: Firestore, uid: string) => db.doc(`users/${uid}`);
export const crewRef = (db: Firestore, crewId: string) => db.doc(`crews/${crewId}`);
export const membersCol = (db: Firestore, crewId: string) => db.collection(`crews/${crewId}/members`);
export const memberRef = (db: Firestore, crewId: string, uid: string) => db.doc(`crews/${crewId}/members/${uid}`);
export const placeRef = (db: Firestore, crewId: string, placeId: string) => db.doc(`crews/${crewId}/places/${placeId}`);
export const rideRef = (db: Firestore, crewId: string, rideId: string) => db.doc(`crews/${crewId}/rides/${rideId}`);
export const requestRef = (db: Firestore, crewId: string, requestId: string) =>
  db.doc(`crews/${crewId}/requests/${requestId}`);
export const redemptionRef = (db: Firestore, crewId: string, redemptionId: string) =>
  db.doc(`crews/${crewId}/redemptions/${redemptionId}`);
export const routeRef = (db: Firestore, crewId: string, fromId: string, toId: string) =>
  db.doc(`crews/${crewId}/routes/${fromId}_${toId}`);
export const activityCol = (db: Firestore, crewId: string) => db.collection(`crews/${crewId}/activity`);
export const inviteCodeRef = (db: Firestore, code: string) => db.doc(`inviteCodes/${code}`);
