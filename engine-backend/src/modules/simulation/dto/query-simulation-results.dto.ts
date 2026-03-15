import { IsOptional, IsString } from 'class-validator';

export class QuerySimulationResultsDto {
  @IsOptional()
  @IsString()
  run_id?: string;

  @IsOptional()
  @IsString()
  scenario_id?: string;
}
