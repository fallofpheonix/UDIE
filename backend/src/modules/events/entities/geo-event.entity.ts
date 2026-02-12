export interface GeoEventEntity {
  id: string;
  event_type: string;
  severity: number;
  confidence: number;
  source: string;
  description: string | null;
  start_time: string;
  end_time: string | null;
  latitude: number;
  longitude: number;
}
