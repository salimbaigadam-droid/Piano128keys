/*
Rust Backend - Concurrent Actor Architecture
Handles: Concurrent note processing, message passing, distributed state management
*/

use actix_web::{web, App, HttpResponse, HttpServer, Result};
use actix::{Actor, Context, Handler, Message, Addr, SyncArbiter};
use serde::{Deserialize, Serialize};
use tokio_postgres::{NoTls, Client};
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};
use futures::future::join_all;

// Database Configuration
const DB_URL: &str = "host=localhost user=piano_user password=secure_password dbname=piano_db";

// Message Types for Actor System
#[derive(Message, Clone, Serialize, Deserialize)]
#[rtype(result = "Result<NoteProcessed, String>")]
pub struct ProcessNote {
    user_id: String,
    key_number: i32,
    velocity: f32,
    timestamp: i64,
}

#[derive(Message, Clone, Serialize, Deserialize)]
#[rtype(result = "Result<Vec<NoteEvent>, String>")]
pub struct GetUserNotes {
    user_id: String,
    limit: i32,
}

#[derive(Message, Clone, Serialize, Deserialize)]
#[rtype(result = "Result<SongSaved, String>")]
pub struct SaveSong {
    user_id: String,
    song_name: String,
    notes: Vec<i32>,
}

