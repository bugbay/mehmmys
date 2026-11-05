import type { DistanceUnit } from "../types.js";

export interface LatLng {
  lat: number;
  lng: number;
}

const EARTH_RADIUS_M = 6371008.8;
const ROAD_FACTOR = 1.3;
const METERS_PER_MILE = 1609.344;

export function haversineMeters(a: LatLng, b: LatLng): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function estimateRoadMeters(a: LatLng, b: LatLng): number {
  return Math.round(haversineMeters(a, b) * ROAD_FACTOR);
}

export function formatDistance(meters: number, unit: "mi" | "km"): string {
  const value = unit === "mi" ? meters / METERS_PER_MILE : meters / 1000;
  return `${value.toFixed(1)} ${unit}`;
}

export function resolveUnit(user: { unit?: DistanceUnit; locale?: string }): "mi" | "km" {
  if (user.unit === "mi" || user.unit === "km") return user.unit;
  const locale = (user.locale ?? "").replace("_", "-");
  return locale.startsWith("en-US") ? "mi" : "km";
}
