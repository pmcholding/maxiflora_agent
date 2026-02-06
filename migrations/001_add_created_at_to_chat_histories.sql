-- Migration: Add created_at column to n8n_chat_histories_maxiflora
-- Purpose: Enable automatic cleanup of old chat history (> 3 days)
-- Database: draidbprod

-- 1. Add created_at column (if not exists)
ALTER TABLE n8n_chat_histories_maxiflora
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW();

-- 2. Create function to auto-populate created_at on INSERT
CREATE OR REPLACE FUNCTION set_created_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.created_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create trigger for INSERT (drop first if exists)
DROP TRIGGER IF EXISTS trigger_set_created_at ON n8n_chat_histories_maxiflora;
CREATE TRIGGER trigger_set_created_at
    BEFORE INSERT ON n8n_chat_histories_maxiflora
    FOR EACH ROW
    EXECUTE FUNCTION set_created_at_timestamp();

-- 4. Populate created_at for existing rows (set to 1 day ago as estimate)
UPDATE n8n_chat_histories_maxiflora
SET created_at = NOW() - INTERVAL '1 day'
WHERE created_at IS NULL;
