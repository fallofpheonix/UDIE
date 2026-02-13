import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsNumber, IsString, Max, Min, MinLength, ValidateNested } from 'class-validator';

class CoordinateDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat!: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  lng!: number;
}

export class RouteRiskDto {
  @IsArray()
  @ArrayMinSize(2)
  @ValidateNested({ each: true })
  @Type(() => CoordinateDto)
  coordinates!: CoordinateDto[];

  @IsString()
  @MinLength(1)
  city!: string;
}
