import { IsNumber, Max, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

class LatLngDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat!: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  lng!: number;
}

export class RouteOptionsDto {
  @ValidateNested()
  @Type(() => LatLngDto)
  origin!: LatLngDto;

  @ValidateNested()
  @Type(() => LatLngDto)
  destination!: LatLngDto;
}
