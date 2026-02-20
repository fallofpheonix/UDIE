import { Module } from '@nestjs/common';
import { IngestionService } from './ingestion.service';
import { DatabaseModule } from '../../database/database.module';
import { SocialEventParserService } from './social-event-parser.service';

@Module({
  imports: [DatabaseModule],
  providers: [IngestionService, SocialEventParserService],
  exports: [IngestionService],
})
export class IngestionModule { }
