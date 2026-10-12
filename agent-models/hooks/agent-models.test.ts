import { expect, test } from 'claude-code/testing'

import { prettyModel } from './register'

const BAND = { component: 'AbovePrompt', props: {} } as const

test('model names read nicely', () => {
  expect(prettyModel('claude-opus-5-5')).toBe('Opus 5.5')
  expect(prettyModel('claude-haiku-5-5')).toBe('Haiku 5.5')
  expect(prettyModel('claude-sonnet-5')).toBe('Sonnet 5')
  expect(prettyModel('haiku')).toBe('Haiku')
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
