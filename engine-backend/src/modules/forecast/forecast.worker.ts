import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ForecastService } from './forecast.service';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class ForecastingWorker {
    private readonly logger = new Logger(ForecastingWorker.name);

    constructor(
        private readonly forecastService: ForecastService,
        private readonly db: DatabaseService,
    ) { }

    @Cron('0 */10 * * * *')
    async rebuildAllForecasts() {
        this.logger.log('[FORECASTER] Starting forecast_cells rebuild...');

        try {
            const count = await this.forecastService.rebuildForecastCells();
            await this.db.query(`SELECT set_system_state($1, $2::jsonb)`, [
                'forecast_worker',
                JSON.stringify({
                    status: 'OK',
                    rebuilt_cells: count,
                    last_success_at: new Date().toISOString(),
                }),
            ]);
            this.logger.log(`[FORECASTER] Forecast rebuild complete. cells=${count}`);
        } catch (error: unknown) {
            this.logger.error(`[FORECASTER] Batch rebuild failed: ${error instanceof Error ? error.message : String(error)}`);
        }
    }
}
