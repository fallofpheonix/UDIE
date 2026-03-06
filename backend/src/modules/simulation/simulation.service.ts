import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { CreateSimulationDto } from './dto/create-simulation.dto';

@Injectable()
export class SimulationService {
  constructor(private readonly db: DatabaseService) {}

  async injectSimulationEvent(dto: CreateSimulationDto) {
    const result = await this.db.query<QueryResultRow>(`
      INSERT INTO simulation_events (scenario_id, event_type, severity, lat, lng, created_at)
      VALUES ($1, $2, $3, $4, $5, now())
      RETURNING id, scenario_id, event_type, severity, lat, lng, created_at
    `, [dto.scenario_id, dto.event_type.toUpperCase(), dto.severity, dto.lat, dto.lng]);

    return result.rows[0];
  }

  async listScenario(scenarioId: string) {
    const result = await this.db.query<QueryResultRow>(`
      SELECT id, scenario_id, event_type, severity, lat, lng, created_at
      FROM simulation_events
      WHERE scenario_id = $1
      ORDER BY created_at DESC
      LIMIT 500
    `, [scenarioId]);

    return result.rows;
  }
}
