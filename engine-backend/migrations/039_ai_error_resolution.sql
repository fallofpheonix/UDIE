-- Migration 039: AI Error Resolution
-- Adds AI-driven suggestion support to the system observability layer.

ALTER TABLE system_errors ADD COLUMN IF NOT EXISTS ai_suggestion TEXT;

COMMENT ON COLUMN system_errors.ai_suggestion IS 'AI-generated fix recommendation based on error context and historical patterns.';
