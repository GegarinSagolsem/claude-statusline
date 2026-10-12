import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { AgentEntry } from '../types'

const agents = atom({ plugin: 'agent-models', key: 'agents' } as const, {})

const ACTIVE = ['pending', 'running', 'waiting']

// "claude-opus-5-5" -> "Opus 5.5"; aliases like "haiku" -> "Haiku"
export function prettyModel(model: string): string {
  const m = /^claude-([a-z]+)-(\d+)(?:-(\d+))?/.exec(model)
  if (m) {
    const family = m[1][0].toUpperCase() + m[1].slice(1)
    return m[3] ? `${family} ${m[2]}.${m[3]}` : `${family} ${m[2]}`
  }
  return model ? model[0].toUpperCase() + model.slice(1) : 'unknown'
}

function modelColor(model: string): string {
  if (/opus/i.test(model)) return 'claude'
  if (/sonnet/i.test(model)) return 'suggestion'
  if (/haiku/i.test(model)) return 'success'
  return 'subtle'
}

export const register: Register = on => {
  on('agent.spawn', async ($, e, next) => {
    // Prefix the task's description, which the built-in agents panel shows, with the model.
    // Only the Agent call's own model (or a fork's parent) is known before the spawn; when the
    // agent definition picks its model, the parent's is a guess and is marked with "?".
    let shown = e
    if (!e.workflow && !e.description.startsWith('[')) {
      const known = e.fork ? e.parentModel : e.model
      const label = known ? prettyModel(known) : `${prettyModel(e.parentModel)}?`
      shown = { ...e, description: `[${label}] ${e.description}` }
    }
    const result = await next(shown)
    if (result.agentId) {
      const id = result.agentId
      const entry: AgentEntry = {
        label: e.name || e.subagentType,
        description: e.description,
        model: result.model,
      }
      // Never let the label break a spawn: a failed write just leaves it unlabeled
      try {
        await update($, agents, all => ({ ...all, [id]: entry }))
      } catch {}
    }
    return result
  }).catch(($, e, next) => (next.called ? undefined : next(e)))

  on('turn.complete', async ($, e, next) => {
    const id = e.agentId
    if (id) {
      await update($, agents, all => {
        if (!(id in all)) return all
        const { [id]: _, ...rest } = all
        return rest
      })
    }
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const known = await read($, agents)
    // Drop agents the engine no longer runs; if the list is unavailable, trust turn.complete
    let rows = Object.entries(known)
    try {
      const live = new Set(
        (await $.agent.list()).filter(a => ACTIVE.includes(a.status)).map(a => a.id),
      )
      rows = rows.filter(([id]) => live.has(id))
    } catch {}
    if (rows.length === 0) return next(e)

    const { Box, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="column">
        {rows.map(([id, a]) => (
          <Box key={id}>
            <Text color={modelColor(a.model)} bold>
              [{prettyModel(a.model)}]
            </Text>
            <Text> {a.label} </Text>
            <Text dimColor wrap="truncate-end">
              {a.description}
            </Text>
          </Box>
        ))}
      </Box>
    )
  })
}
