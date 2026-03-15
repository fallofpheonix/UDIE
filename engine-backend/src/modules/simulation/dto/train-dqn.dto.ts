import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class TrainDqnDto {
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
  @Max(256)
  batch_size = 16;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(256)
  replay_capacity = 128;
}
