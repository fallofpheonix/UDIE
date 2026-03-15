import { Type } from 'class-transformer';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export class IngestSensorStreamDto {
  @IsString()
  city_id!: string;

  @IsIn(['LOOP_DETECTOR', 'CAMERA_SENSOR', 'VEHICLE_TELEMETRY', 'GPS_DATA'])
  source_type!: 'LOOP_DETECTOR' | 'CAMERA_SENSOR' | 'VEHICLE_TELEMETRY' | 'GPS_DATA';

  @IsOptional()
  @IsString()
  topic?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  partition?: number;

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

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  vehicle_count!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  average_speed!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(1.5)
  traffic_density!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(1.5)
  disruption_weight = 0;

  @IsOptional()
  @IsString()
  observed_at?: string;
}
