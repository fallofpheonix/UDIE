import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

export class LatLngDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat!: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  lng!: number;
}

export class RouteWeightsDto {
  @IsOptional()
  @IsNumber()
  @Min(0)
  distance?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  travel_time?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  risk?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  traffic?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  disruption?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  capacity?: number;
}

export class RouteOptionsDto {
  @ValidateNested()
  @Type(() => LatLngDto)
  origin!: LatLngDto;

  @ValidateNested()
  @Type(() => LatLngDto)
  destination!: LatLngDto;

  @IsOptional()
  @IsString()
  city_id?: string;

  @IsOptional()
  @IsIn(['DIJKSTRA', 'ASTAR'])
  strategy?: 'DIJKSTRA' | 'ASTAR';

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  alternatives?: number;

  @IsOptional()
  @ValidateNested()
  @Type(() => RouteWeightsDto)
  weights?: RouteWeightsDto;
}

export class RerouteDto extends RouteOptionsDto {
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => LatLngDto)
  current_route?: LatLngDto[];
}

export class TrafficQueryDto {
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  minLat!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  maxLat!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  minLng!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  maxLng!: number;

  @IsOptional()
  @IsString()
  city_id?: string;

  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(500)
  limit?: number;
}

export class EtaQueryDto extends RouteOptionsDto {}

export class RouteResponseWeightsDto {
  distance!: number;
  travelTime!: number;
  risk!: number;
  traffic!: number;
  disruption!: number;
  capacity!: number;
}
