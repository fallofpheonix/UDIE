import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class PredictDownstreamCongestionDto {
  @IsString()
  intersection_id!: string;

  @IsOptional()
  @IsString()
  city_id?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  horizon_steps = 3;
}
