export interface GeoEventEntity {
  id: string;
  event_type: string;
  severity: number;
  confidence: number;
  status: string;
  source_id: string | null;
  description: string | null;
  observed_at: Date;
  expires_at: Date | null;
  last_observed: Date;
  h3_index: string | null;
  latitude: number;
  longitude: number;
}
