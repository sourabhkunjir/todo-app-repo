/**
 * Builds a full API URL. When VITE_API_URL is empty, uses relative paths
 * (e.g. /api/todos) so nginx can proxy to the backend.
 * When set, accepts origin with or without a trailing /api segment.
 */
export function getApiUrl(path: string): string {
  const configured = (import.meta.env.VITE_API_URL ?? '').trim().replace(/\/+$/, '');
  const origin = configured.replace(/\/api$/, '');

  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  const apiPath = normalizedPath.startsWith('/api')
    ? normalizedPath
    : `/api${normalizedPath}`;

  if (origin) {
    return `${origin}${apiPath}`;
  }

  return apiPath;
}
