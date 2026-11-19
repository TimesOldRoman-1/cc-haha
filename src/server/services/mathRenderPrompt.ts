/**
 * Appended to every desktop chat session via `--append-system-prompt`.
 *
 * The desktop transcript renders math with KaTeX (see
 * desktop/src/components/markdown/MarkdownRenderer.tsx), while terminal and
 * VS Code chat surfaces do not. Keep this short: it rides the cached system
 * prefix on every turn, so every line costs tokens in every request.
 */
export const MATH_RENDER_PROMPT =
  '[公式渲染] 桌面端用 KaTeX：公式一律 LaTeX（行内 $...$，行间 $$...$$），化学式用 \\ce{}，中文用 \\text{}；不要用 Unicode 拼分数/积分，也不要用代码围栏包公式。'

/** Main sessions get the math hint alone; side chats keep their boundary. */
export function appendMathRenderPrompt(boundary?: string): string {
  return boundary ? `${MATH_RENDER_PROMPT}\n\n${boundary}` : MATH_RENDER_PROMPT
}
