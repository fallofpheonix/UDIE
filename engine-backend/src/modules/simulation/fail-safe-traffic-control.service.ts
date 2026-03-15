import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { ApplySignalControlDto } from './dto/apply-signal-control.dto';
import { RealTimeSignalControlService } from './real-time-signal-control.service';

@Injectable()
export class FailSafeTrafficControlService {
  constructor(
    private readonly db: DatabaseService,
    private readonly control: RealTimeSignalControlService,
  ) {}

  async dispatch(dto: ApplySignalControlDto) {
    try {
      const health = await this.db.query<{
        key: string;
        updated_at: Date | string;
      }>(
        `
          SELECT key, updated_at
          FROM system_state
          WHERE key IN ('digital_twin_tick_worker', 'materialization_worker')
        `,
      );

      const stale = health.rows.some((row) => {
        const updatedAt = new Date(String(row.updated_at)).getTime();
        return Number.isNaN(updatedAt) || Date.now() - updatedAt > 180_000;
      });
      if (stale) {
        throw new Error('worker_health_stale');
      }

      const result = await this.control.dispatch(dto);
      await this.setMode(dto.intersection_id, dto.city_id ?? null, 'AI_CONTROL', {
        reason: 'ai_control_ok',
        action: result.action,
      });
      return {
        ...result,
        mode: 'AI_CONTROL',
      };
    } catch (error) {
      const fallback = await this.activateFailSafe(dto, error instanceof Error ? error.message : 'unknown');
      return fallback;
    }
  }

  private async activateFailSafe(dto: ApplySignalControlDto, reason: string) {
    const schedule = await this.db.queryRead<{
      schedule_name: string;
      action: string;
      phase_duration_seconds: number;
      min_phase_seconds: number;
      max_phase_seconds: number;
      manual_override_enabled: boolean;
    }>(
      `
        SELECT
          schedule_name,
          action,
          phase_duration_seconds,
          min_phase_seconds,
          max_phase_seconds,
          manual_override_enabled
        FROM traffic_signal_fail_safe_profiles
        WHERE intersection_id = $1
           OR intersection_id = '*'
        ORDER BY CASE WHEN intersection_id = $1 THEN 0 ELSE 1 END
        LIMIT 1
      `,
      [dto.intersection_id],
    );

    const row = schedule.rows[0] ?? {
      schedule_name: 'default_safe_cycle',
      action: 'hold_phase',
      phase_duration_seconds: 45,
      min_phase_seconds: 20,
      max_phase_seconds: 60,
      manual_override_enabled: true,
    };

    const mode = row.manual_override_enabled ? 'MANUAL_CONTROL' : 'PREDEFINED_SCHEDULE';
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
        row.action,
        JSON.stringify({
          mode,
          scheduleName: row.schedule_name,
          phaseDurationSeconds: row.phase_duration_seconds,
          minPhaseSeconds: row.min_phase_seconds,
          maxPhaseSeconds: row.max_phase_seconds,
          failureReason: reason,
        }),
      ],
    );

    await this.setMode(dto.intersection_id, dto.city_id ?? null, mode, {
      reason,
      scheduleName: row.schedule_name,
    });

    return {
      intersectionId: dto.intersection_id,
      action: row.action,
      mode,
      withinTarget: true,
      failSafe: true,
      reason,
      scheduleName: row.schedule_name,
    };
  }

  private async setMode(intersectionId: string, cityId: string | null, mode: string, details: Record<string, unknown>) {
    await this.db.query(
      `
        INSERT INTO traffic_signal_control_modes (
          intersection_id,
          city_id,
          mode,
          details,
          activated_at
        )
        VALUES ($1, $2, $3, $4::jsonb, now())
        ON CONFLICT (intersection_id) DO UPDATE
        SET city_id = EXCLUDED.city_id,
            mode = EXCLUDED.mode,
            details = EXCLUDED.details,
            activated_at = now()
      `,
      [intersectionId, cityId, mode, JSON.stringify(details)],
    );
  }
}
