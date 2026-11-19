import { expect, mock, test } from 'claude-code/testing'

const BAND = { component: 'AbovePrompt', props: {} } as const

test('tasks show above the prompt and minimize to one line', async ($, on) => {
  const store = new Map<string, unknown>()
  on('store.get', (_$, e) => ({ value: store.get(e.key) }) as never)
  on('store.set', (_$, e) => (store.set(e.key, e.value), { value: undefined }) as never)
  let n = 0
  on('tool.call', (_$, e) => {
    if (e.tool === 'TaskCreate') return { result: { task: { id: String(++n), subject: (e as never as { subject: string }).subject } } } as never
    return { result: { success: true } } as never
  })
  on('command.run', () => ({ text: '' }) as never)
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e as never) as never as { Text: string }
    return h(Text, {}, 'engine default') as never
  })
  const call = (tool: string, input: object) => $.tool.call({ tool, tool_use_id: 't', ...input } as never)
  await call('TaskCreate', { subject: 'Write the module', description: 'd', activeForm: 'Writing the module' })
  await call('TaskCreate', { subject: 'Test it', description: 'd' })
  await call('TaskUpdate', { taskId: '1', status: 'in_progress' })

  let ui = await $.ui.mount({ plugin: 'task-list', surface: 'terminal', ...BAND } as never)
  expect(await ui.find({ type: 'Text', text: /Test it/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /0\/2 done/ })).toBeDefined()
  await ui.press({ key: 'toggle' })
  await ui.unmount()

  ui = await $.ui.mount({ plugin: 'task-list', surface: 'terminal', ...BAND } as never)
  expect(await ui.find({ type: 'Text', text: /Test it/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /Writing the module/ })).toBeDefined()
  await ui.unmount()
})

test('a running demo never touches real tasks', async ($, on) => {
  const clock = mock.clock(on)
  on('tool.call', () => ({ result: { task: { id: '7', subject: 'Real work' } } }) as never)
  on('command.run', () => ({ text: '' }) as never)
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e as never) as never as { Text: string }
    return h(Text, {}, 'engine default') as never
  })
  await $.command.run({ command: 'todo', args: 'demo' } as never)
  await $.tool.call({ tool: 'TaskCreate', tool_use_id: 't', subject: 'Real work', description: 'd' } as never)
  await clock.advance(20000)
  const ui = await $.ui.mount({ plugin: 'task-list', surface: 'terminal', component: 'AbovePrompt', props: {} } as never)
  expect(await ui.find({ type: 'Text', text: /Real work/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /0\/1 done/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /status line script/ })).toBeUndefined()
  await ui.unmount()
})
