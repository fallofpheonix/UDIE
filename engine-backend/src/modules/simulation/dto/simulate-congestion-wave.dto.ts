import { Type } from 'class-transformer';
import { IsInt, IsNumber, IsOptional, Max, Min } from 'class-validator';

export class SimulateCongestionWaveDto {
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng!: number;

  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1.5)
  arrivalRate = 0.3;

  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(6)
  horizonSteps = 3;
}
