import type { Todo } from '../types/todo';
import { TodoItem } from './TodoItem';
import './TodoList.css';

interface TodoListProps {
  todos: Todo[];
  onToggle: (id: string, completed: boolean) => Promise<void>;
  onDelete: (id: string) => Promise<void>;
  onUpdate: (id: string, title: string) => Promise<void>;
}

export function TodoList({ todos, onToggle, onDelete, onUpdate }: TodoListProps) {
  if (todos.length === 0) {
    return (
      <div className="todo-empty">
        <span className="todo-empty__icon" aria-hidden="true">
          ✨
        </span>
        <p>No todos yet. Add one above to get started!</p>
      </div>
    );
  }

  const active = todos.filter((t) => !t.completed).length;
  const completed = todos.length - active;

  return (
    <div className="todo-list-wrapper">
      <p className="todo-stats">
        {active} active · {completed} completed
      </p>
      <ul className="todo-list">
        {todos.map((todo, index) => (
          <TodoItem
            key={todo._id}
            todo={todo}
            index={index}
            onToggle={onToggle}
            onDelete={onDelete}
            onUpdate={onUpdate}
          />
        ))}
      </ul>
    </div>
  );
}
