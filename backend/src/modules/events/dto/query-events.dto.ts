import { IsNumberString, IsOptional, IsString, Matches, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class QueryEventsDto {
  @IsNumberString()
  minLat!: string;

  @IsNumberString()
  maxLat!: string;

  @IsNumberString()
  minLng!: string;

  @IsNumberString()
  maxLng!: string;

  @IsOptional()
  @IsString()
  eventTypes?: string;

  @IsOptional()
  @IsString()
  regionId?: string;

  @IsOptional()
  @IsNumberString()
  @Matches(/^[1-5]$/, { message: 'minSeverity must be between 1 and 5' })
  minSeverity?: string;

  @IsOptional()
  @Type(() => Number)
  @Min(1)
  @Max(1000)
  limit?: number = 100;

  @IsOptional()
  @Type(() => Number)
  @Min(0)
  offset?: number = 0;
}
