/**
 * Builds a full API URL. Accepts VITE_API_URL as either:
 * - https://your-backend.vercel.app
 * - https://your-backend.vercel.app/api
 * Paths like "/todos" are always resolved under "/api".
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
