# 🎹 128-Key Professional Piano Application

A full-stack piano application featuring 128 keys with three distinct backend architectures and persistent SQL storage.

## 🏗️ Architecture Overview

This application demonstrates three different backend architectures working together:

### 1️⃣ Python Backend - ML/Analytics Pipeline Architecture
**Port: 8001**
- **Purpose**: Machine learning analysis, pattern recognition, user behavior analytics
- **Architecture Pattern**: Event-driven ML pipeline
- **Key Features**:
  - Melody pattern analysis using statistical methods
  - Next-note prediction using Markov chains
  - Complexity scoring and interval analysis
  - Cached analytics for performance
  - Asynchronous event processing

### 2️⃣ C++ Backend - Real-time DSP Architecture
**Port: 8002**
- **Purpose**: Low-latency audio processing, real-time effects
- **Architecture Pattern**: Real-time signal processing with thread-based concurrency
- **Key Features**:
  - Sub-millisecond latency audio processing
  - Real-time DSP effects (Reverb, EQ)
  - ADSR envelope generation
  - Lock-free audio buffers
  - Hardware-optimized processing

### 3️⃣ Rust Backend - Concurrent Actor Architecture
**Port: 8003**
- **Purpose**: Concurrent note processing, distributed state management
- **Architecture Pattern**: Actor model with message passing
- **Key Features**:
  - Actor-based concurrency (Actix framework)
  - Worker pool for load distribution
  - Lock-free message passing
  - Type-safe concurrent state
  - Fault-tolerant design

## 🗄️ Database Architecture

### PostgreSQL Database - Persistent Storage
**Port: 5432**
- **Purpose**: Permanent data storage that survives restarts
- **Key Features**:
  - User accounts and preferences
  - Song compositions with metadata
  - Individual note event tracking
  - Pre-computed analytics cache
  - Practice session history
  - Automatic triggers for statistics
  - Indexed for performance

### Database Schema

```sql
Users
├── user_id (PK)
├── username
├── email
└── statistics (total_notes_played, total_songs_saved)

Songs
├── song_id (PK)
├── user_id (FK)
├── song_name
├── notes (JSONB array)
└── metadata (tempo, key, ML analysis)

Note Events
├── event_id (PK)
├── user_id (FK)
├── key_number (0-127)
├── velocity
├── timestamp
└── backend_used

Analytics Cache
├── cache_id (PK)
├── user_id (FK)
├── analysis_type
└── results (JSONB)
```

## 🚀 Quick Start

### Using Docker (Recommended)

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Reset database (removes all data)
docker-compose down -v
```

The application will be available at:
- Frontend: http://localhost:3000
- Python API: http://localhost:8001
- C++ API: http://localhost:8002
- Rust API: http://localhost:8003
- PostgreSQL: localhost:5432

### Manual Setup

#### 1. Database Setup

```bash
# Install PostgreSQL
sudo apt-get install postgresql postgresql-contrib

# Create database and user
sudo -u postgres psql
CREATE DATABASE piano_db;
CREATE USER piano_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE piano_db TO piano_user;
\q

# Initialize schema
psql -U piano_user -d piano_db -f database_schema.sql
```

#### 2. Python Backend

```bash
# Install dependencies
pip install -r requirements.txt

# Run backend
python python_backend.py
```

#### 3. C++ Backend

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get install build-essential cmake libpqxx-dev nlohmann-json3-dev

# Download cpp-httplib
mkdir include
wget https://raw.githubusercontent.com/yhirose/cpp-httplib/master/httplib.h -O include/httplib.h

# Build
mkdir build && cd build
cmake ..
make

# Run
./piano_cpp_backend
```

#### 4. Rust Backend

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Build and run
cargo build --release
cargo run --release
```

## 📡 API Endpoints

### Python Backend (ML/Analytics)

```http
POST /api/python/process-note-ml
Content-Type: application/json

{
  "user_id": "user_001",
  "key_number": 60,
  "velocity": 0.8,
  "timestamp": 1234567890
}

Response:
{
  "backend": "python",
  "architecture": "ML/Analytics Pipeline",
  "ml_prediction": {
    "predictions": [
      {"note": 62, "probability": 0.6}
    ],
    "confidence": 0.6
  }
}
```

```http
POST /api/python/save-song
{
  "user_id": "user_001",
  "song_name": "My Composition",
  "notes": [60, 62, 64, 65, 67]
}

Response:
{
  "song_id": 123,
  "saved": true,
  "analysis": {
    "mean_pitch": 63.6,
    "complexity_score": 0.75
  }
}
```

```http
GET /api/python/user-analytics/{user_id}

Response:
{
  "total_notes_played": 1500,
  "songs_saved": 12,
  "overall_analysis": { ... }
}
```

### C++ Backend (Real-time DSP)

```http
POST /api/cpp/process-note-realtime
{
  "user_id": "user_001",
  "key_number": 60,
  "velocity": 0.8
}

Response:
{
  "backend": "cpp",
  "architecture": "Real-time DSP",
  "latency_ms": 0.05,
  "active_notes": 3,
  "sample_rate": 44100
}
```

```http
POST /api/cpp/note-off
{
  "key_number": 60
}
```

### Rust Backend (Concurrent Actor)

```http
POST /api/rust/process-note-concurrent
{
  "user_id": "user_001",
  "key_number": 60,
  "velocity": 0.8
}

