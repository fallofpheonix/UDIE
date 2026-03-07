import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { RiskModule } from '../risk/risk.module';
import { RouteOptionsController } from './route-options.controller';
import { RouteOptionsService } from './route-options.service';

@Module({
  imports: [DatabaseModule, RiskModule],
  controllers: [RouteOptionsController],
  providers: [RouteOptionsService],
})
export class RouteOptionsModule {}
