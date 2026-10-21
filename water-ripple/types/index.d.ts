export type Frame = number

declare module 'claude-code' {
  interface PluginState {
    'water-ripple': { frame: Frame }
  }
}
