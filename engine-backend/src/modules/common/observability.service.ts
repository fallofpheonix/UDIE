import { Injectable } from '@nestjs/common';

@Injectable()
export class ObservabilityService {
  private readonly gauges = {
    risk_grid_size: 0,
  };

  private readonly histograms = {
    risk_eval_latency: [] as number[],
    risk_grid_refresh_time: [] as number[],
  };

  private readonly counters = {
    events_ingested_total: 0,
  };

  public eventsIngested = {
    inc: (_labels: Record<string, string>) => {
      this.counters.events_ingested_total += 1;
    },
  };

  observeRiskEvalLatency(seconds: number): void {
    if (Number.isFinite(seconds) && seconds >= 0) {
      this.histograms.risk_eval_latency.push(seconds);
    }
  }

  setRiskGridSize(size: number): void {
    if (Number.isFinite(size) && size >= 0) {
      this.gauges.risk_grid_size = size;
    }
  }

  observeRiskGridRefreshTime(seconds: number): void {
    if (Number.isFinite(seconds) && seconds >= 0) {
      this.histograms.risk_grid_refresh_time.push(seconds);
    }
  }

  async getMetrics(): Promise<string> {
    const avg = (arr: number[]): number => {
      if (arr.length === 0) return 0;
      return arr.reduce((a, b) => a + b, 0) / arr.length;
    };

    return [
      '# TYPE udie_risk_grid_size gauge',
      `udie_risk_grid_size ${this.gauges.risk_grid_size}`,
      '# TYPE udie_events_ingested_total counter',
      `udie_events_ingested_total ${this.counters.events_ingested_total}`,
      '# TYPE udie_risk_eval_latency_seconds_avg gauge',
      `udie_risk_eval_latency_seconds_avg ${avg(this.histograms.risk_eval_latency)}`,
      '# TYPE udie_risk_grid_refresh_time_seconds_avg gauge',
      `udie_risk_grid_refresh_time_seconds_avg ${avg(this.histograms.risk_grid_refresh_time)}`,
    ].join('\n');
  }

  snapshot(): {
    riskEvalLatencyAvgSec: number;
    riskGridRefreshAvgSec: number;
    eventsIngestedTotal: number;
    riskGridSize: number;
  } {
    const avg = (arr: number[]): number => {
      if (arr.length === 0) return 0;
      return arr.reduce((a, b) => a + b, 0) / arr.length;
    };

    return {
      riskEvalLatencyAvgSec: avg(this.histograms.risk_eval_latency),
      riskGridRefreshAvgSec: avg(this.histograms.risk_grid_refresh_time),
      eventsIngestedTotal: this.counters.events_ingested_total,
      riskGridSize: this.gauges.risk_grid_size,
    };
  }
}
