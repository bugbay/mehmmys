import * as triggers from "../src/triggers.js";

type WithEndpoint = { __endpoint: { eventTrigger?: { retry?: boolean } } };

it("firestore triggers retry on failure", () => {
  for (const name of ["onRideCreated", "onRequestCreated", "onRequestUpdated", "onRedemptionCreated"] as const) {
    expect((triggers[name] as unknown as WithEndpoint).__endpoint.eventTrigger?.retry, name).toBe(true);
  }
});
