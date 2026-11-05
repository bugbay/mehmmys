import { HttpsError, type FunctionsErrorCode } from "firebase-functions/v2/https";

export function fail(code: FunctionsErrorCode, message: string): never {
  throw new HttpsError(code, message);
}
