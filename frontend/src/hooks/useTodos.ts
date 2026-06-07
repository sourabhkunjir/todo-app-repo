import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { todoApi } from '../api/todos';
import { notify } from '../lib/notifications';
import type { CreateTodoPayload, Todo, UpdateTodoPayload } from '../types/todo';

export const todoKeys = {
  all: ['todos'] as const,
};

export function useTodos() {
  return useQuery({
    queryKey: todoKeys.all,
    queryFn: todoApi.getAll,
  });
}

export function useCreateTodo() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: CreateTodoPayload) => todoApi.create(payload),
    onSuccess: (newTodo) => {
      queryClient.setQueryData<Todo[]>(todoKeys.all, (old = []) => [newTodo, ...old]);
      notify.added(newTodo.title);
    },
    onError: (error) => {
      notify.error(error instanceof Error ? error.message : 'Failed to add todo');
    },
  });
}

export function useUpdateTodo() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: UpdateTodoPayload }) =>
      todoApi.update(id, payload),
    onSuccess: (updatedTodo, { payload }) => {
      queryClient.setQueryData<Todo[]>(todoKeys.all, (old = []) =>
        old.map((todo) => (todo._id === updatedTodo._id ? updatedTodo : todo))
      );

      if (payload.completed !== undefined) {
        if (updatedTodo.completed) {
          notify.completed(updatedTodo.title);
        } else {
          notify.uncompleted(updatedTodo.title);
        }
      } else if (payload.title !== undefined) {
        notify.updated(updatedTodo.title);
      }
    },
    onError: (error) => {
      notify.error(error instanceof Error ? error.message : 'Failed to update todo');
    },
  });
}

export function useDeleteTodo() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => todoApi.delete(id),
    onMutate: (id) => {
      const todos = queryClient.getQueryData<Todo[]>(todoKeys.all);
      const deleted = todos?.find((todo) => todo._id === id);
      return { title: deleted?.title };
    },
    onSuccess: (_data, id, context) => {
      queryClient.setQueryData<Todo[]>(todoKeys.all, (old = []) =>
        old.filter((todo) => todo._id !== id)
      );
      notify.deleted(context?.title);
    },
    onError: (error) => {
      notify.error(error instanceof Error ? error.message : 'Failed to delete todo');
    },
  });
}
