import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

const disruptionTypes = ['ACCIDENT', 'ROAD_CLOSURE', 'CONSTRUCTION', 'EVENT_CONGESTION'] as const;
const propagationKernels = ['EXPONENTIAL', 'GAUSSIAN'] as const;

export class CreateDisruptionDto {
  @IsEnum(disruptionTypes)
  type!: string;

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

  @IsISO8601()
  start_time!: string;

  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(5)
  severity!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(5)
  @Max(1440)
  estimated_duration_minutes!: number;

  @IsArray()
  @ArrayMaxSize(128)
  @IsString({ each: true })
  affected_roads!: string[];

  @IsOptional()
  @IsEnum(propagationKernels)
  kernel: string = 'EXPONENTIAL';
}
