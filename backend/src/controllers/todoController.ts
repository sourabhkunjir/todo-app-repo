import { Request, Response } from 'express';
import { Todo } from '../models/Todo';

export const getTodos = async (_req: Request, res: Response): Promise<void> => {
  try {
    const todos = await Todo.find().sort({ createdAt: -1 });
    res.json(todos);
  } catch (error) {
    res.status(500).json({ message: 'Failed to fetch todos' });
  }
};

export const createTodo = async (req: Request, res: Response): Promise<void> => {
  try {
    const { title } = req.body;

    if (!title || typeof title !== 'string' || !title.trim()) {
      res.status(400).json({ message: 'Title is required' });
      return;
    }

    const todo = await Todo.create({ title: title.trim() });
    res.status(201).json(todo);
  } catch (error) {
    res.status(500).json({ message: 'Failed to create todo' });
  }
};

export const updateTodo = async (req: Request, res: Response): Promise<void> => {
  try {
    const { title, completed } = req.body;
    const update: { title?: string; completed?: boolean } = {};

    if (title !== undefined) {
      if (typeof title !== 'string' || !title.trim()) {
        res.status(400).json({ message: 'Title must be a non-empty string' });
        return;
      }
      update.title = title.trim();
    }

    if (completed !== undefined) {
      if (typeof completed !== 'boolean') {
        res.status(400).json({ message: 'Completed must be a boolean' });
        return;
      }
      update.completed = completed;
    }

    const todo = await Todo.findByIdAndUpdate(req.params.id, update, {
      new: true,
      runValidators: true,
    });

    if (!todo) {
      res.status(404).json({ message: 'Todo not found' });
      return;
    }

    res.json(todo);
  } catch (error) {
    res.status(500).json({ message: 'Failed to update todo' });
  }
};

export const deleteTodo = async (req: Request, res: Response): Promise<void> => {
  try {
    const todo = await Todo.findByIdAndDelete(req.params.id);

    if (!todo) {
      res.status(404).json({ message: 'Todo not found' });
      return;
    }

    res.json({ message: 'Todo deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Failed to delete todo' });
  }
};
