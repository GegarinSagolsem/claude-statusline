export type AgentEntry = { label: string; description: string; model: string }

declare module 'claude-code' {
  interface PluginState {
    'agent-models': { agents: Record<string, AgentEntry> }
  }
}
