import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { SimulationController } from './simulation.controller';
import { SimulationService } from './simulation.service';

@Module({
  imports: [DatabaseModule],
  controllers: [SimulationController],
  providers: [SimulationService],
})
export class SimulationModule {}
