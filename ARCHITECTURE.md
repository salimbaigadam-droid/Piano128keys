# 128-Key Piano Application Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend Layer                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │     React Application (piano.jsx)                       │   │
│  │     - 128 Piano Keys                                    │   │
│  │     - Real-time Audio (Web Audio API)                  │   │
│  │     - Backend Selection (Python/C++/Rust)              │   │
│  │     - Recording & Playback                             │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTP/REST API
                         │
        ┌────────────────┴────────────────┐
        │                                  │
        ▼                                  ▼
┌───────────────────┐           ┌───────────────────┐
│   Load Balancer   │           │   API Gateway     │
│   (Optional)      │           │   (Optional)      │
└────────┬──────────┘           └────────┬──────────┘
         │                               │
         │                               │
    ┌────┴────┬─────────────────┬────────┴─────┐
    │         │                 │              │
    ▼         ▼                 ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Backend Layer (3 Architectures)            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐ │
│  │ Python Backend   │  │  C++ Backend     │  │ Rust Backend │ │
│  │ Port: 8001       │  │  Port: 8002      │  │ Port: 8003   │ │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────┤ │
│  │ Architecture:    │  │ Architecture:    │  │ Architecture:│ │
│  │ ML/Analytics     │  │ Real-time DSP    │  │ Actor Model  │ │
│  │ Pipeline         │  │                  │  │              │ │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────┤ │
│  │ Components:      │  │ Components:      │  │ Components:  │ │
│  │ • FastAPI        │  │ • Audio Engine   │  │ • Actix      │ │
│  │ • ML Analyzer    │  │ • DSP Effects    │  │ • 8 Workers  │ │
│  │ • Async I/O      │  │ • Buffer Manager │  │ • Message Q  │ │
│  │ • Pattern Rec.   │  │ • Reverb/EQ      │  │ • Tokio      │ │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────┤ │
│  │ Use Cases:       │  │ Use Cases:       │  │ Use Cases:   │ │
│  │ • Melody Analysis│  │ • Audio Process  │  │ • Concurrent │ │
│  │ • Prediction     │  │ • Low Latency    │  │   Processing │ │
│  │ • User Analytics │  │ • Real-time FX   │  │ • Load Dist. │ │
│  └────────┬─────────┘  └────────┬─────────┘  └──────┬───────┘ │
│           │                     │                    │         │
└───────────┼─────────────────────┼────────────────────┼─────────┘
            │                     │                    │
            └─────────────────────┴────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Persistence Layer                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              PostgreSQL Database                        │   │
│  │              Port: 5432                                 │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │ Tables:                                                 │   │
│  │  • users              (User accounts)                  │   │
│  │  • user_preferences   (Settings)                       │   │
│  │  • songs              (Compositions)                   │   │
│  │  • note_events        (Individual notes)               │   │
│  │  • analytics_cache    (Pre-computed data)              │   │
│  │  • practice_sessions  (Session tracking)               │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │ Features:                                               │   │
│  │  ✓ ACID Compliance                                     │   │
│  │  ✓ Automatic Triggers                                  │   │
│  │  ✓ Indexed Queries                                     │   │
│  │  ✓ Data Persistence                                    │   │
│  │  ✓ Concurrent Access                                   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Note Playing Flow
```
User Presses Key
    ↓
Frontend (React)
    ↓
Web Audio API (Sound Generation)
    ↓
Send to Selected Backend (HTTP POST)
    ↓
┌────────────────┬────────────────┬─────────────────┐
│                │                │                 │
▼                ▼                ▼                 ▼
Python           C++              Rust              Database
Process Note     Process Note     Process Note      Save Event
    ↓                ↓                ↓                 ↓
ML Analysis      DSP Effects      Actor Queue       note_events
    ↓                ↓                ↓                 ↓
Prediction       Audio Buffer     Worker Pool       users (stats)
    ↓                ↓                ↓                 ↓
Response         Response         Response          Triggers
    └────────────────┴────────────────┴─────────────┘
                         ↓
                  Frontend Updates
```

