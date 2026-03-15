import { Type } from 'class-transformer';
import { IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export class GenerateRiskSurfaceDto {
  @IsOptional()
  @IsString()
  city_id = 'default';

  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  minLat!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  maxLat!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  minLng!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  maxLng!: number;

  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(60)
  horizon_minutes = 0;
}
