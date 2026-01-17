import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { createServer } from 'http';
import authRoutes from './routes/auth.js';
import usersRoutes from './routes/users.js';
import matchesRoutes from './routes/matches.js';
import messagesRoutes from './routes/messages.js';
import waitlistRoutes from './routes/waitlist.js';
import presenceRoutes from './routes/presence.js';
import typingRoutes from './routes/typing.js';
import pushRoutes from './routes/push.js';
import { initializeWebSocket } from './services/websocket.js';

dotenv.config();

// 1. Environment Variable Check
const requiredEnvVars = ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY', 'JWT_SECRET', 'GEMINI_API_KEY'];
const missingVars = requiredEnvVars.filter(v => !process.env[v]);

if (missingVars.length > 0) {
    console.error('CRITICAL ERROR: Missing environment variables:', missingVars.join(', '));
    // In production, we don't want to exit(1) immediately if the platform is trying to boot
    // but we should log it clearly.
}

const app = express();

// 2. The Definite CORS Fix
// This allows your GitHub Pages frontend to talk to this backend.
const allowedOrigins = [
  'https://sparkadate.online',           // Add this
  'https://www.sparkadate.online',       // Add this too
  'https://sekotonjabulo-rgb.github.io', 
  'http://localhost:5173',               
  'http://localhost:3000'
];

app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or curl)
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      console.log("CORS Blocked for origin:", origin);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());

// 3. Robust Health Checks
// Render/Fly often ping the root "/" or "/healthz". 
app.get('/', (req, res) => res.status(200).send('Spark Backend is Live'));
app.get('/healthz', (req, res) => res.status(200).send('OK'));

app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development'
    });
});

// 4. API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/matches', matchesRoutes);
app.use('/api/messages', messagesRoutes);
app.use('/api/waitlist', waitlistRoutes);
app.use('/api/presence', presenceRoutes);
app.use('/api/typing', typingRoutes);
app.use('/api/push', pushRoutes);

// 5. Port Binding for Cloud Deployment
// Clouds like Render/Fly inject the PORT variable. 0.0.0.0 is required for external access.
const PORT = process.env.PORT || 3000;

// Create HTTP server for both Express and WebSocket
const httpServer = createServer(app);

// Initialize WebSocket server
initializeWebSocket(httpServer, allowedOrigins);

const server = httpServer.listen(PORT, '0.0.0.0', () => {
    console.log('========================================');
    console.log(`Spark backend running on port ${PORT}`);
    console.log(`WebSocket server enabled`);
    console.log(`Health check: /api/health`);
    console.log('========================================');
});

// Error Handling to prevent silent crashes
server.on('error', (err) => {
    console.error('Server error:', err);
});

process.on('uncaughtException', (err) => {
    console.error('Uncaught exception:', err);
});

process.on('unhandledRejection', (err) => {
    console.error('Unhandled rejection:', err);
});
