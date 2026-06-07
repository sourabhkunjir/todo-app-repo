export interface Todo {
  _id: string;
  title: string;
  completed: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface CreateTodoPayload {
  title: string;
}

export interface UpdateTodoPayload {
  title?: string;
  completed?: boolean;
}
