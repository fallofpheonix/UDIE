import { IsNumber, IsString, Max, Min } from 'class-validator';

export class CreateSimulationDto {
  @IsString()
  event_type!: string;

  @IsNumber()
  @Min(1)
  @Max(5)
  severity!: number;

  @IsNumber()
  @Min(-90)
  @Max(90)
  lat!: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  lng!: number;

  @IsString()
  scenario_id!: string;
}
