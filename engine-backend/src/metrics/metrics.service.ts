import { Injectable } from '@nestjs/common';
import * as client from 'prom-client';

@Injectable()
export class MetricsService {
    private registry = new client.Registry();

    constructor() {
        client.collectDefaultMetrics({ register: this.registry });
    }

    getMetrics() {
        return this.registry.metrics();
    }

    // Custom UDIE Metrics
    private routeRiskHistogram = new client.Histogram({
        name: 'udie_route_risk_latency_ms',
        help: 'Route risk evaluation latency in milliseconds',
        buckets: [1, 5, 10, 50, 100, 500],
        registers: [this.registry],
    });

    private eventIngestionCounter = new client.Counter({
        name: 'udie_event_ingestion_total',
        help: 'Total number of disruption events ingested',
        registers: [this.registry],
    });

    trackRouteLatency(ms: number) {
        this.routeRiskHistogram.observe(ms);
    }

    trackEventIngested() {
        this.eventIngestionCounter.inc();
    }
}
