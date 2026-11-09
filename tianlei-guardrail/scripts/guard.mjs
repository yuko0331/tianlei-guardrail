#!/usr/bin/env node
// 天磊安全围栏 WorkBuddy Hook（PoC）
// 从 stdin 读取 Hook 事件，调用防护模型 /v1/scan，按结果放行、拦截或提示，并写本地日志。
// 用法：node guard.mjs <prompt|tool|toolResult|stop>
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const CONFIG_DIR = path.join(os.homedir(), '.tianlei-guardrail');
const DEFAULTS = {
  scanUrl: 'http://192.168.120.68:18000/v1/scan',
  failMode: 'open',          // open=检测失败放行；closed=检测失败拦截
  blockLevels: ['block'],    // 达到这些等级时拦截；challenge 只记录
  timeoutMs: 5000,
  maxChars: 8000,            // 单次送检最大字符数（超出部分截断，PoC 限制）
  logFile: path.join(CONFIG_DIR, 'hook.log'),
};

const config = { ...DEFAULTS, ...readJson(path.join(CONFIG_DIR, 'hook.json')) };
const mode = process.argv[2];
const startedAt = Date.now();

let event = {};
try {
  event = JSON.parse(fs.readFileSync(0, 'utf8') || '{}');
} catch {
  process.exit(0); // 事件解析失败不影响用户使用
}

const text = extractText(mode, event).slice(0, config.maxChars);
if (!text.trim()) process.exit(0);

let verdict;
try {
  verdict = await scan(text);
} catch (error) {
  log({ action: config.failMode === 'closed' ? 'failBlock' : 'failOpen', error: String(error.message ?? error) });
  if (config.failMode === 'closed') block('安全检测暂不可用，已按策略阻止');
  process.exit(0);
}

const shouldBlock = config.blockLevels.includes(verdict.level);
const reason = `[天磊安全围栏] 检测到「${verdict.category || '风险内容'}」（风险分 ${verdict.score}）`;
log({ action: shouldBlock ? 'block' : verdict.level === 'challenge' ? 'warn' : 'allow', ...verdict });

if (shouldBlock) {
  if (mode === 'stop') {
    // 回答已经展示给用户，只能提示并留痕；不能用退出码 2，否则会让模型继续生成
    emit({ systemMessage: `${reason}，上一条回答命中安全策略，已记录` });
  } else {
    block(`${reason}，已拦截`);
  }
}
process.exit(0);

// ---------- 以下为辅助函数 ----------

function extractText(currentMode, ev) {
  switch (currentMode) {
    case 'prompt':
      return String(ev.prompt ?? '');
    case 'tool':
      return collectStrings(ev.tool_input).join('\n');
    case 'toolResult':
      return collectStrings(ev.tool_response).join('\n');
    case 'stop':
      return ev.stop_hook_active ? '' : lastAssistantText(ev.transcript_path);
    default:
      return '';
  }
}

// 递归收集对象里的字符串值，避免把 JSON 键名和符号送检
function collectStrings(value, out = []) {
  if (typeof value === 'string') out.push(value);
  else if (Array.isArray(value)) value.forEach(item => collectStrings(item, out));
  else if (value && typeof value === 'object') Object.values(value).forEach(item => collectStrings(item, out));
  return out;
}

// WorkBuddy 对话记录为 JSONL：{"type":"message","role":"assistant","content":[{"type":"output_text","text":"..."}]}
function lastAssistantText(transcriptPath) {
  if (!transcriptPath) return '';
  try {
    const lines = fs.readFileSync(transcriptPath, 'utf8').trim().split('\n').reverse();
    for (const line of lines) {
      let item;
      try { item = JSON.parse(line); } catch { continue; }
      const role = item.role ?? item.message?.role;
      if (item.type === 'message' && role === 'assistant') {
        const content = item.content ?? item.message?.content;
        return Array.isArray(content) ? content.map(part => part.text ?? '').join('') : String(content ?? '');
      }
    }
  } catch {
    // 读不到对话记录时跳过输出检测
  }
  return '';
}

async function scan(content) {
  const response = await fetch(config.scanUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: content, source: 'prompt' }),
    signal: AbortSignal.timeout(config.timeoutMs),
  });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const body = await response.json();
  // 与检测节点 http_adapter.go 的归一规则保持一致
  let level = String(body.level || body.action || '').toLowerCase();
  if (level === 'pass' || level === 'observe') level = 'allow';
  if (level === 'review' || level === 'warn') level = 'challenge';
  if (!['allow', 'challenge', 'block'].includes(level)) throw new Error(`未知检测等级：${level}`);
  return {
    level,
    score: Number(body.risk_score ?? 0).toFixed(2),
    category: body.classification?.level11 || body.results?.[0]?.category || '',
    gbSub: body.classification?.gb_sub?.name || '',
    traceId: body.trace_id || '',
  };
}

function block(message) {
  if (mode === 'tool') {
    emit({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: message } });
    process.exit(0);
  }
  if (mode === 'toolResult') {
    emit({ hookSpecificOutput: { hookEventName: 'PostToolUse', updatedToolOutput: `${message}：工具返回内容已被替换` } });
    process.exit(0);
  }
  process.stderr.write(message);
  process.exit(2); // UserPromptSubmit：阻止本次输入
}

function emit(payload) {
  process.stdout.write(JSON.stringify(payload));
}

function log(fields) {
  try {
    fs.mkdirSync(path.dirname(config.logFile), { recursive: true });
    const record = {
      time: new Date().toISOString(),
      mode,
      event: event.hook_event_name,
      tool: event.tool_name,
      session: event.session_id,
      latencyMs: Date.now() - startedAt,
      chars: text.length,
      preview: text.replace(/\s+/g, ' ').slice(0, 40),
      ...fields,
    };
    fs.appendFileSync(config.logFile, `${JSON.stringify(record)}\n`, { mode: 0o600 });
  } catch {
    // 日志失败不影响检测结果
  }
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return {};
  }
}
