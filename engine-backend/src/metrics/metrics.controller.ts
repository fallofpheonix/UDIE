import { Controller, Get, Res } from '@nestjs/common';
import { Response } from 'express';
import { MetricsService } from './metrics.service';

@Controller('metrics')
export class MetricsController {
    constructor(private metrics: MetricsService) { }

    @Get()
    async getMetrics(@Res() res: Response) {
        res.set('Content-Type', 'text/plain');
        res.send(await this.metrics.getMetrics());
    }
}
