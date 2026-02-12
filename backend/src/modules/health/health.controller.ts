import { Controller, Get } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Controller('health')
export class HealthController {
  constructor(private readonly databaseService: DatabaseService) {}

  @Get()
  async health() {
    await this.databaseService.healthCheck();
    return { status: 'ok', db: 'up' };
  }
}
