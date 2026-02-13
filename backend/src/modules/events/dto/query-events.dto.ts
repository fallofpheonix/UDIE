import { IsNumberString, IsOptional, IsString, Matches } from 'class-validator';

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
  city?: string;

  @IsOptional()
  @IsString()
  eventTypes?: string;

  @IsOptional()
  @IsNumberString()
  @Matches(/^[1-5]$/, { message: 'minSeverity must be between 1 and 5' })
  minSeverity?: string;
}
