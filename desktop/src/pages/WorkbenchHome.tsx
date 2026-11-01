import { useEffect, useMemo, type ReactNode } from 'react'
import {
  ArrowUpRight,
  CalendarClock,
  FolderGit2,
  LayoutDashboard,
  MessageSquare,
  Plus,
  Settings,
  Store,
} from 'lucide-react'
import { useSessionStore } from '../stores/sessionStore'
import { useTaskStore } from '../stores/taskStore'
import { useTabStore, MARKET_TAB_ID, SCHEDULED_TAB_ID, SETTINGS_TAB_ID } from '../stores/tabStore'
import { useUIStore } from '../stores/uiStore'
import { useProjectDisplayName } from '../stores/projectDisplayNameStore'
import { useTranslation } from '../i18n'
import { formatRelativeTime } from '../lib/formatRelativeTime'
import type { SessionListItem } from '../types/session'

/**
 * Desktop landing page: a project/session overview rather than another blank
 * composer. Every number here comes from stores the app already hydrates, so
 * opening this tab costs no extra backend round-trip beyond the scheduled-task
 * list (which is cached by the task store).
 */
export function WorkbenchHome() {
  const sessions = useSessionStore((s) => s.sessions)
  const tasks = useTaskStore((s) => s.tasks)
  const fetchTasks = useTaskStore((s) => s.fetchTasks)
  const t = useTranslation()

  useEffect(() => {
    void fetchTasks()
  }, [fetchTasks])

  const activeSessions = useMemo(
    () => sessions.filter((session) => !session.archived),
    [sessions],
  )

  const recent = useMemo(
    () =>
      [...activeSessions]
        .sort((a, b) => new Date(b.modifiedAt).getTime() - new Date(a.modifiedAt).getTime())
        .slice(0, 7),
    [activeSessions],
  )

  const projects = useMemo(() => {
    const byPath = new Map<string, { key: string; displayPath: string; count: number; lastAt: string }>()
    for (const session of activeSessions) {
      const key = session.projectPath || session.workDir || ''
      if (!key) continue
      // projectPath is the Claude Code project id (`c--Users-...`), not a real
      // path; workDir/projectRoot keep the readable folder name.
      const displayPath = session.workDir || session.projectRoot || session.projectPath
      const entry = byPath.get(key)
      if (entry) {
        entry.count += 1
        if (new Date(session.modifiedAt).getTime() > new Date(entry.lastAt).getTime()) {
          entry.lastAt = session.modifiedAt
        }
      } else {
        byPath.set(key, { key, displayPath, count: 1, lastAt: session.modifiedAt })
      }
    }
    return [...byPath.values()]
      .sort((a, b) => new Date(b.lastAt).getTime() - new Date(a.lastAt).getTime())
      .slice(0, 6)
  }, [activeSessions])

  const messageTotal = useMemo(
    () => activeSessions.reduce((total, session) => total + session.messageCount, 0),
    [activeSessions],
  )

  const hour = new Date().getHours()
  const greetingKey =
    hour < 12 ? 'workbench.greeting.morning' : hour < 18 ? 'workbench.greeting.afternoon' : 'workbench.greeting.evening'
  const today = useMemo(
    () => new Intl.DateTimeFormat(undefined, { month: 'long', day: 'numeric', weekday: 'long' }).format(new Date()),
    [],
  )

  const openSession = (session: SessionListItem) => {
    useTabStore.getState().openTab(session.id, session.title, 'session')
  }

  const startNewSession = () => {
    useUIStore.getState().startNewSessionDraft()
    useTabStore.getState().setActiveTab(null)
  }

  const openSpecial = (id: string, type: 'scheduled' | 'market' | 'settings', label: string) => {
    useTabStore.getState().openTab(id, label, type)
  }

  return (
    <div className="flex-1 overflow-y-auto bg-[var(--color-surface)]">
      <div className="mx-auto max-w-[960px] px-10 pb-16 pt-10">
        <header>
          <div className="flex items-center gap-2 text-[12px] font-medium uppercase tracking-[0.08em] text-[var(--color-text-tertiary)]">
            <LayoutDashboard size={14} strokeWidth={1.75} aria-hidden="true" />
            {t('workbench.title')}
          </div>
          <h1 className="mt-2 text-[26px] font-semibold leading-[1.25] text-[var(--color-text-primary)]">
            {t(greetingKey)}
          </h1>
          <p className="mt-1.5 text-[13px] leading-[1.6] text-[var(--color-text-tertiary)]">
            {today} · {t('workbench.subtitle', { count: activeSessions.length, projects: projects.length })}
          </p>
        </header>

        <div className="mt-7 grid grid-cols-4 gap-3">
          <QuickAction
            icon={<Plus size={16} strokeWidth={2} aria-hidden="true" />}
            label={t('workbench.quick.newSession')}
            onClick={startNewSession}
          />
          <QuickAction
            icon={<CalendarClock size={16} strokeWidth={1.75} aria-hidden="true" />}
            label={t('workbench.quick.scheduled')}
            onClick={() => openSpecial(SCHEDULED_TAB_ID, 'scheduled', t('sidebar.scheduled'))}
          />
          <QuickAction
            icon={<Store size={16} strokeWidth={1.75} aria-hidden="true" />}
            label={t('workbench.quick.market')}
            onClick={() => openSpecial(MARKET_TAB_ID, 'market', t('sidebar.extensions'))}
          />
          <QuickAction
            icon={<Settings size={16} strokeWidth={1.75} aria-hidden="true" />}
            label={t('workbench.quick.settings')}
            onClick={() => openSpecial(SETTINGS_TAB_ID, 'settings', t('sidebar.settings'))}
          />
        </div>

        <div className="mt-7 grid grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)] items-start gap-5">
          <section className="rounded-[var(--radius-xl)] border border-[var(--color-outline-variant)] bg-[var(--color-surface-container-low)]">
            <SectionHead title={t('workbench.recent.title')} count={activeSessions.length} />
            {recent.length === 0 ? (
              <EmptyRow text={t('workbench.recent.empty')} />
            ) : (
              <ul className="px-2 pb-2">
                {recent.map((session) => (
                  <SessionRow key={session.id} session={session} onOpen={() => openSession(session)} />
                ))}
              </ul>
            )}
          </section>

          <div className="flex flex-col gap-5">
            <section className="rounded-[var(--radius-xl)] border border-[var(--color-outline-variant)] bg-[var(--color-surface-container-low)]">
              <SectionHead title={t('workbench.projects.title')} count={projects.length} />
              {projects.length === 0 ? (
                <EmptyRow text={t('workbench.projects.empty')} />
              ) : (
                <ul className="px-2 pb-2">
                  {projects.map((project) => (
                    <ProjectRow
                      key={project.key}
                      projectKey={project.key}
                      displayPath={project.displayPath}
                      count={project.count}
                      lastAt={project.lastAt}
                    />
                  ))}
                </ul>
              )}
            </section>

            <section className="grid grid-cols-2 gap-2.5">
              <StatTile icon={<MessageSquare size={14} strokeWidth={1.75} />} label={t('workbench.stats.sessions')} value={activeSessions.length} />
              <StatTile icon={<FolderGit2 size={14} strokeWidth={1.75} />} label={t('workbench.stats.projects')} value={projects.length} />
              <StatTile icon={<CalendarClock size={14} strokeWidth={1.75} />} label={t('workbench.stats.tasks')} value={tasks.length} />
              <StatTile icon={<MessageSquare size={14} strokeWidth={1.75} />} label={t('workbench.stats.messages')} value={messageTotal} />
            </section>
          </div>
        </div>
      </div>
    </div>
  )
}

