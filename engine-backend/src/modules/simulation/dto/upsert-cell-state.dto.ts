import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export class UpsertCellStateDto {
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
  disruption_weight!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  vehicle_count!: number;

  @IsOptional()
  @IsISO8601()
  timestamp?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(256)
  @IsString({ each: true })
  road_segments?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(256)
  @IsString({ each: true })
  intersection_ids?: string[];
}
