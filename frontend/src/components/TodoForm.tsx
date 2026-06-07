import { useState } from 'react';
import type { FormEvent } from 'react';
import './TodoForm.css';

interface TodoFormProps {
  onAdd: (title: string) => Promise<void>;
}

export function TodoForm({ onAdd }: TodoFormProps) {
  const [title, setTitle] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const trimmed = title.trim();
    if (!trimmed || submitting) return;

    setSubmitting(true);
    try {
      await onAdd(trimmed);
      setTitle('');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form
      className={`todo-form ${submitting ? 'todo-form--submitting' : ''}`}
      onSubmit={handleSubmit}
    >
      <input
        type="text"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        placeholder="What needs to be done?"
        maxLength={200}
        disabled={submitting}
        aria-label="New todo title"
      />
      <button type="submit" disabled={!title.trim() || submitting}>
        {submitting ? 'Adding...' : 'Add'}
      </button>
    </form>
  );
}
