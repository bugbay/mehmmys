import { haversineMeters, estimateRoadMeters, formatDistance, resolveUnit } from "../src/lib/distance.js";

it("haversine NYC→Newark ≈ 15.1 km", () => {
  const m = haversineMeters({ lat: 40.7128, lng: -74.006 }, { lat: 40.7357, lng: -74.1724 });
  expect(m).toBeGreaterThan(14000);
  expect(m).toBeLessThan(15500);
});

it("road estimate is 1.3× haversine, rounded", () => {
  const a = { lat: 40.7128, lng: -74.006 };
  const b = { lat: 40.7357, lng: -74.1724 };
  expect(estimateRoadMeters(a, b)).toBe(Math.round(haversineMeters(a, b) * 1.3));
  expect(estimateRoadMeters(a, a)).toBe(0);
});

it("formats both units", () => {
  expect(formatDistance(8530, "mi")).toBe("5.3 mi");
  expect(formatDistance(8530, "km")).toBe("8.5 km");
});

it("resolves unit from locale when auto", () => {
  expect(resolveUnit({ unit: "auto", locale: "en-US" })).toBe("mi");
  expect(resolveUnit({ unit: "auto", locale: "en_US" })).toBe("mi");
  expect(resolveUnit({ unit: "auto", locale: "tr-TR" })).toBe("km");
  expect(resolveUnit({ unit: "auto", locale: undefined })).toBe("km");
  expect(resolveUnit({ unit: "km", locale: "en-US" })).toBe("km");
  expect(resolveUnit({ unit: "mi", locale: "tr-TR" })).toBe("mi");
});
