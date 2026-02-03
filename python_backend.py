"""
Python Backend - ML/Analytics Pipeline Architecture
Handles: Machine learning analysis, pattern recognition, user behavior analytics
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import numpy as np
from datetime import datetime
import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor
import json

app = FastAPI()

# Database Configuration
DB_CONFIG = {
    'dbname': 'piano_db',
    'user': 'piano_user',
    'password': 'secure_password',
    'host': 'localhost',
    'port': 5432
}

class NoteEvent(BaseModel):
    user_id: str
    key_number: int
    velocity: float
    timestamp: float

class Song(BaseModel):
    user_id: str
    song_name: str
    notes: List[int]
    metadata: Optional[dict] = None

class MLAnalyzer:
    """Machine Learning analyzer for piano patterns"""
    
    def __init__(self):
        self.note_history = []
        self.pattern_cache = {}
    
    def analyze_melody(self, notes: List[int]) -> dict:
        """Analyze melody patterns using statistical methods"""
        if not notes:
            return {}
        
        notes_array = np.array(notes)
        
        analysis = {
            'mean_pitch': float(np.mean(notes_array)),
            'std_pitch': float(np.std(notes_array)),
            'pitch_range': int(np.max(notes_array) - np.min(notes_array)),
            'unique_notes': len(np.unique(notes_array)),
            'intervals': self._analyze_intervals(notes),
            'complexity_score': self._calculate_complexity(notes)
        }
        
        return analysis
    
    def _analyze_intervals(self, notes: List[int]) -> dict:
        """Analyze intervals between consecutive notes"""
        if len(notes) < 2:
            return {}
        
        intervals = np.diff(notes)
        return {
            'mean_interval': float(np.mean(intervals)),
            'ascending_steps': int(np.sum(intervals > 0)),
            'descending_steps': int(np.sum(intervals < 0)),
            'repeated_notes': int(np.sum(intervals == 0))
        }
    
    def _calculate_complexity(self, notes: List[int]) -> float:
        """Calculate melody complexity score"""
        if len(notes) < 2:
            return 0.0
        
        unique_ratio = len(np.unique(notes)) / len(notes)
        interval_variance = np.var(np.diff(notes))
        
        complexity = (unique_ratio * 0.5 + min(interval_variance / 100, 1.0) * 0.5)
        return float(complexity)
    
    def predict_next_note(self, recent_notes: List[int]) -> dict:
        """Predict likely next notes using simple Markov chain"""
        if len(recent_notes) < 2:
            return {'predictions': [], 'confidence': 0.0}
        
        # Simple bigram model
        transitions = {}
        for i in range(len(recent_notes) - 1):
            current = recent_notes[i]
            next_note = recent_notes[i + 1]
            
            if current not in transitions:
                transitions[current] = {}
            
            if next_note not in transitions[current]:
                transitions[current][next_note] = 0
            
            transitions[current][next_note] += 1
        
        last_note = recent_notes[-1]
        if last_note in transitions:
            predictions = sorted(
                transitions[last_note].items(),
                key=lambda x: x[1],
                reverse=True
            )[:3]
            
            total = sum(count for _, count in predictions)
            return {
                'predictions': [
                    {'note': note, 'probability': count / total}
                    for note, count in predictions
                ],
                'confidence': 0.6
            }
        
        return {'predictions': [], 'confidence': 0.0}

# Global ML analyzer instance
ml_analyzer = MLAnalyzer()

# Database Functions
def get_db_connection():
    """Create database connection"""
    return psycopg2.connect(**DB_CONFIG)

def init_database():
    """Initialize database tables"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    # Users table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            user_id VARCHAR(255) PRIMARY KEY,
            username VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # Songs table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS songs (
            song_id SERIAL PRIMARY KEY,
            user_id VARCHAR(255) REFERENCES users(user_id),
            song_name VARCHAR(255) NOT NULL,
            notes JSONB NOT NULL,
            metadata JSONB,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # Note events table for analytics
    cur.execute("""
        CREATE TABLE IF NOT EXISTS note_events (
            event_id SERIAL PRIMARY KEY,
            user_id VARCHAR(255) REFERENCES users(user_id),
            key_number INTEGER NOT NULL,
            velocity FLOAT NOT NULL,
            timestamp BIGINT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # Analytics cache table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS analytics_cache (
            cache_id SERIAL PRIMARY KEY,
            user_id VARCHAR(255) REFERENCES users(user_id),
            analysis_type VARCHAR(100) NOT NULL,
            results JSONB NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    conn.commit()
    cur.close()
    conn.close()

# API Endpoints
@app.on_event("startup")
async def startup_event():
    """Initialize database on startup"""
    try:
        init_database()
        print("✓ Python Backend: Database initialized")
    except Exception as e:
        print(f"✗ Database initialization error: {e}")

@app.post("/api/python/process-note-ml")
async def process_note_ml(event: NoteEvent):
    """
    Process note with ML analysis
    Architecture: Event-driven ML pipeline
    """
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Store note event
        cur.execute("""
            INSERT INTO note_events (user_id, key_number, velocity, timestamp)
            VALUES (%s, %s, %s, %s)
        """, (event.user_id, event.key_number, event.velocity, event.timestamp))
        
        # Get recent notes for analysis
        cur.execute("""
            SELECT key_number FROM note_events
            WHERE user_id = %s
            ORDER BY timestamp DESC
            LIMIT 20
        """, (event.user_id,))
        
        recent_notes = [row[0] for row in cur.fetchall()]
        
        conn.commit()
        cur.close()
        conn.close()
        
        # Perform ML analysis
        prediction = ml_analyzer.predict_next_note(recent_notes)
        
        return {
            'backend': 'python',
            'architecture': 'ML/Analytics Pipeline',
            'key_number': event.key_number,
            'processed': True,
            'ml_prediction': prediction,
            'recent_notes_count': len(recent_notes),
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/python/save-song")
async def save_song(song: Song):
    """Save song to database with ML analysis"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Analyze song before saving
        analysis = ml_analyzer.analyze_melody(song.notes)
        
        metadata = song.metadata or {}
        metadata['ml_analysis'] = analysis
        
        cur.execute("""
            INSERT INTO songs (user_id, song_name, notes, metadata)
            VALUES (%s, %s, %s, %s)
            RETURNING song_id
        """, (song.user_id, song.song_name, json.dumps(song.notes), json.dumps(metadata)))
        
        song_id = cur.fetchone()[0]
        
        # Cache analysis
        cur.execute("""
            INSERT INTO analytics_cache (user_id, analysis_type, results)
            VALUES (%s, %s, %s)
        """, (song.user_id, 'song_analysis', json.dumps(analysis)))
        
        conn.commit()
        cur.close()
        conn.close()
        
        return {
            'song_id': song_id,
            'saved': True,
            'analysis': analysis,
            'backend': 'python'
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/python/user-analytics/{user_id}")
async def get_user_analytics(user_id: str):
    """Get comprehensive user analytics"""
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get all user notes
        cur.execute("""
            SELECT key_number FROM note_events
            WHERE user_id = %s
            ORDER BY timestamp ASC
        """, (user_id,))
        
        all_notes = [row['key_number'] for row in cur.fetchall()]
        
        # Get saved songs count
        cur.execute("""
            SELECT COUNT(*) as song_count FROM songs
            WHERE user_id = %s
        """, (user_id,))
        
        song_count = cur.fetchone()['song_count']
        
        cur.close()
        conn.close()
        
        # Comprehensive analysis
        if all_notes:
            analysis = ml_analyzer.analyze_melody(all_notes)
        else:
            analysis = {}
        
        return {
            'user_id': user_id,
            'total_notes_played': len(all_notes),
            'songs_saved': song_count,
            'overall_analysis': analysis,
            'backend': 'python',
            'architecture': 'ML/Analytics Pipeline'
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/python/health")
async def health_check():
    """Health check endpoint"""
    return {
        'status': 'healthy',
        'backend': 'python',
        'architecture': 'ML/Analytics Pipeline',
        'features': ['ML Analysis', 'Pattern Recognition', 'Predictive Modeling']
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
