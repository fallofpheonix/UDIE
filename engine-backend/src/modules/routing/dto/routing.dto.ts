import {
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class GeoPointDto {
  @IsLatitude()
  lat!: number;

  @IsLongitude()
  lng!: number;
}

export class RouteRequestDto {
  @ValidateNested()
  @Type(() => GeoPointDto)
  origin!: GeoPointDto;

  @ValidateNested()
  @Type(() => GeoPointDto)
  destination!: GeoPointDto;

  /** Weighted combination mode: 'fastest' | 'shortest' | 'safest' | 'balanced' */
  @IsOptional()
  @IsString()
  mode?: string;

  /** Custom weight for travel_time (0–1). Overrides mode. */
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  timeWeight?: number;

  /** Custom weight for distance (0–1). Overrides mode. */
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  distanceWeight?: number;

  /** Custom weight for risk_score (0–1). Overrides mode. */
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  riskWeight?: number;

  /** Number of route candidates to return (1–5). */
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(5)
  candidates?: number;
}

export class RerouteRequestDto {
  @ValidateNested()
  @Type(() => GeoPointDto)
  currentPosition!: GeoPointDto;

  @ValidateNested()
  @Type(() => GeoPointDto)
  destination!: GeoPointDto;

  @IsOptional()
  @IsString()
  reason?: string;
}

export class TelemetryDto {
  @IsString()
  vehicleId!: string;

  @IsLatitude()
  lat!: number;

  @IsLongitude()
  lng!: number;

  @IsNumber()
  @Min(0)
  speedKmh!: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(360)
  heading?: number;
}
