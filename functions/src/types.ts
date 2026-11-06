import type { Timestamp } from "firebase-admin/firestore";

export type MemberRole = "owner" | "coowner" | "driver";
export type RequestWhen = "now" | "morning" | "afternoon" | "tonight";
export type RedemptionStatus = "pending" | "delivered" | "rejected";
export type ActivityType = "ride" | "request" | "claim" | "redeem";
export type DistanceUnit = "auto" | "mi" | "km";
export type PushScreen = "ride" | "board" | "rewards" | "activity";

export interface RewardTier {
  id: string;
  cost: number;
  icon: string;
  title: string;
  subtitle: string;
}

export interface UserDoc {
  displayName: string;
  emoji: string;
  color: string;
  email?: string;
  unit: DistanceUnit;
  locale?: string;
  fcmTokens: string[];
  ownedCrewId?: string;
  createdAt: Timestamp;
}

export interface CrewDoc {
  name: string;
  ownerUid: string;
  coOwnerUids?: string[];
  inviteCode: string;
  rewardTiers: RewardTier[];
  createdAt: Timestamp;
}

export interface MemberDoc {
  uid?: string;
  role: MemberRole;
  displayName: string;
  emoji: string;
  color: string;
  mehmmys: number;
  meters: number;
  rides: number;
  joinedAt: Timestamp;
  legacy?: boolean;
}

export interface PlaceDoc {
  name: string;
  lat: number;
  lng: number;
  createdAt: Timestamp;
}

export interface RideDoc {
  driverUid: string;
  fromPlaceId: string;
  fromName: string;
  toPlaceId: string;
  toName: string;
  meters: number;
  estimated: boolean;
  ts: Timestamp;
  createdBy: string;
  applied?: boolean;
  invalid?: boolean;
}

export interface RequestDoc {
  byUid: string;
  fromName: string;
  toName: string;
  when: RequestWhen;
  ts: Timestamp;
  claimedBy?: string | null;
  claimedAt?: Timestamp | null;
}

export interface RedemptionDoc {
  driverUid: string;
  tierId: string;
  title: string;
  cost: number;
  ts: Timestamp;
  status: RedemptionStatus;
  applied?: boolean;
}

export interface RouteDoc {
  meters: number;
  estimated: boolean;
  computedAt: Timestamp;
}

export interface ActivityDoc {
  type: ActivityType;
  ts: Timestamp;
  crewId: string;
  actorUid: string;
  actorName: string;
  actorEmoji: string;
  [key: string]: unknown;
}

// founder or co-owner
export function isManager(crew: Pick<CrewDoc, "ownerUid" | "coOwnerUids">, uid: string): boolean {
  return crew.ownerUid === uid || (crew.coOwnerUids ?? []).includes(uid);
}

export function managerUids(crew: Pick<CrewDoc, "ownerUid" | "coOwnerUids">): string[] {
  return [crew.ownerUid, ...(crew.coOwnerUids ?? [])];
}
