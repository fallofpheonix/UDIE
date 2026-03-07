import { Module } from '@nestjs/common';
import { IngestionService } from './ingestion.service';
import { DatabaseModule } from '../../database/database.module';
import { SocialEventParserService } from './social-event-parser.service';
import { SignalCredibilityService } from './signal-credibility.service';
import { AdversarialProtectionService } from './adversarial-protection.service';
import { SpatialModule } from '../common/spatial.module';
import { EventsModule } from '../events/events.module';

@Module({
  imports: [DatabaseModule, SpatialModule, EventsModule],
  providers: [
    IngestionService,
    SocialEventParserService,
    SignalCredibilityService,
    AdversarialProtectionService,
  ],
  exports: [IngestionService],
})
export class IngestionModule { }
