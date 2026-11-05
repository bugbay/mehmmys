import { setGlobalOptions } from "firebase-functions/v2";

setGlobalOptions({ region: "us-central1", maxInstances: 10 });

export * from "./callables.js";
export * from "./triggers.js";
