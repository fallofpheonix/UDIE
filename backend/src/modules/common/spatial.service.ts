import { Injectable } from '@nestjs/common';
import * as h3 from 'h3-js';

@Injectable()
export class SpatialService {
    /**
     * Derives the regional H3 Parent ID (Resolution 6) for a given point.
     * This serves as the partition key for national scaling.
     */
    getRegionId(lat: number, lng: number): string {
        const res9 = h3.latLngToCell(lat, lng, 9);
        return h3.cellToParent(res9, 6);
    }

    /**
     * Returns the H3 Res 9 index for coordinates.
     */
    getH3Index(lat: number, lng: number): string {
        return h3.latLngToCell(lat, lng, 9);
    }

    /**
     * Precomputed influence weights based on H3 grid distance (k-ring).
     * k=0: 1.0 (self)
     * k=1: 0.5
     * k=2: 0.25
     * k=3: 0.12
     */
    getInfluenceWeight(gridDistance: number): number {
        const weights: Record<number, number> = {
            0: 1.0,
            1: 0.5,
            2: 0.25,
            3: 0.12,
        };
        return weights[gridDistance] ?? 0;
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
}
