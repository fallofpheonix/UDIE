import * as h3 from 'h3-js';

export interface Coordinate {
  lat: number;
  lng: number;
}

export function resolveRouteRegion(coordinates: Coordinate[]): string {
  if (coordinates.length === 0) {
    throw new Error('coordinates are required');
  }

  const pivot = coordinates[Math.floor(coordinates.length / 2)];
  const cell = h3.latLngToCell(pivot.lat, pivot.lng, 9);
  return BigInt(`0x${h3.cellToParent(cell, 6)}`).toString(10);
}
