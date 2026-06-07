import toast from 'react-hot-toast';

export const notify = {
  added: (title: string) => toast.success(`"${title}" added`),
  deleted: (title?: string) =>
    toast.success(title ? `"${title}" deleted` : 'Todo deleted'),
  completed: (title: string) => toast.success(`"${title}" marked as complete`),
  uncompleted: (title: string) => toast.success(`"${title}" marked as active`),
  updated: (title: string) => toast.success(`"${title}" updated`),
  error: (message: string) => toast.error(message),
};
