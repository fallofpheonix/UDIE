import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { GenerateRiskSurfaceDto } from './generate-risk-surface.dto';

export class SimulateFutureHorizonDto extends GenerateRiskSurfaceDto {
  @IsOptional()
  @IsString()
  scenario_id?: string;

  @IsArray()
  @ArrayMaxSize(8)
  @Type(() => Number)
  @IsInt({ each: true })
  @Min(5, { each: true })
  @Max(240, { each: true })
  horizons = [15, 30, 60];
}
