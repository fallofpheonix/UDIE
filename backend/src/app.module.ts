import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { DatabaseModule } from './database/database.module';
import { EventsModule } from './modules/events/events.module';
import { RiskModule } from './modules/risk/risk.module';
import { IngestionModule } from './modules/ingestion/ingestion.module';
import { HealthModule } from './modules/health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    EventsModule,
    RiskModule,
    IngestionModule,
    HealthModule,
  ],
})
export class AppModule {}
