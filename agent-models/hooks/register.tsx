import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { AgentEntry } from '../types'

const agents = atom({ plugin: 'agent-models', key: 'agents' } as const, {})

const ACTIVE = ['pending', 'running', 'waiting']

// What a bare alias resolves to: the latest model of that family
const ALIASES: Record<string, string> = {
  opus: 'claude-opus-5-5',
  sonnet: 'claude-sonnet-5-5',
  haiku: 'claude-haiku-5-5',
  fable: 'claude-fable-5-1',
}

// "claude-opus-5-5" -> "Opus 5.5"; aliases like "haiku" -> "Haiku 5.5"
export function prettyModel(model: string): string {
  model = (model && ALIASES[model.toLowerCase()]) || model
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

// Per agent type, the model its definition pins (null: seen inheriting the parent's),
// learned from past spawns since a definition's model is unknown until the spawn resolves
const PINNED = 'pinned'
type Pinned = Record<string, string | null>

export const register: Register = on => {
  on('agent.spawn', async ($, e, next) => {
    // Prefix the task's description, which the built-in agents panel shows, with the model.
    // Only the Agent call's own model (or a fork's parent) is known before the spawn; otherwise
    // the model learned for this agent type is shown, and a type never seen yet gets the
    // parent's marked with "?".
    const decides = !e.fork && !e.model
    let pinned: Pinned = {}
    try {
      pinned = ((await $.store.get(PINNED)) as Pinned | undefined) ?? {}
    } catch {}
    let shown = e
    if (!e.workflow && !e.description.startsWith('[')) {
      const learned = pinned[e.subagentType]
      const label = !decides
        ? prettyModel(e.fork ? e.parentModel : e.model!)
        : learned
          ? prettyModel(learned)
          : learned === null
            ? prettyModel(e.parentModel)
            : `${prettyModel(e.parentModel)}?`
      shown = { ...e, description: `[${label}] ${e.description}` }
    }
    const result = await next(shown)
    if (decides && result.model) {
      // A model other than the parent's means the definition pins it; the same one tells
      // nothing new once a pinned model is known (a pin can match the parent's)
      const ran = prettyModel(result.model)
      const next_ = ran !== prettyModel(e.parentModel) ? ran : pinned[e.subagentType] ?? null
      if (pinned[e.subagentType] !== next_) {
        try {
          await $.store.set(PINNED, { ...pinned, [e.subagentType]: next_ })
        } catch {}
      }
    }
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
