import { estimateRoadMeters, type LatLng } from "./distance.js";
import { isEmulator } from "./push.js";

export type { LatLng };

export interface RouteProvider {
  computeMeters(from: LatLng, to: LatLng): Promise<number>;
}

export class HaversineRouteProvider implements RouteProvider {
  async computeMeters(from: LatLng, to: LatLng): Promise<number> {
    return estimateRoadMeters(from, to);
  }
}

const ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes";

export class GoogleRoutesProvider implements RouteProvider {
  constructor(private readonly apiKey: string) {}

  async computeMeters(from: LatLng, to: LatLng): Promise<number> {
    const point = (p: LatLng) => ({ location: { latLng: { latitude: p.lat, longitude: p.lng } } });
    const res = await fetch(ROUTES_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": this.apiKey,
        "X-Goog-FieldMask": "routes.distanceMeters",
      },
      body: JSON.stringify({
        origin: point(from),
        destination: point(to),
        travelMode: "DRIVE",
        routingPreference: "TRAFFIC_UNAWARE",
      }),
    });
    if (!res.ok) throw new Error(`routes api ${res.status}: ${await res.text()}`);
    const json = (await res.json()) as { routes?: { distanceMeters?: number }[] };
    const meters = json.routes?.[0]?.distanceMeters;
    if (typeof meters !== "number" || meters <= 0) throw new Error("routes api returned no route");
    return meters;
  }
}

export function getRouteProvider(apiKey?: string): RouteProvider {
  if (isEmulator() || !apiKey) return new HaversineRouteProvider();
  return new GoogleRoutesProvider(apiKey);
}
