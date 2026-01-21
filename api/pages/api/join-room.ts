// POST /api/join-room
// Joins an existing room with a room code
import type { NextApiRequest, NextApiResponse } from 'next';
import { getRoom, incrementPlayers } from '../../lib/rooms';
import { generateAblyToken } from '../../lib/ably';
import type { JoinRoomRequest, JoinRoomResponse, ErrorResponse } from '../../lib/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  // Only allow POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { roomCode, playerName = 'Guest' } = req.body as JoinRoomRequest;

    // Validate input
    if (!roomCode || roomCode.trim().length === 0) {
      return res.status(400).json({ error: 'Room code is required' });
    }

    const finalPlayerName = playerName && playerName.trim().length > 0 ? playerName.trim() : 'Guest';

    if (finalPlayerName.length > 20) {
      return res.status(400).json({ error: 'Player name too long (max 20 chars)' });
    }

    // Get room
    const room = await getRoom(roomCode.toUpperCase());
    if (!room) {
      return res.status(404).json({ error: 'Room not found' });
    }

    // Check if room is full
    if (room.players >= room.maxPlayers) {
      return res.status(400).json({ error: 'Room is full' });
    }

    // Increment player count
    const success = await incrementPlayers(room.code);
    if (!success) {
      return res.status(400).json({ error: 'Failed to join room' });
    }

    // Generate Ably token for the client
    const ablyToken = await generateAblyToken(room.channelName, 'client');

    return res.status(200).json({
      channelName: room.channelName,
      ablyToken,
      hostName: room.hostName,
    });
  } catch (error) {
    console.error('Error joining room:', error);
    return res.status(500).json({ 
      error: error instanceof Error ? error.message : 'Internal server error' 
    });
  }
}
