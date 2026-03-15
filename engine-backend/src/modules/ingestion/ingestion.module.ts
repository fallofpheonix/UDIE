import { Module } from '@nestjs/common';
import { IngestionService } from './ingestion.service';
import { DatabaseModule } from '../../database/database.module';
import { SocialEventParserService } from './social-event-parser.service';
import { SignalCredibilityService } from './signal-credibility.service';
import { AdversarialProtectionService } from './adversarial-protection.service';
import { SpatialModule } from '../common/spatial.module';
import { BloomDedupService } from './bloom-dedup.service';
import { IngestionController } from './ingestion.controller';
import { IngestionGateway } from './ingestion.gateway';

@Module({
  imports: [DatabaseModule, SpatialModule],
  controllers: [IngestionController],
  providers: [
    IngestionService,
    SocialEventParserService,
    SignalCredibilityService,
    AdversarialProtectionService,
    BloomDedupService,
    IngestionGateway,
  ],
  exports: [IngestionService],
})
export class IngestionModule { }