function QuickAction({ icon, label, onClick }: { icon: ReactNode; label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="group flex items-center gap-3 rounded-[var(--radius-lg)] border border-[var(--color-outline-variant)] bg-[var(--color-surface-container-low)] px-4 py-3 text-left transition-colors hover:border-[var(--color-outline)] hover:bg-[var(--color-surface-container)]"
    >
      <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-brand-soft)] text-[var(--color-brand)]">
        {icon}
      </span>
      <span className="truncate text-[13px] font-medium text-[var(--color-text-primary)]">{label}</span>
      <ArrowUpRight
        size={14}
        strokeWidth={1.75}
        aria-hidden="true"
        className="ml-auto shrink-0 text-[var(--color-text-tertiary)] opacity-0 transition-opacity group-hover:opacity-100"
      />
    </button>
  )
}

function SectionHead({ title, count }: { title: string; count: number }) {
  return (
    <div className="flex items-center justify-between px-4 pb-2 pt-4">
      <h2 className="text-[13px] font-medium text-[var(--color-text-secondary)]">{title}</h2>
      <span className="text-[12px] tabular-nums text-[var(--color-text-tertiary)]">{count}</span>
    </div>
  )
}

function SessionRow({ session, onOpen }: { session: SessionListItem; onOpen: () => void }) {
  const t = useTranslation()
  const projectName =
    useProjectDisplayName(session.projectPath) ??
    baseName(session.workDir || session.projectRoot || session.projectPath || '')
  return (
    <li>
      <button
        type="button"
        onClick={onOpen}
        className="group flex w-full items-center gap-3 rounded-[var(--radius-md)] px-2.5 py-2 text-left transition-colors hover:bg-[var(--color-surface-hover)]"
      >
        <span className="min-w-0 flex-1">
          <span className="block truncate text-[13px] font-medium text-[var(--color-text-primary)]">{session.title}</span>
          <span className="mt-0.5 block truncate text-[12px] text-[var(--color-text-tertiary)]">
            {projectName || t('workbench.noProject')} · {t('workbench.messageCount', { count: session.messageCount })}
          </span>
        </span>
        <span className="shrink-0 text-[12px] tabular-nums text-[var(--color-text-tertiary)]">
          {formatRelativeTime(session.modifiedAt, t)}
        </span>
      </button>
    </li>
  )
}

