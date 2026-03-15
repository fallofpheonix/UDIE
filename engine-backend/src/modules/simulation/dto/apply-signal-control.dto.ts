import { IsOptional, IsString } from 'class-validator';

export class ApplySignalControlDto {
  @IsString()
  intersection_id!: string;

  @IsOptional()
  @IsString()
  city_id?: string;
}
