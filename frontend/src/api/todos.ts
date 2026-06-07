import type { CreateTodoPayload, Todo, UpdateTodoPayload } from '../types/todo';
import { getApiUrl } from '../lib/apiUrl';

async function request<T>(url: string, options?: RequestInit): Promise<T> {
  const response = await fetch(getApiUrl(url), {
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
    ...options,
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ message: 'Request failed' }));
    throw new Error(error.message || 'Request failed');
  }

  return response.json();
}

export const todoApi = {
  getAll: () => request<Todo[]>('/todos'),

  create: (payload: CreateTodoPayload) =>
    request<Todo>('/todos', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),

  update: (id: string, payload: UpdateTodoPayload) =>
    request<Todo>(`/todos/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    }),

  delete: (id: string) =>
    request<{ message: string }>(`/todos/${id}`, {
      method: 'DELETE',
    }),
};
