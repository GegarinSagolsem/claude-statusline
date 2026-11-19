export type TaskStatus = 'pending' | 'in_progress' | 'completed'
export type TaskItem = { id: string; subject: string; activeForm?: string; status: TaskStatus }

declare module 'claude-code' {
  interface PluginState {
    'task-list': { tasks: TaskItem[]; isMinimized: boolean }
  }
}
