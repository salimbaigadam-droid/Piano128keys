-- PostgreSQL Database Schema for 128-Key Piano Application
-- Ensures data persistence across sessions and restarts

-- Drop existing tables if they exist (for clean setup)
DROP TABLE IF EXISTS note_events CASCADE;
DROP TABLE IF EXISTS songs CASCADE;
DROP TABLE IF EXISTS analytics_cache CASCADE;
DROP TABLE IF EXISTS user_preferences CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Users Table
-- Stores user account information
CREATE TABLE users (
    user_id VARCHAR(255) PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_notes_played BIGINT DEFAULT 0,
    total_songs_saved INTEGER DEFAULT 0,
    CONSTRAINT email_format CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- User Preferences Table
-- Stores user settings and preferences
CREATE TABLE user_preferences (
    preference_id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES users(user_id) ON DELETE CASCADE,
    preferred_backend VARCHAR(50) DEFAULT 'python',
    default_volume FLOAT DEFAULT 0.5 CHECK (default_volume >= 0 AND default_volume <= 1),
    enable_reverb BOOLEAN DEFAULT true,
    enable_eq BOOLEAN DEFAULT true,
    auto_save BOOLEAN DEFAULT true,
    theme VARCHAR(50) DEFAULT 'dark',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- Songs Table
-- Stores saved compositions and recordings
CREATE TABLE songs (
    song_id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES users(user_id) ON DELETE CASCADE,
    song_name VARCHAR(255) NOT NULL,
    notes JSONB NOT NULL, -- Array of note numbers
    note_timings JSONB, -- Array of timestamps for each note
    duration_seconds FLOAT,
    metadata JSONB, -- Additional data (tempo, key signature, ML analysis, etc.)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    play_count INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT false,
    tags VARCHAR(255)[],
    CONSTRAINT valid_notes CHECK (jsonb_typeof(notes) = 'array')
);

-- Note Events Table
-- Stores individual note playing events for analytics
CREATE TABLE note_events (
    event_id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES users(user_id) ON DELETE CASCADE,
    key_number INTEGER NOT NULL CHECK (key_number >= 0 AND key_number < 128),
    velocity FLOAT NOT NULL CHECK (velocity >= 0 AND velocity <= 1),
    timestamp BIGINT NOT NULL, -- Unix timestamp in milliseconds
    duration_ms INTEGER, -- How long the note was held
    backend_used VARCHAR(50), -- Which backend processed this note
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Analytics Cache Table
-- Stores pre-computed analytics to improve performance
CREATE TABLE analytics_cache (
    cache_id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES users(user_id) ON DELETE CASCADE,
    analysis_type VARCHAR(100) NOT NULL,
    results JSONB NOT NULL,
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, analysis_type)
);

-- Practice Sessions Table
-- Tracks user practice sessions
CREATE TABLE practice_sessions (
    session_id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES users(user_id) ON DELETE CASCADE,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    total_notes INTEGER DEFAULT 0,
    unique_keys_played INTEGER DEFAULT 0,
    session_metadata JSONB
);

-- Shared Songs Table
-- For songs shared between users
CREATE TABLE shared_songs (
    share_id SERIAL PRIMARY KEY,
    song_id INTEGER REFERENCES songs(song_id) ON DELETE CASCADE,
    shared_by VARCHAR(255) REFERENCES users(user_id) ON DELETE CASCADE,
    shared_with VARCHAR(255) REFERENCES users(user_id) ON DELETE CASCADE,
    shared_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    can_edit BOOLEAN DEFAULT false,
    UNIQUE(song_id, shared_by, shared_with)
);

-- Indexes for Performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_last_active ON users(last_active);

CREATE INDEX idx_songs_user_id ON songs(user_id);
CREATE INDEX idx_songs_created_at ON songs(created_at);
CREATE INDEX idx_songs_is_public ON songs(is_public);
CREATE INDEX idx_songs_tags ON songs USING GIN(tags);

CREATE INDEX idx_note_events_user_id ON note_events(user_id);
CREATE INDEX idx_note_events_timestamp ON note_events(timestamp);
CREATE INDEX idx_note_events_key_number ON note_events(key_number);
CREATE INDEX idx_note_events_created_at ON note_events(created_at);
CREATE INDEX idx_note_events_backend ON note_events(backend_used);

CREATE INDEX idx_analytics_cache_user_id ON analytics_cache(user_id);
CREATE INDEX idx_analytics_cache_type ON analytics_cache(analysis_type);

CREATE INDEX idx_practice_sessions_user_id ON practice_sessions(user_id);
CREATE INDEX idx_practice_sessions_start_time ON practice_sessions(start_time);

-- Functions for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for automatic timestamp updates
CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_songs_updated_at
    BEFORE UPDATE ON songs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analytics_cache_updated_at
    BEFORE UPDATE ON analytics_cache
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to update user statistics
CREATE OR REPLACE FUNCTION update_user_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update last active time and total notes played
    UPDATE users
    SET 
        last_active = CURRENT_TIMESTAMP,
        total_notes_played = total_notes_played + 1
    WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_stats_on_note
    AFTER INSERT ON note_events
    FOR EACH ROW
    EXECUTE FUNCTION update_user_stats();

-- Function to update song count
CREATE OR REPLACE FUNCTION update_song_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE users
    SET total_songs_saved = total_songs_saved + 1
    WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_song_count_on_insert
    AFTER INSERT ON songs
    FOR EACH ROW
    EXECUTE FUNCTION update_song_count();

-- Insert default demo user
INSERT INTO users (user_id, username, email) VALUES
    ('user_001', 'PianoMaster', 'demo@piano.app'),
    ('user_002', 'JazzPlayer', 'jazz@piano.app'),
    ('user_003', 'ClassicalFan', 'classical@piano.app')
ON CONFLICT (user_id) DO NOTHING;

-- Insert default preferences
INSERT INTO user_preferences (user_id, preferred_backend, default_volume) VALUES
    ('user_001', 'python', 0.6),
    ('user_002', 'cpp', 0.7),
    ('user_003', 'rust', 0.5)
ON CONFLICT (user_id) DO NOTHING;

-- Insert sample songs
INSERT INTO songs (user_id, song_name, notes, metadata) VALUES
    ('user_001', 'C Major Scale', 
     '[60, 62, 64, 65, 67, 69, 71, 72]'::jsonb,
     '{"tempo": 120, "time_signature": "4/4", "key": "C major"}'::jsonb),
    ('user_002', 'Jazz Chord Progression',
     '[60, 64, 67, 62, 65, 69, 64, 68, 71]'::jsonb,
     '{"tempo": 96, "style": "jazz", "complexity": 0.7}'::jsonb)
ON CONFLICT DO NOTHING;

-- Views for common queries
CREATE OR REPLACE VIEW user_stats AS
SELECT 
    u.user_id,
    u.username,
    u.total_notes_played,
    u.total_songs_saved,
    u.last_active,
    COUNT(DISTINCT DATE(ne.created_at)) as days_active,
    up.preferred_backend
FROM users u
LEFT JOIN note_events ne ON u.user_id = ne.user_id
LEFT JOIN user_preferences up ON u.user_id = up.user_id
GROUP BY u.user_id, u.username, u.total_notes_played, u.total_songs_saved, 
         u.last_active, up.preferred_backend;

CREATE OR REPLACE VIEW popular_songs AS
SELECT 
    s.song_id,
    s.song_name,
    u.username as creator,
    s.play_count,
    s.created_at,
    jsonb_array_length(s.notes) as note_count
FROM songs s
JOIN users u ON s.user_id = u.user_id
WHERE s.is_public = true
ORDER BY s.play_count DESC
LIMIT 100;

-- Grant permissions (adjust as needed for your setup)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO piano_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO piano_user;

-- Output completion message
SELECT 'Database schema created successfully!' as status;
SELECT 'Tables: ' || COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'public';
