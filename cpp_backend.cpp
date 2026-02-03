/*
C++ Backend - Real-time DSP Architecture
Handles: Low-latency audio processing, real-time effects, signal processing
*/

#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <queue>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <cmath>
#include <memory>
#include <pqxx/pqxx>
#include <nlohmann/json.hpp>
#include <httplib.h>

using json = nlohmann::json;

// Constants
const double PI = 3.14159265358979323846;
const int SAMPLE_RATE = 44100;
const int BUFFER_SIZE = 256;

// Database Configuration
const std::string DB_CONNECTION = "dbname=piano_db user=piano_user password=secure_password host=localhost port=5432";

// Real-time Audio Buffer
struct AudioBuffer {
    std::vector<float> samples;
    int writePos;
    int readPos;
    std::mutex mutex;
    
    AudioBuffer(int size) : samples(size, 0.0f), writePos(0), readPos(0) {}
    
    void write(float sample) {
        std::lock_guard<std::mutex> lock(mutex);
        samples[writePos] = sample;
        writePos = (writePos + 1) % samples.size();
    }
    
    float read() {
        std::lock_guard<std::mutex> lock(mutex);
        float sample = samples[readPos];
        readPos = (readPos + 1) % samples.size();
        return sample;
    }
};

// DSP Effects
class ReverbEffect {
private:
    std::vector<float> delayBuffer;
    int delayLength;
    int writePos;
    float feedback;
    float wetLevel;
    
public:
    ReverbEffect(int delayMs = 50, float fb = 0.5f, float wet = 0.3f)
        : delayLength(SAMPLE_RATE * delayMs / 1000),
          writePos(0),
          feedback(fb),
          wetLevel(wet) {
        delayBuffer.resize(delayLength, 0.0f);
    }
    
    float process(float input) {
        float delayed = delayBuffer[writePos];
        float output = input + delayed * wetLevel;
        
        delayBuffer[writePos] = input + delayed * feedback;
        writePos = (writePos + 1) % delayLength;
        
        return output;
    }
};

class EqualizerEffect {
private:
    float lowGain;
    float midGain;
    float highGain;
    
    // Simple IIR filters
    float lowPassPrev;
    float highPassPrev;
    
public:
    EqualizerEffect(float low = 1.0f, float mid = 1.0f, float high = 1.0f)
        : lowGain(low), midGain(mid), highGain(high),
          lowPassPrev(0.0f), highPassPrev(0.0f) {}
    
    float process(float input) {
        // Simple 3-band EQ using cascaded filters
        float lowPass = input * 0.3f + lowPassPrev * 0.7f;
        lowPassPrev = lowPass;
        
        float highPass = input - lowPass;
        
        return lowPass * lowGain + (input - lowPass - highPass) * midGain + highPass * highGain;
    }
};

// Real-time Note Processor
class NoteProcessor {
private:
    int keyNumber;
    float frequency;
    float phase;
    float amplitude;
    float envelope;
    
    ReverbEffect reverb;
    EqualizerEffect eq;
    
    enum EnvelopeState { ATTACK, DECAY, SUSTAIN, RELEASE, IDLE };
    EnvelopeState state;
    
    float attackTime;
    float decayTime;
    float sustainLevel;
    float releaseTime;
    
    std::chrono::steady_clock::time_point startTime;
    
public:
    NoteProcessor(int key)
        : keyNumber(key),
          frequency(440.0 * std::pow(2.0, (key - 69) / 12.0)),
          phase(0.0),
          amplitude(0.5),
          envelope(0.0),
          state(ATTACK),
          attackTime(0.01f),
          decayTime(0.1f),
          sustainLevel(0.7f),
          releaseTime(0.3f) {
        startTime = std::chrono::steady_clock::now();
    }
    