### 2. Song Saving Flow
```
User Clicks Save
    ↓
Frontend collects recorded notes
    ↓
POST to selected backend
    ↓
Backend processes:
    ├─ Python: ML Analysis
    ├─ C++: Audio metrics
    └─ Rust: Concurrent save
    ↓
Database operations:
    ├─ INSERT INTO songs
    ├─ UPDATE user statistics
    └─ Cache analytics
    ↓
Response to frontend
    ↓
UI updates with confirmation
```

## Architecture Patterns

### Python Backend: Event-Driven ML Pipeline
```
Request → FastAPI Router → ML Analyzer → Database → Cache → Response
                ↓              ↓           ↓        ↓
           Async Queue    Pattern Rec   Event Log  Analytics
```

### C++ Backend: Real-time DSP
```
Request → Thread Pool → Audio Engine → DSP Chain → Buffer → Response
               ↓            ↓             ↓          ↓
          Lock-free    Oscillators    Reverb/EQ   Output
```

### Rust Backend: Actor Model
```
Request → Router → Actor System → Worker Pool → Database → Response
              ↓         ↓             ↓           ↓
         Message Q   Supervisor   8 Workers   Connection Pool
```

## Technology Stack

### Frontend
- **Framework**: React 18
- **Build Tool**: Vite
- **Styling**: Tailwind CSS
- **Audio**: Web Audio API
- **Icons**: Lucide React

### Backend - Python
- **Framework**: FastAPI
- **Database**: psycopg2
- **ML/Math**: NumPy, SciPy
- **Async**: uvicorn

### Backend - C++
- **Standard**: C++17
- **HTTP**: cpp-httplib
- **Database**: libpqxx
- **JSON**: nlohmann-json
- **Build**: CMake

### Backend - Rust
- **Framework**: Actix-web
- **Actor**: Actix
- **Async**: Tokio
- **Database**: tokio-postgres
- **Serialization**: Serde

### Database
- **DBMS**: PostgreSQL 16
- **Features**: JSONB, Triggers, Indexes
- **Pooling**: Connection pooling in all backends

## Deployment Options

### Option 1: Docker Compose (Recommended)
```
docker-compose up -d
```
- All services containerized
- Automatic networking
- Volume persistence
- Easy scaling

### Option 2: Manual Deployment
```
PostgreSQL → Python → C++ → Rust → Frontend
```
- Full control over each service
- Custom configuration
- Direct system access

### Option 3: Kubernetes (Production)
```
Pods: [Frontend, Python, C++, Rust, PostgreSQL]
Services: Load balancing, Auto-scaling
Volumes: Persistent storage
```

## Performance Characteristics

| Metric | Python | C++ | Rust |
|--------|--------|-----|------|
| Latency | ~10ms | <1ms | ~0.1ms |
| Throughput | 100 req/s | 10k req/s | 5k req/s |
| Memory | ~50MB | ~10MB | ~20MB |
| CPU Usage | Medium | Low | Low |
| Concurrency | AsyncIO | Threads | Actors |

## Scalability

### Horizontal Scaling
- Multiple Python instances for analytics
- Load balancer distributes requests
- Database read replicas
- Cached analytics reduce DB load

### Vertical Scaling
- Increase C++ buffer size for more voices
- More Rust worker actors
- Larger database connection pools

## Security Considerations

1. **Database**: 
   - Password authentication
   - Role-based access
   - SSL/TLS connections

2. **API**:
   - Rate limiting
   - Input validation
   - CORS configuration

3. **Data**:
   - User data isolation
   - SQL injection prevention
   - Prepared statements

## Monitoring

- Backend health endpoints
- Database connection status
- Request/response logging
- Performance metrics
- Error tracking

## Future Enhancements

- [ ] MIDI device support
- [ ] Collaborative playing
- [ ] Cloud sync
- [ ] Mobile app
- [ ] AI composition
- [ ] Virtual instruments
- [ ] Audio export
