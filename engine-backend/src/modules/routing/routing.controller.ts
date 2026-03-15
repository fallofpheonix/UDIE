import {
  Body,
  Controller,
  Get,
  HttpCode,
  Logger,
  Post,
  Query,
} from '@nestjs/common';
import * as h3 from 'h3-js';
import { DatabaseService } from '../../database/database.service';
import { RoadGraphService } from './road-graph.service';
import { PathfindingService } from './pathfinding.service';
import { TrafficService } from './traffic.service';
import { NavigationService } from './navigation.service';
import { TelemetryService } from './telemetry.service';
import { RouteRequestDto, RerouteRequestDto, TelemetryDto } from './dto/routing.dto';

/** Route cache TTL in ms (aligns with ROUTE_CACHE_TTL_MIN = 15 min in model_parameters) */
const ROUTE_CACHE_TTL_MS = 15 * 60 * 1000;

/** In-memory route cache (origin_h3 + dest_h3 + hour -> result) */
const routeCache = new Map<string, { data: unknown; expiresAt: number }>();

@Controller('navigation')
export class RoutingController {
  private readonly logger = new Logger(RoutingController.name);

  constructor(
    private readonly roadGraph: RoadGraphService,
    private readonly pathfinding: PathfindingService,
    private readonly traffic: TrafficService,
    private readonly navigation: NavigationService,
    private readonly telemetry: TelemetryService,
    private readonly db: DatabaseService,
  ) {}

  /**
   * POST /navigation/route
   * Compute an optimal route between two points (Prompt 30).
   * Returns route_polyline, navigation_steps, travel_time, risk_score.
   */
  @Post('route')
  @HttpCode(200)
  async computeRoute(@Body() dto: RouteRequestDto) {
    const graph = dto.mode === 'highway' ? this.roadGraph.getHighwayGraph() : this.roadGraph.getGraph();

    // City-level route cache (Prompt 21)
    const originH3 = h3.latLngToCell(dto.origin.lat, dto.origin.lng, 6);
    const destH3 = h3.latLngToCell(dto.destination.lat, dto.destination.lng, 6);
    const hour = new Date().getUTCHours();
    const cacheKey = `${originH3}:${destH3}:${hour}`;

    const cached = routeCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return { ...(cached.data as object), cached: true };
    }

    // Find nearest nodes (graceful fallback if graph is empty)
    const originNode = this.roadGraph.findNearestNode(dto.origin.lat, dto.origin.lng, graph);
    const destNode = this.roadGraph.findNearestNode(dto.destination.lat, dto.destination.lng, graph);

    if (!originNode || !destNode) {
      return this.fallbackRoute(dto);
    }

    const weights = this.pathfinding.resolveWeights(
      dto.mode,
      dto.timeWeight,
      dto.distanceWeight,
      dto.riskWeight,
    );

    const k = Math.min(dto.candidates ?? 1, 5);

    // Multi-route candidate generation (Prompt 19)
    const candidates = this.pathfinding.kShortestPaths(graph, originNode.id, destNode.id, k, weights);

    if (candidates.length === 0) {
      return this.fallbackRoute(dto);
    }

    // Build navigation for best route
    const bestPath = candidates[0];
    const nav = await this.navigation.buildNavigation(bestPath);

    const result = {
      routes: await Promise.all(candidates.map(async (path, idx) => {
        const pathNav = idx === 0 ? nav : await this.navigation.buildNavigation(path);
        return {
          routeId: `R${idx + 1}`,
          rank: idx + 1,
          distanceM: Math.round(path.distanceM),
          travelTimeS: Math.round(path.travelTimeS),
          riskScore: Number(path.riskScore.toFixed(4)),
          cost: Number(path.cost.toFixed(4)),
          routePolyline: pathNav.routePolyline,
          navigationSteps: pathNav.steps,
          estimatedArrivalIso: pathNav.estimatedArrivalIso,
          riskExplanations: pathNav.riskExplanations,
        };
      })),
      origin: dto.origin,
      destination: dto.destination,
      requestedMode: dto.mode ?? 'balanced',
      cached: false,
    };

    // Cache result (Prompt 21) — TTL aligned with ROUTE_CACHE_TTL_MIN parameter
    routeCache.set(cacheKey, { data: result, expiresAt: Date.now() + ROUTE_CACHE_TTL_MS });

    // Persist to route_cache table for analytics
    this.db.query(
      `INSERT INTO route_cache (origin_h3, destination_h3, time_of_day, route_data, expires_at)
       VALUES ($1, $2, $3, $4::jsonb, now() + interval '15 minutes')
       ON CONFLICT (origin_h3, destination_h3, time_of_day) DO UPDATE SET
         route_data = EXCLUDED.route_data,
         hit_count  = route_cache.hit_count + 1,
         expires_at = EXCLUDED.expires_at`,
      [originH3, destH3, hour, JSON.stringify(result)],
    ).catch(() => { /* non-critical */ });

