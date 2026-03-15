import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export class InjectSyntheticEventDto {
  @IsString()
  scenario_id!: string;

  @IsString()
  scenario_type!: string;

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
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  severity = 3;

  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(5)
  @Max(1440)
  estimated_duration_minutes = 60;

  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(25)
  cluster_size = 1;

  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(6)
  radius_cells = 2;

  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(500000)
  attendee_count = 0;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(256)
  @IsString({ each: true })
  affected_roads?: string[];
}
