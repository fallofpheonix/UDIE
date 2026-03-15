import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsIn, IsInt, IsOptional, IsString, Max, Min, ValidateNested } from 'class-validator';
import { signalActions } from '../traffic-signal.types';

class TrafficSignalActionDto {
  @IsString()
  intersection_id!: string;

  @IsIn(signalActions)
  action!: (typeof signalActions)[number];
}

export class StepTrafficSignalEnvironmentDto {
  @IsOptional()
  @IsString()
  episode_id?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  step_index = 0;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(3)
  @Max(30)
  tick_seconds = 5;

  @IsArray()
  @ArrayMaxSize(128)
  @ValidateNested({ each: true })
  @Type(() => TrafficSignalActionDto)
  actions!: TrafficSignalActionDto[];
}
