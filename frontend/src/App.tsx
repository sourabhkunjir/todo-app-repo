import { TodoForm } from './components/TodoForm';
import { LoadingSpinner } from './components/LoadingSpinner';
import { TodoList } from './components/TodoList';
import {
  useCreateTodo,
  useDeleteTodo,
  useTodos,
  useUpdateTodo,
} from './hooks/useTodos';
import './App.css';

function App() {
  const { data: todos = [], isLoading, isError, error, refetch } = useTodos();
  const createTodo = useCreateTodo();
  const updateTodo = useUpdateTodo();
  const deleteTodo = useDeleteTodo();

  const displayError =
    isError && error instanceof Error ? error.message : isError ? 'Failed to load todos' : null;

  const handleAdd = async (title: string) => {
    await createTodo.mutateAsync({ title });
  };

  const handleToggle = async (id: string, completed: boolean) => {
    await updateTodo.mutateAsync({ id, payload: { completed } });
  };

  const handleDelete = async (id: string) => {
    await deleteTodo.mutateAsync(id);
  };

  const handleUpdate = async (id: string, title: string) => {
    await updateTodo.mutateAsync({ id, payload: { title } });
  };

  return (
    <div className="app">
      <header className="app-header">
        <h1>Todo App</h1>
        <p className="subtitle">Stay organized, one task at a time</p>
      </header>

      <main className="app-main">
        <TodoForm onAdd={handleAdd} />

        {displayError && (
          <div className="error-banner" role="alert">
            <span>{displayError}</span>
            <button type="button" onClick={() => refetch()}>
              Retry
            </button>
          </div>
        )}

        {isLoading ? (
          <LoadingSpinner />
        ) : (
          <TodoList
            todos={todos}
            onToggle={handleToggle}
            onDelete={handleDelete}
            onUpdate={handleUpdate}
          />
        )}
      </main>
    </div>
  );
}

export default App;
