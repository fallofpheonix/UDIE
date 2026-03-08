import { Transform } from 'class-transformer';
import { IsEnum, IsNumber, IsOptional, Max, Min } from 'class-validator';

export class CreateEventDto {
    @Transform(({ value }) => typeof value === 'string' ? value.toUpperCase().trim() : value)
    @IsEnum(['TRAFFIC', 'WEATHER', 'CONVERSION', 'CRIME', 'INFRASTRUCTURE', 'TEST'])
    type!: string;

    @IsNumber()
    @Min(-90)
    @Max(90)
    lat!: number;

    @IsNumber()
    @Min(-180)
    @Max(180)
    lng!: number;

    @IsNumber()
    @Min(0)
    @Max(1)
    weight!: number;

    @IsOptional()
    @IsNumber()
    @Min(0)
    @Max(1)
    confidence?: number;
}
