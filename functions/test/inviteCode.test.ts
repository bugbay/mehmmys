import { generateInviteCode, normaliseInviteCode, isValidInviteCode, INVITE_ALPHABET } from "../src/lib/inviteCode.js";

it("generates 6 chars from the alphabet", () => {
  for (let i = 0; i < 200; i++) {
    const c = generateInviteCode();
    expect(c).toHaveLength(6);
    expect([...c].every((ch) => INVITE_ALPHABET.includes(ch))).toBe(true);
  }
});

it("normalises user input", () => {
  expect(normaliseInviteCode(" ab 12\tcd\n")).toBe("AB12CD");
});

it("rejects ambiguous characters", () => {
  expect(isValidInviteCode("AB10CD")).toBe(false);
  expect(isValidInviteCode("ABOICD")).toBe(false);
  expect(isValidInviteCode("AB23CD")).toBe(true);
});

it("rejects wrong length", () => {
  expect(isValidInviteCode("AB23C")).toBe(false);
  expect(isValidInviteCode("AB23CDE")).toBe(false);
});
