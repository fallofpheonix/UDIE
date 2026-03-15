import { Type } from 'class-transformer';
import { IsArray, IsInt, IsOptional, ValidateNested } from 'class-validator';
import { InjectSyntheticEventDto } from './inject-synthetic-event.dto';

class SimulationBoundsDto {
  @Type(() => Number)
  minLat!: number;

  @Type(() => Number)
  maxLat!: number;

  @Type(() => Number)
  minLng!: number;

  @Type(() => Number)
  maxLng!: number;
}

export class SimulateEventDto extends InjectSyntheticEventDto {
  @ValidateNested()
  @Type(() => SimulationBoundsDto)
  bounds!: SimulationBoundsDto;

  @IsOptional()
  @IsArray()
  @Type(() => Number)
  @IsInt({ each: true })
  horizons = [15, 30, 60];
}
