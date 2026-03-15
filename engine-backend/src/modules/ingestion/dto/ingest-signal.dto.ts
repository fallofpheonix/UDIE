import { IsLatitude, IsLongitude, IsNumber, IsObject, IsOptional, IsString, Max, Min } from 'class-validator';

export class IngestSignalDto {
  @IsString()
  sourceId!: string;

  @IsString()
  sourceCategory!: string;

  @IsLatitude()
  lat!: number;

  @IsLongitude()
  lng!: number;

  @IsString()
  eventType!: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(5)
  severity?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  confidence?: number;

  @IsOptional()
  @IsString()
  observedAt?: string;

  @IsOptional()
  @IsString()
  text?: string;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}
