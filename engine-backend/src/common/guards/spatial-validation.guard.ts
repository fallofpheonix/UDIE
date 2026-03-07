import {
    Injectable,
    CanActivate,
    ExecutionContext,
    BadRequestException,
} from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class SpatialValidationGuard implements CanActivate {
    constructor(private readonly databaseService: DatabaseService) { }

    async canActivate(context: ExecutionContext): Promise<boolean> {
        const request = context.switchToHttp().getRequest();
        const { query, body, path } = request;

        // Handle /events bbox validation
        if (path.includes('/events')) {
            const { minLat, maxLat, minLng, maxLng } = query;
            if (minLat && maxLat && minLng && maxLng) {
                const area = Math.abs(maxLat - minLat) * Math.abs(maxLng - minLng);
                const maxArea = 1.0; // ~100km x 100km max
                if (area > maxArea) {
                    throw new BadRequestException(`Bounding box area too large (${area.toFixed(4)} > ${maxArea})`);
                }
            }
        }

        // Handle /risk vertex and distance validation
        if (path.includes('/risk')) {
            const vertices = body.coordinates?.length || 0;

            const params = await this.databaseService.query(
                "SELECT key, value FROM model_parameters WHERE key IN ('MAX_ROUTE_VERTICES', 'MAX_ROUTE_DISTANCE_KM')"
            );

            const maxVertices = params.rows.find(r => r.key === 'MAX_ROUTE_VERTICES')?.value || 500;
            const maxDistance = params.rows.find(r => r.key === 'MAX_ROUTE_DISTANCE_KM')?.value || 100;

            if (vertices > maxVertices) {
                throw new BadRequestException(`Route has too many vertices (${vertices} > ${maxVertices})`);
            }

            // Simple distance check (Euclidean approx for guard rail)
            if (vertices > 1) {
                let totalDist = 0;
                for (let i = 1; i < vertices; i++) {
                    const p1 = body.coordinates[i - 1];
                    const p2 = body.coordinates[i];
                    const dx = p1.lng - p2.lng;
                    const dy = p1.lat - p2.lat;
                    totalDist += Math.sqrt(dx * dx + dy * dy) * 111; // Approx km
                }

                if (totalDist > maxDistance) {
                    throw new BadRequestException(`Route distance too long (${totalDist.toFixed(1)}km > ${maxDistance}km)`);
                }
            }
        }

        return true;
    }
}
