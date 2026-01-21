// POST /api/heartbeat
// Updates room's last heartbeat to keep it alive in listings
import type { NextApiRequest, NextApiResponse } from 'next';
import { updateHeartbeat } from '../../lib/rooms';
import type { HeartbeatRequest, HeartbeatResponse, ErrorResponse } from '../../lib/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  // Only allow POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { roomCode } = req.body as HeartbeatRequest;

    // Validate input
    if (!roomCode || roomCode.trim().length === 0) {
      return res.status(400).json({ error: 'Room code is required' });
    }

    // Update heartbeat
    const success = await updateHeartbeat(roomCode.toUpperCase());
    
    if (!success) {
      return res.status(404).json({ error: 'Room not found' });
    }

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error updating heartbeat:', error);
    return res.status(500).json({ 
      error: error instanceof Error ? error.message : 'Internal server error' 
    });
  }
}
