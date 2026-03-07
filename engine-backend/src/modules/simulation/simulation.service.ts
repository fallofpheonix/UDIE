import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { CreateSimulationDto } from './dto/create-simulation.dto';

@Injectable()
export class SimulationService {
  constructor(private readonly db: DatabaseService) { }

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

  async clearScenario(scenarioId: string) {
    const result = await this.db.query<{ count: number }>(`
      DELETE FROM simulation_events WHERE scenario_id = $1
      RETURNING 1
    `, [scenarioId]);
    return { deleted: result.rows.length };
  }

  async runScenario(scenarioId: string, eventType: string, count: number, baseLat: number, baseLng: number) {
    const events = [];
    for (let i = 0; i < count; i++) {
      // Generate a small jitter (approx 500m)
      const latJitter = (Math.random() - 0.5) * 0.01;
      const lngJitter = (Math.random() - 0.5) * 0.01;

      events.push(this.injectSimulationEvent({
        scenario_id: scenarioId,
        event_type: eventType,
        severity: Math.floor(Math.random() * 5) + 1,
        lat: baseLat + latJitter,
        lng: baseLng + lngJitter,
      }));
    }
    return Promise.all(events);
  }
}
