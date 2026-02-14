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

const requiredEnvVars = ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY', 'JWT_SECRET', 'GEMINI_API_KEY'];
const missingVars = requiredEnvVars.filter(v => !process.env[v]);

if (missingVars.length > 0) {
    console.error('CRITICAL ERROR: Missing environment variables:', missingVars.join(', '));
}

const app = express();

const allowedOrigins = [
  'https://sparkadate.online',
  'https://www.sparkadate.online',
  'https://sekotonjabulo-rgb.github.io',
  'http://localhost:5173',
  'http://localhost:3000'
];

app.use(cors({
  origin: function (origin, callback) {
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

app.get('/', (req, res) => res.status(200).send('Spark Backend is Live'));
app.get('/healthz', (req, res) => res.status(200).send('OK'));

app.get('/api/health', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development'
    });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/matches', matchesRoutes);
app.use('/api/messages', messagesRoutes);
app.use('/api/waitlist', waitlistRoutes);
app.use('/api/presence', presenceRoutes);
app.use('/api/typing', typingRoutes);
app.use('/api/push', pushRoutes);

const PORT = process.env.PORT || 3000;

const httpServer = createServer(app);

initializeWebSocket(httpServer, allowedOrigins);

const server = httpServer.listen(PORT, '0.0.0.0', () => {
    console.log('========================================');
    console.log(`Spark backend running on port ${PORT}`);
    console.log(`WebSocket server enabled`);
    console.log(`Health check: /api/health`);
    console.log('========================================');
});

// Self-ping to prevent Render free tier from sleeping
setInterval(() => {
    fetch('https://sparkadate-1n.onrender.com/healthz')
        .then(() => console.log('Self-ping successful'))
        .catch((err) => console.error('Self-ping failed:', err));
}, 840000);

server.on('error', (err) => {
    console.error('Server error:', err);
});

process.on('uncaughtException', (err) => {
    console.error('Uncaught exception:', err);
});

process.on('unhandledRejection', (err) => {
    console.error('Unhandled rejection:', err);
});
