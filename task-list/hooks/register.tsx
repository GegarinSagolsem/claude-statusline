import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'
import type { TaskItem, TaskStatus } from '../types'

const tasks = atom({ plugin: 'task-list', key: 'tasks' } as const, [])
const isMinimized = atom({ plugin: 'task-list', key: 'isMinimized' } as const, false)
const PREF = 'isMinimized'

const TASK_TOOLS = ['TaskCreate', 'TaskUpdate', 'TodoWrite', 'TaskList']

const DEMO: [string, string][] = [
  ['Read the existing status line script', 'Reading the status line script'],
  ['Write the task-list band', 'Writing the task-list band'],
  ['Add the minimize / expand toggle', 'Adding the toggle'],
  ['Test it and update the README', 'Testing and updating the README'],
]

const MARK: Record<TaskStatus, string> = { completed: '\u2714', in_progress: '\u25A0', pending: '\u25A1' }
const COLOR: Record<TaskStatus, string> = { completed: 'claude', in_progress: 'warning', pending: 'subtle' }

// TaskUpdate-style changes applied to the list; 'deleted' removes the task
export function applyUpdate(
  list: TaskItem[],
  u: { taskId: string; subject?: string; activeForm?: string; status?: TaskStatus | 'deleted' },
): TaskItem[] {
  if (u.status === 'deleted') return list.filter(t => t.id !== u.taskId)
  return list.map(t =>
    t.id !== u.taskId
      ? t
      : {
          ...t,
          ...(u.subject ? { subject: u.subject } : {}),
          ...(u.activeForm ? { activeForm: u.activeForm } : {}),
          ...(u.status && u.status !== 'deleted' ? { status: u.status } : {}),
        },
  )
}

// Flips minimized/expanded and remembers the choice across sessions
async function toggle($: EngineInterface): Promise<boolean> {
  let now = false
  await update($, isMinimized, v => (now = !v))
  try {
    await $.store.set(PREF, now)
  } catch {}
  return now
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    try {
      const saved = await $.store.get(PREF)
      if (typeof saved === 'boolean') await update($, isMinimized, () => saved)
    } catch {}
    try {
      await $.command.register({ name: 'todo', description: 'Minimize or expand the task list above the prompt (/todo demo plays a sample list)' })
    } catch {}
    return next(e)
  })

  let demo: { cancel: () => void } | undefined
  on('command.run', { command: 'todo' }, async ($, e) => {
    if (e.args.trim() === 'demo') {
      // A sample list that works itself through, one step every 3 seconds
      demo?.cancel()
      const sample: TaskItem[] = DEMO.map((d, i) => ({
        id: `demo${i}`,
        subject: d[0],
        activeForm: d[1],
        status: i === 0 ? 'in_progress' : 'pending',
      }))
      await update($, tasks, () => sample)
      let step = 0
      try {
        demo = $.clock.every(3000, () => {
          step += 1
          if (step >= sample.length) demo?.cancel()
          void update($, tasks, list =>
            list.map(t => {
              if (!t.id.startsWith('demo')) return t
              const i = Number(t.id.slice(4))
              return { ...t, status: i < step ? 'completed' : i === step ? 'in_progress' : 'pending' }
            }),
          )
        })
      } catch {}
      return { text: 'Demo started: watch the task list above the prompt. Click the arrow or type /todo to minimize or expand.' }
    }
    const min = await toggle($)
    return { text: min ? 'Task list minimized.' : 'Task list expanded.' }
  })

  // A finished list stays up until the next prompt, then clears
  on('prompt.submit', async ($, e, next) => {
    await update($, tasks, list => (list.length && list.every(t => t.status === 'completed') ? [] : list))
    return next(e)
  })

  on('tool.call', async ($, e, next) => {
    const ran = await next(e)
    if (ran.deny !== undefined || ran.isError) return ran
    try {
      // Real tasks arriving end a running demo and clear its sample rows
      if (TASK_TOOLS.includes(e.tool)) {
        demo?.cancel()
        demo = undefined
        await update($, tasks, list => list.filter(t => !t.id.startsWith('demo')))
      }
      if (e.tool === 'TaskCreate') {
        const r = ran.result as { task?: { id: string; subject: string } }
        if (r?.task) {
          const item: TaskItem = {
            id: r.task.id,
            subject: r.task.subject,
            activeForm: (e as { activeForm?: string }).activeForm,
            status: 'pending',
          }
          await update($, tasks, list => [...list.filter(t => t.id !== item.id), item])
        }
      } else if (e.tool === 'TaskUpdate') {
        await update($, tasks, list => applyUpdate(list, e as never))
      } else if (e.tool === 'TodoWrite') {
        const r = ran.result as { newTodos?: { content: string; status: TaskStatus; activeForm: string }[] }
        if (r?.newTodos) {
          await update($, tasks, () =>
            r.newTodos!.map((t, i) => ({ id: `todo${i}`, subject: t.content, activeForm: t.activeForm, status: t.status })),
          )
        }
      } else if (e.tool === 'TaskList') {
        // Resync from the engine's own list when Claude reads it
        const r = ran.result as { tasks?: { id: string; subject: string; status: TaskStatus }[] }
        if (r?.tasks) {
          await update($, tasks, old =>
            r.tasks!.map(t => ({ ...t, activeForm: old.find(o => o.id === t.id)?.activeForm })),
          )
        }
      }
    } catch {}
    return ran
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)
    const list = await read($, tasks)
    if (list.length === 0) return next(e)
    const min = await read($, isMinimized)
    const { Box, Text, Button } = $.ui.resolve(e)
    const done = list.filter(t => t.status === 'completed').length
    const current = list.find(t => t.status === 'in_progress') ?? list.find(t => t.status === 'pending')

    const header = (
      <Box key="head">
        <Button
          key="toggle"
          label={min ? '\u25B8' : '\u25BE'}
          hotkey="t"
          onPress={async () => {
            await toggle($)
          }}
        />
        <Text bold> Tasks </Text>
        <Text dimColor>
          {done}/{list.length} done
        </Text>
        {min && current ? (
          <Text wrap="truncate-end">
            {'  '}
            <Text color={COLOR[current.status]}>{MARK[current.status]}</Text> {current.activeForm && current.status === 'in_progress' ? current.activeForm : current.subject}
          </Text>
        ) : null}
        <Text dimColor>{min ? '  (t or /todo to expand)' : '  (t or /todo to minimize)'}</Text>
      </Box>
    )
    if (min) return header

    return (
      <Box flexDirection="column">
        {header}
        {list.map(t => (
          <Box key={t.id}>
            <Text>  </Text>
            <Text color={COLOR[t.status]}>{MARK[t.status]} </Text>
            <Text
              wrap="truncate-end"
              bold={t.status === 'in_progress'}
              dimColor={t.status === 'completed'}
              strikethrough={t.status === 'completed'}
            >
              {t.subject}
            </Text>
          </Box>
        ))}
      </Box>
    )
  })
}
