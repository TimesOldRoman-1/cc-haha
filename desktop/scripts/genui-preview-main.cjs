// Minimal Electron host for the file:// GenUI preview smoke test.
const { app, BrowserWindow } = require('electron')
const path = require('node:path')
const fs = require('node:fs')

const theme = process.env.PREVIEW_THEME || 'white'
const shot = process.env.PREVIEW_SHOT || path.join(__dirname, '..', 'build-artifacts', 'genui-preview-shot.png')

app.whenReady().then(async () => {
  const win = new BrowserWindow({
    width: 1100,
    height: 1400,
    show: true,
    webPreferences: { contextIsolation: true },
  })
  win.webContents.on('console-message', (_event, level, message) => {
    console.log(`[console:${level}] ${String(message).slice(0, 300)}`)
  })
  win.webContents.on('did-fail-load', (_event, code, desc, url) => {
    console.log(`[did-fail-load] ${code} ${desc} ${url}`)
  })
  await win.loadFile(path.join(__dirname, '..', 'build-artifacts', 'genui-preview', 'genui-preview.html'), {
    query: { theme },
  })
  await new Promise((resolve) => setTimeout(resolve, 9000))
  const image = await win.webContents.capturePage()
  fs.writeFileSync(shot, image.toPNG())
  console.log(`[shot] ${shot}`)
  app.quit()
})
