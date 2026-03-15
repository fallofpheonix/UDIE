import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class TrainPpoDto {
  @IsOptional()
  @IsString()
  city_id?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(4)
  @Max(256)
  episodes = 24;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(4)
  @Max(256)
  max_steps = 24;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(16)
  epochs = 4;
}
