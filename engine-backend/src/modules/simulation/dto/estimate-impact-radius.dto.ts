import { Type } from 'class-transformer';
import { IsArray, IsInt, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export class EstimateImpactRadiusDto {
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(5)
  severity!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(1.5)
  trafficDensity!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng!: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  affectedRoads?: string[];

  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(6)
  maxRings = 4;
}
