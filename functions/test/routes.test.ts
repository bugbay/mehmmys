import { HaversineRouteProvider, GoogleRoutesProvider, getRouteProvider } from "../src/lib/routes.js";
import { estimateRoadMeters } from "../src/lib/distance.js";

const a = { lat: 40.7128, lng: -74.006 };
const b = { lat: 40.7357, lng: -74.1724 };

afterEach(() => vi.unstubAllGlobals());

it("haversine provider returns the road estimate", async () => {
  expect(await new HaversineRouteProvider().computeMeters(a, b)).toBe(estimateRoadMeters(a, b));
});

it("google provider posts a DRIVE request and parses distanceMeters", async () => {
  const fetchMock = vi.fn(async () => new Response(JSON.stringify({ routes: [{ distanceMeters: 8530 }] }), { status: 200 }));
  vi.stubGlobal("fetch", fetchMock);
  expect(await new GoogleRoutesProvider("key").computeMeters(a, b)).toBe(8530);
  const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
  expect(url).toBe("https://routes.googleapis.com/directions/v2:computeRoutes");
  const headers = init.headers as Record<string, string>;
  expect(headers["X-Goog-Api-Key"]).toBe("key");
  expect(headers["X-Goog-FieldMask"]).toBe("routes.distanceMeters");
  const body = JSON.parse(init.body as string);
  expect(body.travelMode).toBe("DRIVE");
  expect(body.routingPreference).toBe("TRAFFIC_UNAWARE");
  expect(body.origin.location.latLng).toEqual({ latitude: a.lat, longitude: a.lng });
});

it("google provider throws on empty routes", async () => {
  vi.stubGlobal("fetch", vi.fn(async () => new Response(JSON.stringify({ routes: [] }), { status: 200 })));
  await expect(new GoogleRoutesProvider("key").computeMeters(a, b)).rejects.toThrow();
});

it("google provider throws on non-200", async () => {
  vi.stubGlobal("fetch", vi.fn(async () => new Response("denied", { status: 403 })));
  await expect(new GoogleRoutesProvider("key").computeMeters(a, b)).rejects.toThrow();
});

it("getRouteProvider returns haversine under the emulator", () => {
  expect(getRouteProvider("key")).toBeInstanceOf(HaversineRouteProvider);
});