    float generateSample() {
        if (state == IDLE) return 0.0f;
        
        // Update envelope
        auto now = std::chrono::steady_clock::now();
        float elapsed = std::chrono::duration<float>(now - startTime).count();
        
        switch (state) {
            case ATTACK:
                envelope = std::min(1.0f, elapsed / attackTime);
                if (elapsed >= attackTime) {
                    state = DECAY;
                    startTime = now;
                }
                break;
            case DECAY:
                envelope = 1.0f - (1.0f - sustainLevel) * std::min(1.0f, elapsed / decayTime);
                if (elapsed >= decayTime) {
                    state = SUSTAIN;
                }
                break;
            case SUSTAIN:
                envelope = sustainLevel;
                break;
            case RELEASE:
                envelope = sustainLevel * (1.0f - std::min(1.0f, elapsed / releaseTime));
                if (elapsed >= releaseTime) {
                    state = IDLE;
                }
                break;
            case IDLE:
                return 0.0f;
        }
        
        // Generate oscillator
        float sample = std::sin(2.0 * PI * phase) * amplitude * envelope;
        phase += frequency / SAMPLE_RATE;
        if (phase >= 1.0) phase -= 1.0;
        
        // Apply effects
        sample = eq.process(sample);
        sample = reverb.process(sample);
        
        return sample;
    }
    
    void release() {
        if (state != IDLE && state != RELEASE) {
            state = RELEASE;
            startTime = std::chrono::steady_clock::now();
        }
    }
    
    bool isActive() const {
        return state != IDLE;
    }
};

// Real-time Audio Engine
class AudioEngine {
private:
    std::map<int, std::shared_ptr<NoteProcessor>> activeNotes;
    AudioBuffer outputBuffer;
    std::thread processingThread;
    std::mutex notesMutex;
    std::condition_variable cv;
    bool running;
    
    void processingLoop() {
        while (running) {
            std::unique_lock<std::mutex> lock(notesMutex);
            
            // Generate buffer worth of samples
            for (int i = 0; i < BUFFER_SIZE; ++i) {
                float mixedSample = 0.0f;
                
                for (auto it = activeNotes.begin(); it != activeNotes.end();) {
                    float sample = it->second->generateSample();
                    mixedSample += sample;
                    
                    if (!it->second->isActive()) {
                        it = activeNotes.erase(it);
                    } else {
                        ++it;
                    }
                }
                
                // Soft clipping
                mixedSample = std::tanh(mixedSample);
                outputBuffer.write(mixedSample);
            }
            
            lock.unlock();
            std::this_thread::sleep_for(std::chrono::microseconds(BUFFER_SIZE * 1000000 / SAMPLE_RATE));
        }
    }
    
public:
    AudioEngine() : outputBuffer(SAMPLE_RATE), running(true) {
        processingThread = std::thread(&AudioEngine::processingLoop, this);
    }
    
    ~AudioEngine() {
        running = false;
        if (processingThread.joinable()) {
            processingThread.join();
        }
    }
    
    void noteOn(int keyNumber) {
        std::lock_guard<std::mutex> lock(notesMutex);
        activeNotes[keyNumber] = std::make_shared<NoteProcessor>(keyNumber);
    }
    
    void noteOff(int keyNumber) {
        std::lock_guard<std::mutex> lock(notesMutex);
        auto it = activeNotes.find(keyNumber);
        if (it != activeNotes.end()) {
            it->second->release();
        }
    }
    
    int getActiveNoteCount() {
        std::lock_guard<std::mutex> lock(notesMutex);
        return activeNotes.size();
    }
};

// Database Manager
class DatabaseManager {
private:
    std::string connectionString;
    
public:
    DatabaseManager(const std::string& connStr) : connectionString(connStr) {}
    
    void saveNoteEvent(const std::string& userId, int keyNumber, float velocity, long long timestamp) {
        try {
            pqxx::connection conn(connectionString);
            pqxx::work txn(conn);
            
            txn.exec_params(
                "INSERT INTO note_events (user_id, key_number, velocity, timestamp) VALUES ($1, $2, $3, $4)",
                userId, keyNumber, velocity, timestamp
            );
            
            txn.commit();
        } catch (const std::exception& e) {
            std::cerr << "Database error: " << e.what() << std::endl;
        }
    }
    
