import { Type } from 'class-transformer';
import {
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export class IngestTrafficSampleDto {
  @IsOptional()
  @IsString()
  city_id = 'default';

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
  traffic_density!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  average_speed!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  vehicle_count!: number;

  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  disruption_weight = 0;

  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(360)
  heading_degrees?: number;

  @IsOptional()
  @IsISO8601()
  observed_at?: string;
}
