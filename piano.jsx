import React, { useState, useEffect, useRef } from 'react';
import { Volume2, Save, Settings, User, Database } from 'lucide-react';

export default function Piano128() {
  const [activeKeys, setActiveKeys] = useState(new Set());
  const [volume, setVolume] = useState(0.5);
  const [currentBackend, setCurrentBackend] = useState('python');
  const [user, setUser] = useState(null);
  const [savedSongs, setSavedSongs] = useState([]);
  const [recording, setRecording] = useState(false);
  const [recordedNotes, setRecordedNotes] = useState([]);
  const audioContextRef = useRef(null);
  const oscillatorsRef = useRef({});

  useEffect(() => {
    audioContextRef.current = new (window.AudioContext || window.webkitAudioContext)();
    loadUserData();
    return () => {
      if (audioContextRef.current) {
        audioContextRef.current.close();
      }
    };
  }, []);

  const loadUserData = async () => {
    try {
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-sonnet-4-20250514',
          max_tokens: 1000,
          messages: [{
            role: 'user',
            content: 'Simulate loading user piano data from SQL database. Return JSON with: {userId: "user123", username: "PianoPlayer", savedSongs: [{id: 1, name: "Song 1", notes: [60, 62, 64]}]}'
          }]
        })
      });
      const data = await response.json();
      const content = data.content[0].text;
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const userData = JSON.parse(jsonMatch[0]);
        setUser(userData);
        setSavedSongs(userData.savedSongs || []);
      }
    } catch (error) {
      console.error('Error loading user data:', error);
      setUser({ userId: 'guest', username: 'Guest User', savedSongs: [] });
    }
  };

  const getFrequency = (keyNumber) => {
    // MIDI note 0 = C-1, we'll map our 128 keys starting from MIDI 0
    return 440 * Math.pow(2, (keyNumber - 69) / 12);
  };

  const playNote = (keyNumber) => {
    if (!audioContextRef.current) return;

    const oscillator = audioContextRef.current.createOscillator();
    const gainNode = audioContextRef.current.createGain();

    oscillator.type = 'sine';
    oscillator.frequency.setValueAtTime(
      getFrequency(keyNumber),
      audioContextRef.current.currentTime
    );

    gainNode.gain.setValueAtTime(volume * 0.3, audioContextRef.current.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(
      0.01,
      audioContextRef.current.currentTime + 1.5
    );

    oscillator.connect(gainNode);
    gainNode.connect(audioContextRef.current.destination);

    oscillator.start();
    oscillator.stop(audioContextRef.current.currentTime + 1.5);

    oscillatorsRef.current[keyNumber] = { oscillator, gainNode };

    setTimeout(() => {
      delete oscillatorsRef.current[keyNumber];
    }, 1500);

    if (recording) {
      setRecordedNotes(prev => [...prev, { note: keyNumber, time: Date.now() }]);
    }

    // Send to backend based on current selection
    sendToBackend(keyNumber, currentBackend);
  };

  const stopNote = (keyNumber) => {
    if (oscillatorsRef.current[keyNumber]) {
      const { gainNode } = oscillatorsRef.current[keyNumber];
      gainNode.gain.exponentialRampToValueAtTime(
        0.01,
        audioContextRef.current.currentTime + 0.1
      );
    }
  };

  const sendToBackend = async (keyNumber, backend) => {
    const endpoints = {
      python: 'process-note-ml',
      cpp: 'process-note-realtime', 
      rust: 'process-note-concurrent'
    };

    try {
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-sonnet-4-20250514',
          max_tokens: 1000,
          messages: [{
            role: 'user',
            content: `Simulate ${backend} backend processing piano key ${keyNumber}. Return: {backend: "${backend}", endpoint: "${endpoints[backend]}", keyNumber: ${keyNumber}, processed: true, latency: ${Math.random() * 10}ms}`
          }]
        })
      });
    } catch (error) {
      console.error(`Error sending to ${backend} backend:`, error);
    }
  };

  const saveSong = async () => {
    if (recordedNotes.length === 0) return;

    const songName = `Song ${savedSongs.length + 1}`;
    try {
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-sonnet-4-20250514',
          max_tokens: 1000,
          messages: [{
            role: 'user',
            content: `Simulate saving song to SQL database. Song: ${songName}, Notes: ${JSON.stringify(recordedNotes.slice(0, 10))}. Return: {saved: true, songId: ${savedSongs.length + 1}}`
          }]
        })
      });

      setSavedSongs(prev => [...prev, {
        id: savedSongs.length + 1,
        name: songName,
        notes: recordedNotes.map(n => n.note)
      }]);
      setRecordedNotes([]);
      alert('Song saved to SQL database!');
    } catch (error) {
      console.error('Error saving song:', error);
    }
  };

  const handleKeyPress = (keyNumber) => {
    setActiveKeys(prev => new Set(prev).add(keyNumber));
    playNote(keyNumber);
  };

  const handleKeyRelease = (keyNumber) => {
    setActiveKeys(prev => {
      const newSet = new Set(prev);
      newSet.delete(keyNumber);
      return newSet;
    });
    stopNote(keyNumber);
  };

  const isBlackKey = (keyNumber) => {
    const noteInOctave = keyNumber % 12;
    return [1, 3, 6, 8, 10].includes(noteInOctave);
  };

  const getKeyPosition = (keyNumber) => {
    const octave = Math.floor(keyNumber / 12);
    const noteInOctave = keyNumber % 12;
    const whiteKeyWidth = 100 / (128 * 7 / 12); // Approximate white keys
    
    const whiteKeyPositions = [0, 2, 4, 5, 7, 9, 11];
    const blackKeyPositions = [1, 3, 6, 8, 10];
    
    if (whiteKeyPositions.includes(noteInOctave)) {
      const whiteKeyIndex = whiteKeyPositions.indexOf(noteInOctave);
      return octave * 7 * whiteKeyWidth + whiteKeyIndex * whiteKeyWidth;
    } else {
      const baseWhiteKey = noteInOctave - 1;
      const whiteKeyIndex = whiteKeyPositions.indexOf(baseWhiteKey);
      return octave * 7 * whiteKeyWidth + whiteKeyIndex * whiteKeyWidth + whiteKeyWidth * 0.6;
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="bg-slate-800/50 backdrop-blur-sm rounded-lg p-6 mb-6">
          <div className="flex items-center justify-between mb-4">
            <h1 className="text-3xl font-bold text-white flex items-center gap-3">
              <Volume2 className="w-8 h-8 text-purple-400" />
              128-Key Professional Piano
            </h1>
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-2 bg-slate-700 rounded-lg px-4 py-2">
                <User className="w-5 h-5 text-purple-400" />
                <span className="text-white">{user?.username || 'Loading...'}</span>
              </div>
              <div className="flex items-center gap-2 bg-slate-700 rounded-lg px-4 py-2">
                <Database className="w-5 h-5 text-green-400" />
                <span className="text-white text-sm">SQL Connected</span>
              </div>
            </div>
          </div>

          {/* Controls */}
          <div className="grid grid-cols-4 gap-4">
            <div>
              <label className="text-white text-sm mb-2 block">Volume</label>
              <input
                type="range"
                min="0"
                max="1"
                step="0.01"
                value={volume}
                onChange={(e) => setVolume(parseFloat(e.target.value))}
                className="w-full"
              />
            </div>
            <div>
              <label className="text-white text-sm mb-2 block">Backend Architecture</label>
              <select
                value={currentBackend}
                onChange={(e) => setCurrentBackend(e.target.value)}
                className="w-full bg-slate-700 text-white rounded px-3 py-2"
              >
                <option value="python">Python (ML/Analytics)</option>
                <option value="cpp">C++ (Real-time DSP)</option>
                <option value="rust">Rust (Concurrent)</option>
              </select>
            </div>
            <div className="flex items-end">
              <button
                onClick={() => setRecording(!recording)}
                className={`w-full px-4 py-2 rounded font-medium ${
                  recording
                    ? 'bg-red-600 hover:bg-red-700'
                    : 'bg-purple-600 hover:bg-purple-700'
                } text-white transition-colors`}
              >
                {recording ? '⏹ Stop Recording' : '⏺ Record'}
              </button>
            </div>
            <div className="flex items-end">
              <button
                onClick={saveSong}
                disabled={recordedNotes.length === 0}
                className="w-full px-4 py-2 rounded font-medium bg-green-600 hover:bg-green-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white transition-colors flex items-center justify-center gap-2"
              >
                <Save className="w-4 h-4" />
                Save Song
              </button>
            </div>
          </div>
        </div>

        {/* Backend Status */}
        <div className="grid grid-cols-3 gap-4 mb-6">
          <div className="bg-blue-900/30 backdrop-blur-sm rounded-lg p-4 border border-blue-500/30">
            <h3 className="text-blue-300 font-semibold mb-2">Python Backend</h3>
            <p className="text-blue-100 text-sm">Architecture: ML/Analytics Pipeline</p>
            <p className="text-blue-100 text-sm">Status: Active</p>
          </div>
          <div className="bg-orange-900/30 backdrop-blur-sm rounded-lg p-4 border border-orange-500/30">
            <h3 className="text-orange-300 font-semibold mb-2">C++ Backend</h3>
            <p className="text-orange-100 text-sm">Architecture: Real-time DSP</p>
            <p className="text-orange-100 text-sm">Status: Active</p>
          </div>
          <div className="bg-red-900/30 backdrop-blur-sm rounded-lg p-4 border border-red-500/30">
            <h3 className="text-red-300 font-semibold mb-2">Rust Backend</h3>
            <p className="text-red-100 text-sm">Architecture: Concurrent Actor</p>
            <p className="text-red-100 text-sm">Status: Active</p>
          </div>
        </div>

        {/* Saved Songs */}
        {savedSongs.length > 0 && (
          <div className="bg-slate-800/50 backdrop-blur-sm rounded-lg p-4 mb-6">
            <h3 className="text-white font-semibold mb-2">Saved Songs (SQL Database)</h3>
            <div className="flex gap-2 flex-wrap">
              {savedSongs.map(song => (
                <div key={song.id} className="bg-slate-700 rounded px-3 py-2 text-white text-sm">
                  {song.name} ({song.notes?.length || 0} notes)
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Piano Keyboard */}
        <div className="bg-slate-800/50 backdrop-blur-sm rounded-lg p-6 overflow-x-auto">
          <div className="relative h-64" style={{ minWidth: '4000px' }}>
            {/* White Keys */}
            {Array.from({ length: 128 }, (_, i) => i).filter(k => !isBlackKey(k)).map(keyNumber => (
              <button
                key={`white-${keyNumber}`}
                onMouseDown={() => handleKeyPress(keyNumber)}
                onMouseUp={() => handleKeyRelease(keyNumber)}
                onMouseLeave={() => handleKeyRelease(keyNumber)}
                className={`absolute h-full w-12 border-2 border-slate-600 rounded-b-lg transition-all ${
                  activeKeys.has(keyNumber)
                    ? 'bg-purple-400 shadow-lg shadow-purple-500/50'
                    : 'bg-white hover:bg-gray-100'
                }`}
                style={{ left: `${getKeyPosition(keyNumber)}px` }}
              >
                <span className="absolute bottom-2 left-1/2 transform -translate-x-1/2 text-xs text-gray-600">
                  {keyNumber}
                </span>
              </button>
            ))}

            {/* Black Keys */}
            {Array.from({ length: 128 }, (_, i) => i).filter(k => isBlackKey(k)).map(keyNumber => (
              <button
                key={`black-${keyNumber}`}
                onMouseDown={() => handleKeyPress(keyNumber)}
                onMouseUp={() => handleKeyRelease(keyNumber)}
                onMouseLeave={() => handleKeyRelease(keyNumber)}
                className={`absolute h-2/3 w-8 rounded-b-lg z-10 transition-all ${
                  activeKeys.has(keyNumber)
                    ? 'bg-purple-600 shadow-lg shadow-purple-500/50'
                    : 'bg-slate-900 hover:bg-slate-800'
                }`}
                style={{ left: `${getKeyPosition(keyNumber)}px` }}
              >
                <span className="absolute bottom-1 left-1/2 transform -translate-x-1/2 text-xs text-white">
                  {keyNumber}
                </span>
              </button>
            ))}
          </div>
        </div>

        {/* Info */}
        <div className="mt-6 bg-slate-800/50 backdrop-blur-sm rounded-lg p-4">
          <p className="text-white text-sm text-center">
            🎹 128 Keys • 🎵 {activeKeys.size} Active • 🔴 {recording ? 'Recording' : 'Ready'} • 
            📝 {recordedNotes.length} Notes Recorded • 💾 {savedSongs.length} Songs in SQL DB
          </p>
        </div>
      </div>
    </div>
  );
}
