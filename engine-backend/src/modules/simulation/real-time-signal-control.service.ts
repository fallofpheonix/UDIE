import { Injectable } from '@nestjs/common';
import { performance } from 'perf_hooks';
import { DatabaseService } from '../../database/database.service';
import { ApplySignalControlDto } from './dto/apply-signal-control.dto';
import { IntersectionCoordinationService } from './intersection-coordination.service';

@Injectable()
export class RealTimeSignalControlService {
  constructor(
    private readonly db: DatabaseService,
    private readonly coordination: IntersectionCoordinationService,
  ) {}

  async dispatch(dto: ApplySignalControlDto) {
    const started = performance.now();
    const coordination = await this.coordination.coordinate(dto.city_id);
    const command = coordination.coordinatedActions.find(
      (entry) => entry.intersectionId === dto.intersection_id,
    );
    if (!command) {
      throw new Error(`no coordinated command for ${dto.intersection_id}`);
    }

    await this.db.query(
      `
        INSERT INTO traffic_signal_control_commands (
          intersection_id,
          city_id,
          command_action,
          payload,
          dispatched_at
        )
        VALUES ($1, $2, $3, $4::jsonb, now())
      `,
      [
        dto.intersection_id,
        dto.city_id ?? null,
        command.action,
        JSON.stringify(command),
      ],
    );

    const latencyMs = Number((performance.now() - started).toFixed(3));
    return {
      intersectionId: dto.intersection_id,
      action: command.action,
      latencyMs,
      withinTarget: latencyMs < 2000,
    };
  }
}
