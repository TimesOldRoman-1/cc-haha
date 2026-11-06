import { existsSync } from 'node:fs'
import path from 'node:path'
import type { BrowserWindow } from 'electron'

export type AppUserModelIdHost = {
  setAppUserModelId(id: string): void
}

// Personal fork: upstream uses build.appId (com.claude-code-haha.desktop), which
// collides with an official install sharing the same Start Menu shortcut. Windows
// then routes toast activations to the official exe. Keep a fork-specific AUMID so
// this build's notifications open this build; taskbar pinning is separated too.
export const WINDOWS_APP_USER_MODEL_ID = 'com.claude-code-haha.desktop.personal'

export function applyWindowsAppUserModelId(
  app: AppUserModelIdHost,
  platform: NodeJS.Platform = process.platform,
  appUserModelId: string = WINDOWS_APP_USER_MODEL_ID,
): boolean {
  if (platform !== 'win32') return false
  app.setAppUserModelId(appUserModelId)
  return true
}

type WindowsIconPaths = {
  desktopRoot: string
  resourcesPath: string
}

// BrowserWindow can read the bundled icon through Electron's ASAR-aware file
// APIs, but Explorer cannot. Keep a real ICO beside app.asar for new taskbar pins.
export function resolveWindowsWindowIcon(
  paths: WindowsIconPaths,
  platform: NodeJS.Platform = process.platform,
): string | undefined {
  if (platform !== 'win32') return undefined
  return [
    path.join(paths.resourcesPath, 'app-icon.ico'),
    path.join(paths.desktopRoot, 'src-tauri', 'icons', 'icon.ico'),
  ].find(candidate => existsSync(candidate))
}

export function applyWindowsTaskbarIdentity(
  window: Pick<BrowserWindow, 'setAppDetails'>,
  paths: WindowsIconPaths & { isPackaged: boolean, executablePath: string },
  platform: NodeJS.Platform = process.platform,
): boolean {
  // A development launch targets electron.exe and needs the entry script and
  // dev-server environment. Do not turn its button into a production shortcut.
  if (platform !== 'win32' || !paths.isPackaged) return false
  const externalIcon = path.join(paths.resourcesPath, 'app-icon.ico')
  window.setAppDetails({
    appId: WINDOWS_APP_USER_MODEL_ID,
    appIconPath: existsSync(externalIcon) ? externalIcon : paths.executablePath,
    appIconIndex: 0,
    relaunchCommand: `"${paths.executablePath}"`,
    relaunchDisplayName: 'Claude Code Haha',
  })
  return true
}
