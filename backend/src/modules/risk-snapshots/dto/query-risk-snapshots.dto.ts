import { IsISO8601, IsNumberString, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class QueryRiskSnapshotsDto {
  @IsISO8601()
  start_time!: string;

  @IsISO8601()
  end_time!: string;

  @IsNumberString()
  minLat!: string;

  @IsNumberString()
  maxLat!: string;

  @IsNumberString()
  minLng!: string;

  @IsNumberString()
  maxLng!: string;

  @IsOptional()
  @Type(() => Number)
  @Min(1)
  @Max(50000)
  limit?: number = 10000;
}
