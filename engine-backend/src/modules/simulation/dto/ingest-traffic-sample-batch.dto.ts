import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, ValidateNested } from 'class-validator';
import { IngestTrafficSampleDto } from './ingest-traffic-sample.dto';

export class IngestTrafficSampleBatchDto {
  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => IngestTrafficSampleDto)
  samples!: IngestTrafficSampleDto[];
}