// Response Types
#[derive(Clone, Serialize, Deserialize)]
pub struct NoteProcessed {
    key_number: i32,
    processed: bool,
    worker_id: usize,
    processing_time_us: u128,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct NoteEvent {
    key_number: i32,
    velocity: f32,
    timestamp: i64,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct SongSaved {
    song_id: i32,
    saved: bool,
}

// Note Processor Actor
pub struct NoteProcessorActor {
    id: usize,
    db_client: Arc<Mutex<Option<Client>>>,
    processed_count: u64,
}

impl NoteProcessorActor {
    pub fn new(id: usize, db_client: Arc<Mutex<Option<Client>>>) -> Self {
        NoteProcessorActor {
            id,
            db_client,
            processed_count: 0,
        }
    }
}

impl Actor for NoteProcessorActor {
    type Context = Context<Self>;
    
    fn started(&mut self, _ctx: &mut Self::Context) {
        println!("✓ NoteProcessorActor {} started", self.id);
    }
}

impl Handler<ProcessNote> for NoteProcessorActor {
    type Result = Result<NoteProcessed, String>;
    
    fn handle(&mut self, msg: ProcessNote, _ctx: &mut Self::Context) -> Self::Result {
        let start = SystemTime::now();
        
        // Simulate concurrent processing
        std::thread::sleep(std::time::Duration::from_micros(100));
        
        // Process the note (could include complex audio processing)
        let frequency = 440.0 * 2.0_f32.powf((msg.key_number - 69) as f32 / 12.0);
        
        // Store in database (async would be better in production)
        if let Ok(mut guard) = self.db_client.lock() {
            if let Some(client) = guard.as_mut() {
                // Note: In real async code, we'd use tokio::spawn
                // This is simplified for demonstration
            }
        }
        
        self.processed_count += 1;
        
        let processing_time = start.elapsed()
            .map(|d| d.as_micros())
            .unwrap_or(0);
        
        Ok(NoteProcessed {
            key_number: msg.key_number,
            processed: true,
            worker_id: self.id,
            processing_time_us: processing_time,
        })
    }
}

// Database Actor
pub struct DatabaseActor {
    client: Option<Client>,
}

impl DatabaseActor {
    pub fn new() -> Self {
        DatabaseActor { client: None }
    }
    
    pub async fn connect(&mut self) -> Result<(), String> {
        match tokio_postgres::connect(DB_URL, NoTls).await {
            Ok((client, connection)) => {
                tokio::spawn(async move {
                    if let Err(e) = connection.await {
                        eprintln!("Database connection error: {}", e);
                    }
                });
                self.client = Some(client);
                Ok(())
            }
            Err(e) => Err(format!("Failed to connect to database: {}", e)),
        }
    }
}

impl Actor for DatabaseActor {
    type Context = Context<Self>;
    
    fn started(&mut self, ctx: &mut Self::Context) {
        println!("✓ DatabaseActor started");
        
        let fut = async {
            // In production, properly handle the connection
        };
        
        ctx.spawn(actix::fut::wrap_future(fut));
    }
}

impl Handler<GetUserNotes> for DatabaseActor {
    type Result = Result<Vec<NoteEvent>, String>;
    
    fn handle(&mut self, msg: GetUserNotes, _ctx: &mut Self::Context) -> Self::Result {
        // Simulate database query
        // In production, this would use async/await with the client
        Ok(vec![
            NoteEvent {
                key_number: 60,
                velocity: 0.8,
                timestamp: SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_millis() as i64,
            }
        ])
    }
}

impl Handler<SaveSong> for DatabaseActor {
    type Result = Result<SongSaved, String>;
    
    fn handle(&mut self, msg: SaveSong, _ctx: &mut Self::Context) -> Self::Result {
        // Simulate database insert
        Ok(SongSaved {
            song_id: 1,
            saved: true,
        })
    }
}

// Actor Pool Manager
pub struct ActorPoolManager {
    note_processors: Vec<Addr<NoteProcessorActor>>,
    database_actor: Addr<DatabaseActor>,
    current_worker: Arc<Mutex<usize>>,
}

impl ActorPoolManager {
    pub fn new(pool_size: usize) -> Self {
        let db_client = Arc::new(Mutex::new(None));
        
        let note_processors: Vec<Addr<NoteProcessorActor>> = (0..pool_size)
            .map(|i| {
                NoteProcessorActor::new(i, Arc::clone(&db_client)).start()
            })
            .collect();
        
        let database_actor = DatabaseActor::new().start();
        
        ActorPoolManager {
            note_processors,
            database_actor,
            current_worker: Arc::new(Mutex::new(0)),
        }
    }
    
    pub fn get_next_worker(&self) -> Addr<NoteProcessorActor> {
        let mut current = self.current_worker.lock().unwrap();
        let worker = self.note_processors[*current].clone();
        *current = (*current + 1) % self.note_processors.len();
        worker
    }
    
    pub fn get_database_actor(&self) -> Addr<DatabaseActor> {
        self.database_actor.clone()
    }
}

// HTTP Request/Response Types
#[derive(Deserialize)]
struct NoteRequest {
    user_id: String,
    key_number: i32,
    velocity: Option<f32>,
    timestamp: Option<i64>,
}

#[derive(Serialize)]
struct NoteResponse {
    backend: String,
    architecture: String,
    key_number: i32,
    processed: bool,
    worker_id: usize,
    processing_time_us: u128,
    pool_size: usize,
}

#[derive(Deserialize)]
struct SongRequest {
    user_id: String,
    song_name: String,
    notes: Vec<i32>,
}

#[derive(Serialize)]
struct HealthResponse {
    status: String,
    backend: String,
    architecture: String,
    features: Vec<String>,
    active_workers: usize,
}

// HTTP Handlers
async fn process_note_concurrent(
    pool: web::Data<Arc<ActorPoolManager>>,
    note: web::Json<NoteRequest>,
) -> Result<HttpResponse> {
    let timestamp = note.timestamp.unwrap_or_else(|| {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64
    });
    
    let msg = ProcessNote {
        user_id: note.user_id.clone(),
        key_number: note.key_number,
        velocity: note.velocity.unwrap_or(0.8),
        timestamp,
    };
    
    let worker = pool.get_next_worker();
    
    match worker.send(msg).await {
        Ok(Ok(result)) => {
            let response = NoteResponse {
                backend: "rust".to_string(),
                architecture: "Concurrent Actor Model".to_string(),
                key_number: result.key_number,
                processed: result.processed,
                worker_id: result.worker_id,
                processing_time_us: result.processing_time_us,
                pool_size: pool.note_processors.len(),
            };
            Ok(HttpResponse::Ok().json(response))
        }
        Ok(Err(e)) => Ok(HttpResponse::InternalServerError().json(serde_json::json!({
            "error": e
        }))),
        Err(e) => Ok(HttpResponse::InternalServerError().json(serde_json::json!({
            "error": format!("Actor communication error: {}", e)
        }))),
    }
}

async fn save_song(
    pool: web::Data<Arc<ActorPoolManager>>,
    song: web::Json<SongRequest>,
) -> Result<HttpResponse> {
    let msg = SaveSong {
        user_id: song.user_id.clone(),
        song_name: song.song_name.clone(),
        notes: song.notes.clone(),
    };
    
    let db_actor = pool.get_database_actor();
    
    match db_actor.send(msg).await {
        Ok(Ok(result)) => Ok(HttpResponse::Ok().json(serde_json::json!({
            "song_id": result.song_id,
            "saved": result.saved,
            "backend": "rust"
        }))),
        Ok(Err(e)) => Ok(HttpResponse::InternalServerError().json(serde_json::json!({
            "error": e
        }))),
        Err(e) => Ok(HttpResponse::InternalServerError().json(serde_json::json!({
            "error": format!("Actor communication error: {}", e)
        }))),
    }
}

async fn health_check(pool: web::Data<Arc<ActorPoolManager>>) -> Result<HttpResponse> {
    let response = HealthResponse {
        status: "healthy".to_string(),
        backend: "rust".to_string(),
        architecture: "Concurrent Actor Model".to_string(),
        features: vec![
            "Actor-based Concurrency".to_string(),
            "Message Passing".to_string(),
            "Worker Pool".to_string(),
            "Async I/O".to_string(),
        ],
        active_workers: pool.note_processors.len(),
    };
    Ok(HttpResponse::Ok().json(response))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    println!("🎹 Rust Backend - Concurrent Actor Architecture");
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    // Create actor pool with 8 workers
    let pool = Arc::new(ActorPoolManager::new(8));
    
    println!("✓ Actor pool initialized with {} workers", pool.note_processors.len());
    println!("✓ Starting HTTP server on 0.0.0.0:8003...");
    
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(Arc::clone(&pool)))
            .route("/api/rust/process-note-concurrent", web::post().to(process_note_concurrent))
            .route("/api/rust/save-song", web::post().to(save_song))
            .route("/api/rust/health", web::get().to(health_check))
    })
    .bind(("0.0.0.0", 8003))?
    .run()
    .await
}
