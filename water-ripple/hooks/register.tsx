import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

// -1 when still; otherwise how far the ripple has spread
const frame = atom({ plugin: 'water-ripple', key: 'frame' } as const, -1)

const FRAMES = 18
const FRAME_MS = 60

// Water from the ring outward: crest, then smaller waves, then calm
const CREST = ['≈', '∿', '~', '˜', '·']
const COLORS = ['claude', 'suggestion', 'suggestion', 'subtle', 'subtle']

// One row of water, the ring at `radius` cells either side of the center
export function rippleRow(width: number, f: number): { char: string; level: number }[] {
  const center = (width - 1) / 2
  const radius = ((f + 1) / FRAMES) * (center + 6)
  const fade = Math.floor((f / FRAMES) * 2)
  return Array.from({ length: width }, (_, x) => {
    const d = Math.abs(Math.abs(x - center) - radius)
    // Behind the ring the water keeps a gentle swell; ahead of it, still
    const behind = Math.abs(x - center) < radius
    let level = d < 1 ? 0 : d < 2.5 ? 1 : d < 4 ? 2 : behind ? 3 : 5
    level = Math.min(level + fade, 5)
    return { char: level === 5 ? ' ' : CREST[level], level }
  })
}

export const register: Register = on => {
  let timer: { cancel: () => void } | undefined

  on('prompt.submit', async ($, e, next) => {
    timer?.cancel()
    await update($, frame, () => 0)
    let f = 0
    // A ripple is decoration: if the timer is refused, the prompt still goes through
    try {
      timer = $.clock.every(FRAME_MS, () => {
        f += 1
        if (f >= FRAMES) timer?.cancel()
        void update($, frame, () => (f >= FRAMES ? -1 : f))
      })
    } catch {}
    return next(e)
  }).catch(($, e, next) => (next.called ? undefined : next(e)))

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const f = await read($, frame)
    if (f < 0 || e.props.hasSurvey) return next(e)

    const { Box, Text } = $.ui.resolve(e)
    const width = Math.max(10, e.props.bodyColumns || 60)
    // Group runs of the same level into one Text each
    const runs: { text: string; level: number }[] = []
    for (const c of rippleRow(width, f)) {
      const last = runs[runs.length - 1]
      if (last && last.level === c.level) last.text += c.char
      else runs.push({ text: c.char, level: c.level })
    }
    return (
      <Box>
        {runs.map((r, i) => (
          <Text key={String(i)} color={COLORS[Math.min(r.level, 4)]} bold={r.level === 0}>
            {r.text}
          </Text>
        ))}
      </Box>
    )
  })
}
