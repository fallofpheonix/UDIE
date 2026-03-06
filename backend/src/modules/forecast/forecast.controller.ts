import { Controller, Get, Query } from '@nestjs/common';
import { ForecastService } from './forecast.service';

@Controller('forecast')
export class ForecastController {
    constructor(private readonly forecastService: ForecastService) { }

    @Get()
    async getForecast(@Query('h3_index') h3Index: string) {
        return this.forecastService.getForecast(h3Index);
    }
}
