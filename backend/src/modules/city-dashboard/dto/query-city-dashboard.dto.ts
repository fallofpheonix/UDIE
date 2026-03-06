import { IsNumberString, IsOptional } from 'class-validator';

export class QueryCityDashboardDto {
  @IsNumberString()
  minLat!: string;

  @IsNumberString()
  maxLat!: string;

  @IsNumberString()
  minLng!: string;

  @IsNumberString()
  maxLng!: string;

  @IsOptional()
  @IsNumberString()
  hotspotThreshold?: string;
}