    return result;
  }

  /**
   * POST /navigation/reroute
   * Reroute in response to traffic disruptions (Prompt 12).
   */
  @Post('reroute')
  @HttpCode(200)
  async reroute(@Body() dto: RerouteRequestDto) {
    this.logger.log(`[REROUTE] reason=${dto.reason ?? 'unspecified'}`);

    // Invalidate cache for origin cell
    const originH3 = h3.latLngToCell(dto.currentPosition.lat, dto.currentPosition.lng, 6);
    const destH3 = h3.latLngToCell(dto.destination.lat, dto.destination.lng, 6);
    const hour = new Date().getUTCHours();
    routeCache.delete(`${originH3}:${destH3}:${hour}`);

    // Resolve reroute using current traffic state
    return this.computeRoute({
      origin: dto.currentPosition,
      destination: dto.destination,
      mode: 'balanced',
      candidates: 3,
    });
  }

  /**
   * GET /navigation/traffic
   * Return current traffic state and active incidents (Prompt 9, 12).
   */
  @Get('traffic')
  async getTraffic(@Query('h3Index') h3Index?: string) {
    const [congestion, incidents, hazards] = await Promise.all([
      this.traffic.getCongestionSummary(),
      this.traffic.getActiveIncidents(),
      this.traffic.getActiveHazards(),
    ]);

    const filteredIncidents = h3Index
      ? incidents.filter(i => i.h3Index === h3Index)
      : incidents;

    return {
      congestion,
      incidents: filteredIncidents.slice(0, 50),
      hazards: hazards.slice(0, 50),
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * GET /navigation/eta
   * Estimate arrival time for a route (Prompt 28).
   */
  @Get('eta')
  async getEta(
    @Query('originLat') originLat: string,
    @Query('originLng') originLng: string,
    @Query('destLat') destLat: string,
    @Query('destLng') destLng: string,
  ) {
    const olat = parseFloat(originLat);
    const olng = parseFloat(originLng);
    const dlat = parseFloat(destLat);
    const dlng = parseFloat(destLng);

    if ([olat, olng, dlat, dlng].some(isNaN)) {
      return { error: 'Invalid coordinates' };
    }

    const graph = this.roadGraph.getGraph();
    const originNode = this.roadGraph.findNearestNode(olat, olng, graph);
    const destNode = this.roadGraph.findNearestNode(dlat, dlng, graph);

    if (!originNode || !destNode) {
      // Fallback: simple haversine estimate
      const distKm = this.haversineKm(olat, olng, dlat, dlng);
      const travelTimeS = (distKm / 40) * 3600;
      return {
        travelTimeS: Math.round(travelTimeS),
        estimatedArrivalIso: new Date(Date.now() + travelTimeS * 1000).toISOString(),
        distanceM: Math.round(distKm * 1000),
        trafficDelayS: 0,
        source: 'fallback',
      };
    }

    const path = this.pathfinding.aStar(graph, originNode.id, destNode.id);
    if (!path) {
      return { error: 'No route found' };
    }

    const eta = await this.navigation.computeEta(path);
    return { ...eta, source: 'graph' };
  }

  /**
   * POST /navigation/telemetry
   * Ingest vehicle GPS/speed/heading (Prompt 25).
   */
  @Post('telemetry')
  @HttpCode(202)
  async ingestTelemetry(@Body() dto: TelemetryDto) {
    const result = await this.telemetry.ingest(dto);
    return { status: 'accepted', ...result };
  }

  // Fallback route when graph is empty or disconnected
  private fallbackRoute(dto: RouteRequestDto) {
    const distKm = this.haversineKm(
      dto.origin.lat, dto.origin.lng,
      dto.destination.lat, dto.destination.lng,
    );
    const travelTimeS = (distKm / 40) * 3600;
    return {
      routes: [{
        routeId: 'R1',
        rank: 1,
        distanceM: Math.round(distKm * 1000),
        travelTimeS: Math.round(travelTimeS),
        riskScore: 0,
        cost: travelTimeS,
        routePolyline: [[dto.origin.lng, dto.origin.lat], [dto.destination.lng, dto.destination.lat]],
        navigationSteps: [
          { stepIndex: 0, instruction: 'Proceed to destination', distanceM: Math.round(distKm * 1000), durationS: Math.round(travelTimeS) },
        ],
        estimatedArrivalIso: new Date(Date.now() + travelTimeS * 1000).toISOString(),
        riskExplanations: ['Route computed using straight-line fallback — road graph not yet loaded'],
      }],
      origin: dto.origin,
      destination: dto.destination,
      requestedMode: dto.mode ?? 'balanced',
      cached: false,
      fallback: true,
    };
  }

  private haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 6371;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLng = ((lng2 - lng1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLng / 2) * Math.sin(dLng / 2);
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}
