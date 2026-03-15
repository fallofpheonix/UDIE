import { Injectable } from '@nestjs/common';
import * as h3 from 'h3-js';

@Injectable()
export class SpatialService {
    readonly streetResolution = 9;
    readonly shardResolution = 6;

    toDbIndex(h3Cell: string): string {
        return BigInt(`0x${h3Cell}`).toString(10);
    }

    fromDbIndex(dbIndex: string | number | bigint): string {
        return BigInt(dbIndex).toString(16);
    }

    /**
     * Derives the regional H3 Parent ID (Resolution 6) for a given point.
     * This serves as the partition key for national scaling.
     */
    getRegionId(lat: number, lng: number): string {
        const res9 = h3.latLngToCell(lat, lng, this.streetResolution);
        return this.toDbIndex(h3.cellToParent(res9, this.shardResolution));
    }

    /**
     * Returns the H3 Res 9 index for coordinates.
     */
    getH3Index(lat: number, lng: number): string {
        return h3.latLngToCell(lat, lng, this.streetResolution);
    }

    getCellCenter(h3Index: string): [number, number] {
        return h3.cellToLatLng(h3Index);
    }

    getCellParent(h3Index: string, resolution = this.shardResolution): string {
        return h3.cellToParent(h3Index, resolution);
    }

    getCellNeighbors(h3Index: string, k = 1): string[] {
        return h3.gridDisk(h3Index, k);
    }

    getCoveringCells(
        minLat: number,
        minLng: number,
        maxLat: number,
        maxLng: number,
        resolution = this.streetResolution,
    ): string[] {
        const polygon: h3.CoordPair[] = [
            [minLat, minLng],
            [minLat, maxLng],
            [maxLat, maxLng],
            [maxLat, minLng],
            [minLat, minLng],
        ];

        return h3.polygonToCells(polygon, resolution);
    }

    /**
     * Exponential influence weight based on geodesic distance.
     * Spec v2: I = exp(-d / lambda)
     * lambda = 250m (default)
     */
    getInfluenceWeight(gridDistance: number): number {
        if (gridDistance === 0) return 1.0;

        // H3 Res 9 center-to-center distance is approx 300m.
        const distanceMeters = gridDistance * 300;
        const lambda = 250;

        const weight = Math.exp(-distanceMeters / lambda);
        return parseFloat(weight.toFixed(4));
    }

    /**
     * Returns neighbors up to k=3 for streaming aggregation.
     */
    getInfluenceNeighbors(h3Index: string, k = 3): string[] {
        return h3.gridDisk(h3Index, k);
    }

    /**
     * Calculates grid distance between two Res 9 cells.
     */
    getGridDistance(origin: string, destination: string): number {
        try {
            return h3.gridDistance(origin, destination);
        } catch {
            return 999; // Far away
        }
    }

    /**
     * Calculates the set of H3 Res 6 regions (partitions) covering a bounding box.
     * Used for database partition pruning.
     */
    getCoveringRegions(minLat: number, minLng: number, maxLat: number, maxLng: number): string[] {
        const cells = this.getCoveringCells(minLat, minLng, maxLat, maxLng, this.shardResolution);
        return Array.from(new Set(cells.map((cell) => this.toDbIndex(cell))));
    }
}
