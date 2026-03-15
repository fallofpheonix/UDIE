import { Type } from 'class-transformer';
import { IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export class RegisterNationalRegionDto {
  @IsString()
  region_id!: string;

  @IsString()
  region_name!: string;

  @IsString()
  cluster_endpoint!: string;

  @IsOptional()
  @IsString()
  city_id?: string;

  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  min_lat!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  min_lng!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  max_lat!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  max_lng!: number;
}
