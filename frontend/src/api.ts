import type { ControlCmd } from './types'

export async function login(username: string, password: string): Promise<string> {
  const res = await fetch('/api/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  })
  if (!res.ok) throw new Error('Invalid username or password')
  const data = await res.json() as { token: string }
  return data.token
}

export async function sendControl(cmd: ControlCmd, token: string): Promise<void> {
  const res = await fetch('/api/control', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify(cmd),
  })
  if (res.status === 401) throw new Error('SESSION_EXPIRED')
  if (!res.ok) {
    const text = await res.text()
    throw new Error(`Control failed (${res.status}): ${text}`)
  }
}