function ProjectRow({ projectKey, displayPath, count, lastAt }: { projectKey: string; displayPath: string; count: number; lastAt: string }) {
  const t = useTranslation()
  const name = useProjectDisplayName(projectKey) ?? baseName(displayPath)
  return (
    <li className="flex items-center gap-2.5 rounded-[var(--radius-md)] px-2.5 py-2">
      <FolderGit2 size={15} strokeWidth={1.75} aria-hidden="true" className="shrink-0 text-[var(--color-text-tertiary)]" />
      <span className="min-w-0 flex-1">
        <span className="block truncate text-[13px] text-[var(--color-text-primary)]">{name}</span>
        <span className="block truncate text-[12px] text-[var(--color-text-tertiary)]">{t('workbench.projects.meta', { count })}</span>
      </span>
      <span className="shrink-0 text-[12px] tabular-nums text-[var(--color-text-tertiary)]">{formatRelativeTime(lastAt, t)}</span>
    </li>
  )
}

function StatTile({ icon, label, value }: { icon: ReactNode; label: string; value: number }) {
  return (
    <div className="rounded-[var(--radius-lg)] border border-[var(--color-outline-variant)] bg-[var(--color-surface-container-low)] px-3.5 py-3">
      <div className="flex items-center gap-1.5 text-[12px] text-[var(--color-text-tertiary)]">
        <span className="text-[var(--color-text-tertiary)]">{icon}</span>
        <span className="truncate">{label}</span>
      </div>
      <div className="mt-1 text-[22px] font-semibold leading-none tabular-nums text-[var(--color-text-primary)]">{value}</div>
    </div>
  )
}

function EmptyRow({ text }: { text: string }) {
  return <p className="px-4 pb-5 pt-2 text-[13px] text-[var(--color-text-tertiary)]">{text}</p>
}

function baseName(path: string): string {
  const trimmed = path.replace(/[\\/]+$/, '')
  return trimmed.split(/[\\/]/).pop() || trimmed
}
