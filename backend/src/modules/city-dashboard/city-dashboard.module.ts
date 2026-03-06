import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { CityDashboardController } from './city-dashboard.controller';
import { CityDashboardService } from './city-dashboard.service';

@Module({
  imports: [DatabaseModule],
  controllers: [CityDashboardController],
  providers: [CityDashboardService],
})
export class CityDashboardModule {}
