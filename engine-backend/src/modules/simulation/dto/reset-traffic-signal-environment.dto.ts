import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class ResetTrafficSignalEnvironmentDto {
  @IsOptional()
  @IsString()
  city_id?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(128)
  @IsString({ each: true })
  intersection_ids?: string[];

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(128)
  limit = 12;
}
