import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { ForecastService } from './forecast.service';
import { ForecastController } from './forecast.controller';
import { ForecastingWorker } from './forecast.worker';

@Module({
    imports: [DatabaseModule],
    providers: [ForecastService, ForecastingWorker],
    controllers: [ForecastController],
    exports: [ForecastService],
})
export class ForecastModule { }
