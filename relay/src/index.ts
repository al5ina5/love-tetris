import express from 'express';
import cors from 'cors';
import net from 'net';
import { v4 as uuidv4 } from 'uuid';

// --- Configuration ---
const HTTP_PORT = process.env.PORT || 3000;
const TCP_PORT = process.env.TCP_PORT || 12346;

// --- Types ---
interface Room {
  code: string;
  hostName: string;
  isPublic: boolean;
  players: number;
  maxPlayers: number;
  createdAt: number;
  lastHeartbeat: number;
}

interface RoomData {
  sockets: net.Socket[];
}

// --- In-Memory State ---
const rooms = new Map<string, Room>();
const roomSockets = new Map<string, RoomData>();

// --- Helper: Generate Room Code ---
function generateRoomCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// --- HTTP Server (Matchmaker) ---
const app = express();
app.use(cors());
app.use(express.json());

app.post('/api/create-room', (req, res) => {
  const { isPublic, hostName = 'Host' } = req.body;
  const code = generateRoomCode();
  
  const room: Room = {
    code,
    hostName,
    isPublic: !!isPublic,
    players: 1,
    maxPlayers: 2,
    createdAt: Date.now(),
    lastHeartbeat: Date.now(),
  };
  
  rooms.set(code, room);
  res.json({ roomCode: code });
  console.log(`[HTTP] Room ${code} created`);
});

app.get('/api/list-rooms', (req, res) => {
  const now = Date.now();
  const publicRooms = Array.from(rooms.values()).filter(r => 
    r.isPublic && 
    r.players < r.maxPlayers && 
    (now - r.lastHeartbeat) < 60000 // Only show active rooms
  );
  res.json({ rooms: publicRooms });
});

app.post('/api/join-room', (req, res) => {
  const { roomCode } = req.body;
  const room = rooms.get(roomCode?.toUpperCase());
  
  if (!room) return res.status(404).json({ error: 'Room not found' });
  if (room.players >= room.maxPlayers) return res.status(400).json({ error: 'Room full' });
  
  res.json({ success: true });
});

app.post('/api/heartbeat', (req, res) => {
  const { roomCode } = req.body;
  const room = rooms.get(roomCode?.toUpperCase());
  if (room) {
    room.lastHeartbeat = Date.now();
    res.json({ success: true });
  } else {
    res.status(404).json({ error: 'Room not found' });
  }
});

app.listen(HTTP_PORT, () => {
  console.log(`[HTTP] Matchmaker listening on port ${HTTP_PORT}`);
});

// --- TCP Server (Real-time Relay) ---
const tcpServer = net.createServer((socket) => {
  let currentRoomCode: string | null = null;
  let buffer = '';

  socket.on('data', (data) => {
    buffer += data.toString();
    const lines = buffer.split('\n');
    buffer = lines.pop() || '';

    for (const line of lines) {
      if (line.startsWith('JOIN:')) {
        const code = line.split(':')[1].toUpperCase();
        currentRoomCode = code;
        
        let roomData = roomSockets.get(code);
        if (!roomData) {
          roomData = { sockets: [socket] };
          roomSockets.set(code, roomData);
        } else {
          if (roomData.sockets.length < 2) {
            roomData.sockets.push(socket);
            const room = rooms.get(code);
            if (room) room.players = roomData.sockets.length;
            
            // Notify both players they are paired
            roomData.sockets.forEach(s => s.write('PAIRED\n'));
          } else {
            socket.write('ERROR:Room full\n');
            socket.end();
          }
        }
        continue;
      }

      // Forward data to others in the same room
      if (currentRoomCode) {
        const roomData = roomSockets.get(currentRoomCode);
        if (roomData) {
          roomData.sockets.forEach(s => {
            if (s !== socket) s.write(line + '\n');
          });
        }
      }
    }
  });

  const cleanup = () => {
    if (currentRoomCode) {
      const roomData = roomSockets.get(currentRoomCode);
      if (roomData) {
        roomData.sockets = roomData.sockets.filter(s => s !== socket);
        const room = rooms.get(currentRoomCode);
        if (room) room.players = roomData.sockets.length;

        if (roomData.sockets.length === 0) {
          roomSockets.delete(currentRoomCode);
          rooms.delete(currentRoomCode);
        } else {
          roomData.sockets.forEach(s => s.write('OPPONENT_LEFT\n'));
        }
      }
    }
  };

  socket.on('close', cleanup);
  socket.on('error', cleanup);
});

tcpServer.listen(TCP_PORT, () => {
  console.log(`[TCP] Relay listening on port ${TCP_PORT}`);
});
