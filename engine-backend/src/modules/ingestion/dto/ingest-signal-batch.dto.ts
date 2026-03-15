import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, ValidateNested } from 'class-validator';
import { IngestSignalDto } from './ingest-signal.dto';

export class IngestSignalBatchDto {
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => IngestSignalDto)
  signals!: IngestSignalDto[];
}
