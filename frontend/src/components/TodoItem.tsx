import { useEffect, useState } from 'react';
import type { Todo } from '../types/todo';
import { EXIT_ANIMATION_MS, wait } from '../lib/animation';
import './TodoItem.css';

interface TodoItemProps {
  todo: Todo;
  index: number;
  onToggle: (id: string, completed: boolean) => Promise<void>;
  onDelete: (id: string) => Promise<void>;
  onUpdate: (id: string, title: string) => Promise<void>;
}

export function TodoItem({ todo, index, onToggle, onDelete, onUpdate }: TodoItemProps) {
  const [editing, setEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(todo.title);
  const [busy, setBusy] = useState(false);
  const [isRemoving, setIsRemoving] = useState(false);

  useEffect(() => {
    setEditTitle(todo.title);
  }, [todo.title]);

  const handleSave = async () => {
    const trimmed = editTitle.trim();
    if (!trimmed || trimmed === todo.title) {
      setEditing(false);
      setEditTitle(todo.title);
      return;
    }

    setBusy(true);
    try {
      await onUpdate(todo._id, trimmed);
      setEditing(false);
    } finally {
      setBusy(false);
    }
  };

  const handleToggle = async () => {
    if (busy || isRemoving) return;
    setBusy(true);
    try {
      await onToggle(todo._id, !todo.completed);
    } finally {
      setBusy(false);
    }
  };

  const handleDelete = async () => {
    if (busy || isRemoving) return;

    setIsRemoving(true);
    await wait(EXIT_ANIMATION_MS);

    setBusy(true);
    try {
      await onDelete(todo._id);
    } catch {
      setIsRemoving(false);
    } finally {
      setBusy(false);
    }
  };

  const itemClass = [
    'todo-item',
    todo.completed && 'todo-item--completed',
    busy && 'todo-item--busy',
    isRemoving && 'todo-item--removing',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <li
      className={itemClass}
      style={{ animationDelay: `${Math.min(index * 60, 400)}ms` }}
    >
      <label className="todo-checkbox">
        <input
          type="checkbox"
          checked={todo.completed}
          onChange={handleToggle}
          disabled={busy || editing || isRemoving}
          aria-label={`Mark "${todo.title}" as ${todo.completed ? 'incomplete' : 'complete'}`}
        />
        <span className="checkmark" />
      </label>

      {editing ? (
        <input
          className="todo-edit"
          value={editTitle}
          onChange={(e) => setEditTitle(e.target.value)}
          onBlur={handleSave}
          onKeyDown={(e) => {
            if (e.key === 'Enter') handleSave();
            if (e.key === 'Escape') {
              setEditing(false);
              setEditTitle(todo.title);
            }
          }}
          autoFocus
          maxLength={200}
          disabled={busy}
        />
      ) : (
        <span
          className="todo-title"
          onDoubleClick={() => !todo.completed && setEditing(true)}
        >
          {todo.title}
        </span>
      )}

      <div className="todo-actions">
        {!editing && !todo.completed && (
          <button
            type="button"
            className="btn-edit"
            onClick={() => setEditing(true)}
            disabled={busy || isRemoving}
            aria-label="Edit todo"
          >
            Edit
          </button>
        )}
        <button
          type="button"
          className="btn-delete"
          onClick={handleDelete}
          disabled={busy || isRemoving}
          aria-label="Delete todo"
        >
          Delete
        </button>
      </div>
    </li>
  );
}
