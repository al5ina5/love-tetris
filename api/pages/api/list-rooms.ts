// GET /api/list-rooms
// Returns list of public rooms available to join
import type { NextApiRequest, NextApiResponse } from 'next';
import { getPublicRooms } from '../../lib/rooms';
import type { ListRoomsResponse, ErrorResponse } from '../../lib/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  // Only allow GET
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const rooms = await getPublicRooms();

    // Map to response format
    const roomList = rooms.map(room => ({
      roomCode: room.code,
      hostName: room.hostName,
      players: room.players,
      maxPlayers: room.maxPlayers,
    }));

    return res.status(200).json({ rooms: roomList });
  } catch (error) {
    console.error('Error listing rooms:', error);
    return res.status(500).json({ 
      error: error instanceof Error ? error.message : 'Internal server error' 
    });
  }
}
