import { Controller, Get, Query } from '@nestjs/common';
import { IntelligenceService } from './IntelligenceService';

class IntelligenceQueryDto {
  regionId?: string;
  limit?: number;
}

@Controller('intelligence')
export class IntelligenceController {
  constructor(private readonly intelligenceService: IntelligenceService) {}

  @Get()
  listInsights(@Query() query: IntelligenceQueryDto) {
    return this.intelligenceService.listRecentInsights({
      regionId: query.regionId,
      limit:
        query.limit === undefined
          ? undefined
          : Number(query.limit),
    });
  }
}
