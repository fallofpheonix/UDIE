import { Type } from 'class-transformer';
import { IsArray, IsNumber, IsString, MinLength, ValidateNested } from 'class-validator';

class CoordinateDto {
  @IsNumber()
  lat!: number;

  @IsNumber()
  lng!: number;
}

export class RouteRiskDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CoordinateDto)
  coordinates!: CoordinateDto[];

  @IsString()
  @MinLength(1)
  city!: string;
}
