import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { DatabaseModule } from '../../database/database.module';
import { ReliabilityModule } from '../reliability/reliability.module';

@Module({
  imports: [DatabaseModule, ReliabilityModule],
  controllers: [HealthController],
})
export class HealthModule { }