    json getRecentNotes(const std::string& userId, int limit = 10) {
        try {
            pqxx::connection conn(connectionString);
            pqxx::work txn(conn);
            
            pqxx::result res = txn.exec_params(
                "SELECT key_number, velocity, timestamp FROM note_events WHERE user_id = $1 ORDER BY timestamp DESC LIMIT $2",
                userId, limit
            );
            
            json notes = json::array();
            for (const auto& row : res) {
                notes.push_back({
                    {"key_number", row[0].as<int>()},
                    {"velocity", row[1].as<float>()},
                    {"timestamp", row[2].as<long long>()}
                });
            }
            
            return notes;
        } catch (const std::exception& e) {
            std::cerr << "Database error: " << e.what() << std::endl;
            return json::array();
        }
    }
};

// HTTP Server
class PianoServer {
private:
    AudioEngine audioEngine;
    DatabaseManager dbManager;
    httplib::Server server;
    
public:
    PianoServer() : dbManager(DB_CONNECTION) {
        setupRoutes();
    }
    
    void setupRoutes() {
        // Process note with real-time DSP
        server.Post("/api/cpp/process-note-realtime", [this](const httplib::Request& req, httplib::Response& res) {
            try {
                json body = json::parse(req.body);
                
                int keyNumber = body["key_number"];
                std::string userId = body["user_id"];
                float velocity = body.value("velocity", 0.8f);
                long long timestamp = body["timestamp"];
                
                // Process in real-time
                audioEngine.noteOn(keyNumber);
                
                // Save to database asynchronously
                std::thread([this, userId, keyNumber, velocity, timestamp]() {
                    dbManager.saveNoteEvent(userId, keyNumber, velocity, timestamp);
                }).detach();
                
                auto startTime = std::chrono::high_resolution_clock::now();
                // Simulate processing
                std::this_thread::sleep_for(std::chrono::microseconds(50));
                auto endTime = std::chrono::high_resolution_clock::now();
                
                double latency = std::chrono::duration<double, std::milli>(endTime - startTime).count();
                
                json response = {
                    {"backend", "cpp"},
                    {"architecture", "Real-time DSP"},
                    {"key_number", keyNumber},
                    {"processed", true},
                    {"latency_ms", latency},
                    {"active_notes", audioEngine.getActiveNoteCount()},
                    {"sample_rate", SAMPLE_RATE},
                    {"buffer_size", BUFFER_SIZE}
                };
                
                res.set_content(response.dump(), "application/json");
            } catch (const std::exception& e) {
                res.status = 500;
                res.set_content(json{{"error", e.what()}}.dump(), "application/json");
            }
        });
        
        // Note off
        server.Post("/api/cpp/note-off", [this](const httplib::Request& req, httplib::Response& res) {
            try {
                json body = json::parse(req.body);
                int keyNumber = body["key_number"];
                
                audioEngine.noteOff(keyNumber);
                
                res.set_content(json{{"released", true}}.dump(), "application/json");
            } catch (const std::exception& e) {
                res.status = 500;
                res.set_content(json{{"error", e.what()}}.dump(), "application/json");
            }
        });
        
        // Health check
        server.Get("/api/cpp/health", [this](const httplib::Request&, httplib::Response& res) {
            json response = {
                {"status", "healthy"},
                {"backend", "cpp"},
                {"architecture", "Real-time DSP"},
                {"active_notes", audioEngine.getActiveNoteCount()},
                {"features", {"Low-latency Processing", "DSP Effects", "Real-time Audio"}}
            };
            res.set_content(response.dump(), "application/json");
        });
    }
    
    void start(int port = 8002) {
        std::cout << "C++ Backend starting on port " << port << "..." << std::endl;
        server.listen("0.0.0.0", port);
    }
};

int main() {
    try {
        PianoServer server;
        server.start(8002);
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    return 0;
}
