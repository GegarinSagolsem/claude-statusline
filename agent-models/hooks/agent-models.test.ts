import { expect, test } from 'claude-code/testing'

import { prettyModel } from './register'

const BAND = { component: 'AbovePrompt', props: {} } as const

test('model names read nicely', () => {
  expect(prettyModel('claude-opus-5-5')).toBe('Opus 5.5')
  expect(prettyModel('claude-haiku-5-5')).toBe('Haiku 5.5')
  expect(prettyModel('claude-sonnet-5')).toBe('Sonnet 5')
  expect(prettyModel('haiku')).toBe('Haiku 5.5')
  expect(prettyModel('Sonnet')).toBe('Sonnet 5.5')
})

test('the task description carries the model for the agents panel', async ($, on) => {
  const seen: string[] = []
  on('agent.spawn', (_$, e) => {
    seen.push(e.description)
    return { model: e.model ?? e.parentModel, agentId: `a${seen.length}` }
  })
  const base = { tool_use_id: 't', prompt: 'p', subagentType: 'general-purpose', parentModel: 'claude-opus-5-5', fork: false }
  await $.agent.spawn({ ...base, description: 'Push repo', model: 'haiku' } as never)
  await $.agent.spawn({ ...base, description: 'Look around' } as never)
  await $.agent.spawn({ ...base, description: '[Haiku 5.5] Already labeled', model: 'haiku' } as never)
  expect(seen).toEqual(['[Haiku 5.5] Push repo', '[Opus 5.5?] Look around', '[Haiku 5.5] Already labeled'])
})

test('an agent type that pins its own model is labeled with it once seen', async ($, on) => {
  const store = new Map<string, unknown>()
  on('store.get', (_$, e) => ({ value: store.get(e.key) }) as never)
  on('store.set', (_$, e) => (store.set(e.key, e.value), { value: undefined }) as never)
  const seen: string[] = []
  on('agent.spawn', (_$, e) => {
    seen.push(e.description)
    const model = e.model ?? (e.subagentType === 'web-fetch' ? 'claude-haiku-5-5' : e.parentModel)
    return { model, agentId: `a${seen.length}` }
  })
  const base = { tool_use_id: 't', prompt: 'p', parentModel: 'claude-opus-5-5', fork: false }
  await $.agent.spawn({ ...base, subagentType: 'web-fetch', description: 'Fetch docs' } as never)
  await $.agent.spawn({ ...base, subagentType: 'web-fetch', description: 'Fetch more' } as never)
  await $.agent.spawn({ ...base, subagentType: 'Explore', description: 'Look' } as never)
  await $.agent.spawn({ ...base, subagentType: 'Explore', description: 'Look again' } as never)
  expect(seen).toEqual([
    '[Opus 5.5?] Fetch docs',
    '[Haiku 5.5] Fetch more',
    '[Opus 5.5?] Look',
    '[Opus 5.5] Look again',
  ])
})

test('a running subagent shows with its model, and leaves when done', async ($, on) => {
  on('agent.spawn', () => ({ model: 'claude-haiku-5-5', agentId: 'a1' }))
  on('turn.complete', () => ({ text: '' }) as never)
  // Stands for the engine's own band: drawn when the mod has nothing to show
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e as never) as never as { Text: string }
    return h(Text, {}, 'engine default') as never
  })

  await $.agent.spawn({
    tool_use_id: 't1',
    prompt: 'look',
    description: 'Find the config',
    subagentType: 'Explore',
  } as never)

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ plugin: 'agent-models', surface, ...BAND } as never)
    expect(await ui.find({ type: 'Text', text: /Haiku 5\.5/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /Explore/ })).toBeDefined()
    await ui.unmount()
  }

  await $.turn.complete({ agentId: 'a1', reason: 'answer', answer: 'done' } as never)
  const ui = await $.ui.mount({ plugin: 'agent-models', surface: 'terminal', ...BAND } as never)
  expect(await ui.find({ type: 'Text', text: /Haiku 5\.5/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /engine default/ })).toBeDefined()
  await ui.unmount()
})
