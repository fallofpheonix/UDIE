import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { DatabaseModule } from './database/database.module';
import { EventsModule } from './modules/events/events.module';
import { RiskModule } from './modules/risk/risk.module';
import { SpatialModule } from './modules/common/spatial.module';
import { IngestionModule } from './modules/ingestion/ingestion.module';
import { HealthModule } from './modules/health/health.module';
import { UsersModule } from './modules/users/users.module';
import { IntelligenceModule } from './intelligence/intelligence.module';
import { ReliabilityModule } from './modules/reliability/reliability.module';
import { ForecastModule } from './modules/forecast/forecast.module';
import { RiskSnapshotsModule } from './modules/risk-snapshots/risk-snapshots.module';
import { CityDashboardModule } from './modules/city-dashboard/city-dashboard.module';
import { CellInsightModule } from './modules/cell-insight/cell-insight.module';
import { RouteOptionsModule } from './modules/route-options/route-options.module';
import { DiagnosticsModule } from './modules/diagnostics/diagnostics.module';
import { SimulationModule } from './modules/simulation/simulation.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    DatabaseModule,
    EventsModule,
    RiskModule,
    IngestionModule,
    HealthModule,
    UsersModule,
    SpatialModule,
    IntelligenceModule,
    ReliabilityModule,
    ForecastModule,
    RiskSnapshotsModule,
    CityDashboardModule,
    CellInsightModule,
    RouteOptionsModule,
    DiagnosticsModule,
    SimulationModule,
  ],
})
export class AppModule { }
