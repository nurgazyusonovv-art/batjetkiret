import axios from 'axios';

export function getErrorMessage(error: unknown, fallback: string): string {
  if (axios.isAxiosError(error)) {
    return (error.response?.data as { detail?: string } | undefined)?.detail ?? fallback;
  }

  if (error instanceof Error) {
    return error.message;
  }

  return fallback;
}
