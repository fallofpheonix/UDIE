import { Type } from 'class-transformer';
import { IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export class QueryEventsDto {
  @Type(() => Number)
  @IsNumber()
  minLat!: number;

  @Type(() => Number)
  @IsNumber()
  maxLat!: number;

  @Type(() => Number)
  @IsNumber()
  minLng!: number;

  @Type(() => Number)
  @IsNumber()
  maxLng!: number;

  @IsOptional()
  @IsString()
  eventTypes?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(5)
  minSeverity?: number;
}
