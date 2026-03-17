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
import { RoutingModule } from './modules/routing/routing.module';
import { DiagnosticsModule } from './modules/diagnostics/diagnostics.module';
import { SimulationModule } from './modules/simulation/simulation.module';
import { MetricsModule } from './metrics/metrics.module';

const NODE_ROLE = process.env.NODE_ROLE || 'ALL';
const roles = NODE_ROLE.toUpperCase().split(',');
const isAll = roles.includes('ALL');

const coreModules = [
  ConfigModule.forRoot({ isGlobal: true }),
  ScheduleModule.forRoot(),
  DatabaseModule,
  SpatialModule,
  HealthModule,
  UsersModule, // Needed for Auth on all nodes
  MetricsModule,
];

const ingestionModules = [IngestionModule];
const materializationModules = [RiskModule, SimulationModule, DiagnosticsModule, RiskSnapshotsModule];
const evaluationModules = [
  EventsModule,
  RouteOptionsModule,
  RoutingModule,
  CityDashboardModule,
  CellInsightModule,
  IntelligenceModule,
  ReliabilityModule,
  ForecastModule,
];

function getEnabledModules() {
  const enabled = [...coreModules];

  if (isAll || roles.includes('INGESTION')) {
    enabled.push(...ingestionModules);
  }
  if (isAll || roles.includes('MATERIALIZATION')) {
    enabled.push(...materializationModules);
  }
  if (isAll || roles.includes('EVALUATION')) {
    enabled.push(...evaluationModules);
  }

  return enabled;
}

@Module({
  imports: getEnabledModules(),
})
export class AppModule { }
