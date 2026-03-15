import { IsOptional, IsString } from 'class-validator';

export class BuildIntersectionGraphDto {
  @IsOptional()
  @IsString()
  city_id?: string;
}
