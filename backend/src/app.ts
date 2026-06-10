import cors from 'cors';
import dotenv from 'dotenv';
import express, { NextFunction, Request, Response } from 'express';
import { connectDB } from './config/db';
import { metricsHandler, metricsMiddleware } from './metrics';
import todoRoutes from './routes/todoRoutes';

dotenv.config();

const app = express();

const staticOrigins = [
  process.env.FRONTEND_URL,
  'http://localhost:5173',
  'http://localhost:3000',
  'http://127.0.0.1:5173',
].filter(Boolean) as string[];

const isAllowedOrigin = (origin: string): boolean => {
  if (staticOrigins.includes(origin)) {
    return true;
  }

  if (/^https?:\/\/[\w.-]+\.elb\.amazonaws\.com(:\d+)?$/.test(origin)) {
    return true;
  }

  if (/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
    return true;
  }

  return false;
};

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || isAllowedOrigin(origin)) {
        callback(null, true);
        return;
      }

      callback(new Error('Not allowed by CORS'));
    },
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);
app.use(express.json());
app.use(metricsMiddleware);

const ensureDb = async (_req: Request, _res: Response, next: NextFunction) => {
  try {
    await connectDB();
    next();
  } catch (error) {
    next(error);
  }
};

app.get('/', (_req, res) => {
  res.json({ status: 'ok', message: 'Todo API' });
});

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.get('/metrics', metricsHandler);

app.use('/api/todos', ensureDb, todoRoutes);

app.use((_req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

app.use((error: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error(error);

  if (error.message === 'Not allowed by CORS') {
    res.status(403).json({ message: 'Not allowed by CORS' });
    return;
  }

  if (error.message.includes('MONGODB_URI')) {
    res.status(500).json({ message: 'Database is not configured' });
    return;
  }

  if (error.name === 'MongooseServerSelectionError') {
    res.status(503).json({ message: 'Unable to connect to database' });
    return;
  }

  res.status(500).json({ message: 'Internal server error' });
});

export default app;
