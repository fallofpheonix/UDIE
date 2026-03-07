import { Injectable, Logger } from '@nestjs/common';

export interface SocialPostInput {
  sourceId: string;
  observedAt?: string;
  text: string;
}

export interface ParsedSocialEvent {
  source_id: string;
  observed_at: string;
  lat: number;
  lng: number;
  event_type: string;
  severity_hint: number;
  text: string;
}

interface OpenAIEventResponse {
  lat: number;
  lng: number;
  event_type: string;
  severity_hint?: number;
  observed_at?: string;
}

@Injectable()
export class SocialEventParserService {
  private readonly logger = new Logger(SocialEventParserService.name);
  private readonly openAIKey = process.env.OPENAI_API_KEY?.trim();
  private readonly openAIModel = process.env.OPENAI_MODEL?.trim() || 'gpt-4o-mini';
  private readonly allowedTypes = new Set([
    'ACCIDENT',
    'CONSTRUCTION',
    'METRO_WORK',
    'WATER_LOGGING',
    'PROTEST',
    'HEAVY_TRAFFIC',
    'ROAD_BLOCK',
  ]);

  async parse(post: SocialPostInput): Promise<ParsedSocialEvent | null> {
    const fromLLM = await this.parseWithLLM(post);
    if (fromLLM) {
      return fromLLM;
    }
    return this.parseWithHeuristics(post);
  }

  private async parseWithLLM(post: SocialPostInput): Promise<ParsedSocialEvent | null> {
    if (!this.openAIKey) {
      return null;
    }

    try {
      const payload = {
        model: this.openAIModel,
        response_format: { type: 'json_object' },
        temperature: 0,
        messages: [
          {
            role: 'system',
            content:
              'Extract a traffic disruption event from social text and return strict JSON with keys: lat, lng, event_type, severity_hint, observed_at. event_type must be one of ACCIDENT, CONSTRUCTION, METRO_WORK, WATER_LOGGING, PROTEST, HEAVY_TRAFFIC, ROAD_BLOCK. severity_hint is integer 1..5.',
          },
          {
            role: 'user',
            content: `source_id=${post.sourceId}\nobserved_at=${post.observedAt ?? ''}\ntext=${post.text}`,
          },
        ],
      };

      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.openAIKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        this.logger.warn(`LLM parser HTTP ${response.status}; falling back to heuristic parser`);
        return null;
      }

      const body = (await response.json()) as {
        choices?: Array<{ message?: { content?: string } }>;
      };

      const content = body.choices?.[0]?.message?.content;
      if (!content) {
        return null;
      }

      const parsed = JSON.parse(content) as OpenAIEventResponse;
      const normalized = this.normalizeParsedEvent(post, parsed);
      if (!normalized) {
        this.logger.warn(`LLM parser produced invalid event payload for source ${post.sourceId}`);
      }
      return normalized;
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`LLM parser failed: ${message}; using heuristic parser`);
      return null;
    }
  }

  private parseWithHeuristics(post: SocialPostInput): ParsedSocialEvent | null {
    const text = post.text.trim();
    if (!text) {
      return null;
    }

    const coordinateMatch = text.match(/(-?\d{1,2}\.\d+)\s*[, ]\s*(-?\d{1,3}\.\d+)/);
    if (!coordinateMatch) {
      return null;
    }

    const lat = Number(coordinateMatch[1]);
    const lng = Number(coordinateMatch[2]);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return null;
    }

    const lower = text.toLowerCase();
    let eventType = 'HEAVY_TRAFFIC';
    if (/accident|crash|collision/.test(lower)) eventType = 'ACCIDENT';
    else if (/construction|repair|work zone/.test(lower)) eventType = 'CONSTRUCTION';
    else if (/metro|rail work/.test(lower)) eventType = 'METRO_WORK';
    else if (/flood|waterlogging/.test(lower)) eventType = 'WATER_LOGGING';
    else if (/protest|march|demonstration/.test(lower)) eventType = 'PROTEST';
    else if (/closed|closure|blocked|diversion/.test(lower)) eventType = 'ROAD_BLOCK';
    else if (/jam|congestion|traffic|slow/.test(lower)) eventType = 'HEAVY_TRAFFIC';

    const severityHint = this.extractSeverityHint(lower);

    return {
      source_id: post.sourceId,
      observed_at: this.normalizeObservedAt(post.observedAt),
      lat,
      lng,
      event_type: eventType,
      severity_hint: severityHint,
      text,
    };
  }

  private normalizeParsedEvent(
    post: SocialPostInput,
    parsed: OpenAIEventResponse,
  ): ParsedSocialEvent | null {
    const lat = Number(parsed.lat);
    const lng = Number(parsed.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return null;
    }

    const type = String(parsed.event_type ?? 'HEAVY_TRAFFIC').toUpperCase().trim();
    const eventType = this.allowedTypes.has(type) ? type : 'HEAVY_TRAFFIC';
    const severityHint = this.clampSeverity(parsed.severity_hint ?? 2);

    return {
      source_id: post.sourceId,
      observed_at: this.normalizeObservedAt(parsed.observed_at ?? post.observedAt),
      lat,
      lng,
      event_type: eventType,
      severity_hint: severityHint,
      text: post.text.trim(),
    };
  }

  private extractSeverityHint(text: string): number {
    if (/massive|major|severe|standstill|fatal/.test(text)) return 5;
    if (/heavy|badly|blocked|closure/.test(text)) return 4;
    if (/delay|slow/.test(text)) return 3;
    if (/minor|small/.test(text)) return 2;
    return 1;
  }

  private clampSeverity(value: number): number {
    const num = Number(value);
    if (!Number.isFinite(num)) return 2;
    if (num < 1) return 1;
    if (num > 5) return 5;
    return Math.round(num);
  }

  private normalizeObservedAt(value?: string): string {
    if (!value) {
      return new Date().toISOString();
    }
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
      return new Date().toISOString();
    }
    return parsed.toISOString();
  }
}
