import './LoadingSpinner.css';

interface LoadingSpinnerProps {
  message?: string;
}

export function LoadingSpinner({ message = 'Loading todos...' }: LoadingSpinnerProps) {
  return (
    <div className="loading-spinner" role="status" aria-live="polite">
      <div className="loading-spinner__ring" aria-hidden="true" />
      <p className="loading-spinner__text">{message}</p>
    </div>
  );
}
