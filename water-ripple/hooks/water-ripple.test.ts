import { expect, mock, test } from 'claude-code/testing'

import { rippleRow } from './register'

const BAND = { component: 'AbovePrompt', props: {} } as const

test('the ring spreads outward from the center', () => {
  const crest = (f: number) => rippleRow(41, f).findIndex(c => c.level === 0)
  expect(crest(0)).toBeGreaterThan(crest(8))
  expect(crest(8)).toBeGreaterThan(crest(15))
  expect(rippleRow(41, 3)).toHaveLength(41)
})

test('pressing Enter starts a ripple that settles back to calm', async ($, on) => {
  const clock = mock.clock(on)
  on('prompt.submit', (_$, e) => ({ text: e.text }) as never)
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e as never) as never as { Text: string }
    return h(Text, {}, 'engine default') as never
  })

  const before = await $.ui.mount({ plugin: 'water-ripple', surface: 'terminal', ...BAND } as never)
  expect(await before.find({ type: 'Text', text: /engine default/ })).toBeDefined()
  await before.unmount()

  await $.prompt.submit({ text: 'hello' } as never)
  const ui = await $.ui.mount({ plugin: 'water-ripple', surface: 'terminal', ...BAND } as never)
  expect(await ui.find({ type: 'Text', text: /[≈∿~]/ })).toBeDefined()
  await ui.unmount()

  await clock.advance(2000)
  const after = await $.ui.mount({ plugin: 'water-ripple', surface: 'desktop', ...BAND } as never)
  expect(await after.find({ type: 'Text', text: /engine default/ })).toBeDefined()
  await after.unmount()
})
