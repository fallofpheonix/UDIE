import { Controller, Get, Query } from '@nestjs/common';
import { QueryCellInsightDto } from './dto/query-cell-insight.dto';
import { CellInsightService } from './cell-insight.service';

@Controller('cell-insight')
export class CellInsightController {
  constructor(private readonly service: CellInsightService) {}

  @Get()
  getCellInsight(@Query() query: QueryCellInsightDto) {
    return this.service.getCellInsight(Number(query.lat), Number(query.lng));
  }
}
