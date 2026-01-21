// Room state management using Vercel KV
import { kv } from '@vercel/kv';
import type { Room } from './types';

const ROOM_TTL = 3600; // 1 hour in seconds
const PUBLIC_ROOMS_KEY = 'rooms:public';

export function generateRoomCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed confusing chars
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

export async function createRoom(
  hostName: string,
  isPublic: boolean,
  channelName: string
): Promise<Room> {
  // Generate unique room code
  let code = generateRoomCode();
  let attempts = 0;
  while (await kv.exists(`room:${code}`) && attempts < 10) {
    code = generateRoomCode();
    attempts++;
  }

  if (attempts >= 10) {
    throw new Error('Failed to generate unique room code');
  }

  const room: Room = {
    code,
    hostName,
    isPublic,
    players: 1,
    maxPlayers: 2,
    createdAt: Date.now(),
    lastHeartbeat: Date.now(),
    channelName,
  };

  // Store room with TTL
  await kv.set(`room:${code}`, JSON.stringify(room), { ex: ROOM_TTL });

  // Add to public rooms set if public
  if (isPublic) {
    await kv.sadd(PUBLIC_ROOMS_KEY, code);
  }

  return room;
}

export async function getRoom(code: string): Promise<Room | null> {
  const data = await kv.get<string>(`room:${code}`);
  if (!data) return null;
  return JSON.parse(data);
}

export async function updateRoom(room: Room): Promise<void> {
  await kv.set(`room:${room.code}`, JSON.stringify(room), { ex: ROOM_TTL });
}

export async function incrementPlayers(code: string): Promise<boolean> {
  const room = await getRoom(code);
  if (!room || room.players >= room.maxPlayers) {
    return false;
  }

  room.players++;
  await updateRoom(room);
  return true;
}

export async function updateHeartbeat(code: string): Promise<boolean> {
  const room = await getRoom(code);
  if (!room) return false;

  room.lastHeartbeat = Date.now();
  await updateRoom(room);
  return true;
}

export async function getPublicRooms(): Promise<Room[]> {
  const codes = await kv.smembers(PUBLIC_ROOMS_KEY);
  if (!codes || codes.length === 0) return [];

  const rooms: Room[] = [];
  const now = Date.now();
  const staleThreshold = 60000; // 60 seconds

  for (const code of codes) {
    const room = await getRoom(code as string);
    if (!room) {
      // Room expired, remove from set
      await kv.srem(PUBLIC_ROOMS_KEY, code);
      continue;
    }

    // Check if stale (no heartbeat in 60s)
    if (now - room.lastHeartbeat > staleThreshold) {
      await kv.srem(PUBLIC_ROOMS_KEY, code);
      continue;
    }

    // Only return rooms with space
    if (room.players < room.maxPlayers) {
      rooms.push(room);
    } else {
      // Room full, remove from public list
      await kv.srem(PUBLIC_ROOMS_KEY, code);
    }
  }

  return rooms;
}
