import { randomInt } from "node:crypto";

export const INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const INVITE_LENGTH = 6;

export function generateInviteCode(): string {
  let code = "";
  for (let i = 0; i < INVITE_LENGTH; i++) code += INVITE_ALPHABET[randomInt(INVITE_ALPHABET.length)];
  return code;
}

export function normaliseInviteCode(raw: string): string {
  return String(raw ?? "").replace(/\s+/g, "").toUpperCase();
}

export function isValidInviteCode(code: string): boolean {
  return code.length === INVITE_LENGTH && [...code].every((ch) => INVITE_ALPHABET.includes(ch));
}
