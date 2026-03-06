import { IsNumberString } from 'class-validator';

export class QueryCellInsightDto {
  @IsNumberString()
  lat!: string;

  @IsNumberString()
  lng!: string;
}
