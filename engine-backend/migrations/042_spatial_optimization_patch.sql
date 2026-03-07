-- Migration 042: Optimization Patch for Spatial Kernels
-- Applied the optimizations from the audit to the running database.

-- Optimized Law 5 Diffusion Kernel
CREATE OR REPLACE FUNCTION diffuse_risk_field(p_leak_rate DOUBLE PRECISION, p_rounds INT DEFAULT 1)
RETURNS VOID AS $$
DECLARE
  v_i INT;
BEGIN
  FOR v_i IN 1..p_rounds LOOP
    INSERT INTO risk_cells (h3_index, weight, updated_at)
    WITH source_data AS (
        SELECT h3_index, weight FROM risk_cells
    ),
    leaked AS (
        SELECT
          (neighbor.cell)::bigint AS h3_index,
          SUM(weight * p_leak_rate / 6.0) AS leaked_weight
        FROM source_data
        CROSS JOIN LATERAL h3_grid_disk(h3_index::h3index, 1) AS neighbor(cell)
        WHERE neighbor.cell::bigint != h3_index
        GROUP BY 1
    ),
    retained AS (
        SELECT h3_index, weight * (1.0 - p_leak_rate) AS retained_weight
        FROM source_data
    )
    SELECT
      COALESCE(r.h3_index, l.h3_index) AS h3_index,
      COALESCE(r.retained_weight, 0) + COALESCE(l.leaked_weight, 0) AS weight,
      now()
    FROM retained r
    FULL OUTER JOIN leaked l ON r.h3_index = l.h3_index
    WHERE (COALESCE(r.retained_weight, 0) + COALESCE(l.leaked_weight, 0)) > 0.001
    ON CONFLICT (h3_index) DO UPDATE SET
      weight = EXCLUDED.weight,
      updated_at = EXCLUDED.updated_at;
  END LOOP;
  
  DELETE FROM risk_cells WHERE weight < 0.001;
END;
$$ LANGUAGE plpgsql;

-- Optimized Risk Surface Refresh
CREATE OR REPLACE FUNCTION refresh_risk_surface_v2()
RETURNS VOID AS $$
DECLARE
  v_alpha DOUBLE PRECISION;
  v_density_cap DOUBLE PRECISION;
  v_leak_rate DOUBLE PRECISION;
  v_rounds INT;
BEGIN
  SELECT COALESCE(value, 0.3) INTO v_alpha FROM model_parameters WHERE key = 'DENSITY_ALPHA';
  SELECT COALESCE(value, 3.0) INTO v_density_cap FROM model_parameters WHERE key = 'DENSITY_FACTOR_MAX';
  SELECT COALESCE(value::float, 0.15) INTO v_leak_rate FROM model_parameters WHERE key = 'DIFFUSION_LEAK_RATE';
  SELECT COALESCE(value::int, 1) INTO v_rounds FROM model_parameters WHERE key = 'DIFFUSION_ROUNDS';

  -- Optimized aggregation: Use a single join for neighbor density
  INSERT INTO risk_cells (h3_index, weight, updated_at)
  WITH active_events AS (
    SELECT h3_index, severity, confidence
    FROM geo_events
    WHERE status = 'ACTIVE'
      AND (expires_at IS NULL OR expires_at > now())
  ),
  event_counts AS (
    SELECT h3_index, count(*) as count, SUM(severity * confidence) as base_weight
    FROM active_events
    GROUP BY h3_index
  ),
  neighbor_density AS (
    -- Pre-calculate neighbor counts via spatial join
    SELECT 
        ec1.h3_index,
        SUM(ec2.count) as total_neighbor_events
    FROM event_counts ec1
    JOIN event_counts ec2 ON h3_grid_distance(ec1.h3_index::h3index, ec2.h3_index::h3index) <= 1
    GROUP BY ec1.h3_index
  )
  SELECT
    nd.h3_index,
    ec.base_weight * LEAST(
      v_density_cap,
      1 + (v_alpha * LN(1 + nd.total_neighbor_events))
    ) AS weight,
    now()
  FROM neighbor_density nd
  JOIN event_counts ec ON ec.h3_index = nd.h3_index
  ON CONFLICT (h3_index) DO UPDATE SET
    weight = EXCLUDED.weight,
    updated_at = EXCLUDED.updated_at;

  IF v_leak_rate > 0 THEN
    PERFORM diffuse_risk_field(v_leak_rate, v_rounds);
  END IF;
END;
$$ LANGUAGE plpgsql;