Response:
{
  "backend": "rust",
  "architecture": "Concurrent Actor Model",
  "worker_id": 3,
  "processing_time_us": 120,
  "pool_size": 8
}
```

```http
POST /api/rust/save-song
{
  "user_id": "user_001",
  "song_name": "Jazz Improvisation",
  "notes": [60, 63, 67, 70]
}
```

## 🎵 Frontend Features

- **128 Piano Keys**: Full range from MIDI 0-127
- **Real-time Audio**: Web Audio API for sound generation
- **Backend Selection**: Switch between Python, C++, and Rust
- **Recording**: Capture and save performances
- **Persistent Storage**: All data saved to SQL database
- **User Accounts**: Individual user profiles and preferences
- **Analytics Dashboard**: ML-powered insights
- **Responsive Design**: Works on desktop and tablet

## 🔧 Configuration

### Database Connection

Edit `DB_CONFIG` in each backend file:

```python
# Python
DB_CONFIG = {
    'dbname': 'piano_db',
    'user': 'piano_user',
    'password': 'your_password',
    'host': 'localhost',
    'port': 5432
}
```

```cpp
// C++
const std::string DB_CONNECTION = 
    "dbname=piano_db user=piano_user password=your_password host=localhost";
```

```rust
// Rust
const DB_URL: &str = 
    "host=localhost user=piano_user password=your_password dbname=piano_db";
```

## 📊 Architecture Comparison

| Feature | Python | C++ | Rust |
|---------|--------|-----|------|
| **Concurrency Model** | AsyncIO | Threads | Actors |
| **Primary Use Case** | Analytics | Real-time Audio | Concurrent Processing |
| **Latency** | ~10ms | <1ms | ~0.1ms |
| **Memory Safety** | Runtime | Manual | Compile-time |
| **Best For** | ML/Analytics | DSP/Effects | High Concurrency |

## 🎯 Why Three Different Architectures?

1. **Separation of Concerns**: Each backend handles what it does best
2. **Performance Optimization**: Right tool for the right job
3. **Scalability**: Different scaling strategies for different workloads
4. **Fault Tolerance**: Failure in one backend doesn't affect others
5. **Learning Example**: Demonstrates different architectural approaches

## 💾 Data Persistence

All user data persists across restarts:
- ✅ User accounts and preferences
- ✅ Saved songs and compositions
- ✅ Note playing history
- ✅ Analytics cache
- ✅ Practice sessions

To reset data:
```bash
docker-compose down -v  # Removes volumes
# OR
psql -U piano_user -d piano_db -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
psql -U piano_user -d piano_db -f database_schema.sql
```

## 🧪 Testing

```bash
# Test Python backend
curl http://localhost:8001/api/python/health

# Test C++ backend
curl http://localhost:8002/api/cpp/health

# Test Rust backend
curl http://localhost:8003/api/rust/health

# Test database connection
psql -U piano_user -d piano_db -c "SELECT COUNT(*) FROM users;"
```

## 📈 Performance Metrics

- **Python**: Optimized for batch processing, ~10ms average latency
- **C++**: Ultra-low latency <1ms, real-time audio processing
- **Rust**: High concurrency, 8 worker actors, ~0.1ms processing time
- **Database**: Indexed queries, <5ms for most operations

## 🔒 Security Notes

For production deployment:
- Change default database password
- Use environment variables for secrets
- Enable SSL/TLS for database connections
- Implement authentication and authorization
- Rate limit API endpoints
- Use HTTPS for all connections

## 🤝 Contributing

This is a demonstration project showing different architectural patterns.
Feel free to extend it with:
- Additional ML models in Python backend
- More DSP effects in C++ backend
- Additional actor types in Rust backend
- Advanced analytics and visualizations

## 📝 License

MIT License - Feel free to use for learning and projects

## 🎼 Technical Details

### Note Numbering (MIDI Standard)
- 0-127: Full piano range
- 60: Middle C (C4)
- 69: A4 (440 Hz reference)

### Frequency Calculation
```
frequency = 440 * 2^((key_number - 69) / 12)
```

### Audio Processing
- Sample Rate: 44.1 kHz
- Buffer Size: 256 samples
- Bit Depth: 32-bit float

## 🆘 Troubleshooting

**Database won't start:**
```bash
docker-compose logs postgres
# Check port 5432 is not already in use
sudo lsof -i :5432
```

**Backend connection errors:**
```bash
# Ensure database is running
docker-compose ps
# Check backend logs
docker-compose logs python_backend
```

**Frontend can't connect:**
- Check all backends are running
- Verify ports 8001, 8002, 8003 are accessible
- Check browser console for CORS errors

## 🎓 Learning Resources

- **Python FastAPI**: https://fastapi.tiangolo.com
- **C++ Real-time Audio**: https://www.rossbencina.com/code/real-time-audio-programming-101
- **Rust Actix**: https://actix.rs
- **PostgreSQL**: https://www.postgresql.org/docs/

---

Built with using Python, C++, Rust, PostgreSQL, and React by Salimabai
