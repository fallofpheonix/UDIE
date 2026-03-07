import { Controller, Get, Query } from '@nestjs/common';
import { ReliabilityService, ReliabilityInsight } from './reliability.service';

@Controller('api/reliability')
export class ReliabilityController {
    constructor(private readonly reliabilityService: ReliabilityService) { }

    @Get()
    async getReliability(
        @Query('minLat') minLat: string,
        @Query('minLng') minLng: string,
        @Query('maxLat') maxLat: string,
        @Query('maxLng') maxLng: string,
    ): Promise<ReliabilityInsight[]> {
        return this.reliabilityService.getRegionalReliability(
            parseFloat(minLat),
            parseFloat(minLng),
            parseFloat(maxLat),
            parseFloat(maxLng),
        );
    }

    @Get('ai-insights')
    async getAIInsights() {
        return this.reliabilityService.getAIInsights();
    }
}
