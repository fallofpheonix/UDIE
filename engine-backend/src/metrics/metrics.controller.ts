import { Controller, Get, Res } from '@nestjs/common';
import { Response } from 'express';
import { MetricsService } from './metrics.service';
import { ObservabilityService } from '../modules/common/observability.service';

@Controller('metrics')
export class MetricsController {
    constructor(
        private readonly metrics: MetricsService,
        private readonly observability: ObservabilityService,
    ) { }

    @Get()
    async getMetrics(@Res() res: Response) {
        res.set('Content-Type', 'text/plain');
        const [registryMetrics, observabilityMetrics] = await Promise.all([
            this.metrics.getMetrics(),
            this.observability.getMetrics(),
        ]);
        res.send(`${registryMetrics}\n${observabilityMetrics}\n`);
    }
}
