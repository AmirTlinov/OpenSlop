#!/usr/bin/env node
import { execFile, spawn } from 'node:child_process';
import { access } from 'node:fs/promises';
import { constants } from 'node:fs';

const BRIDGE = Object.freeze({
  name: 'claude-bridge',
  version: '0.2.0',
  transport: 'stdio-json',
});

const DEFAULT_PROOF_MODEL = process.env.OPEN_SLOP_CLAUDE_PROOF_MODEL || 'haiku';
const DEFAULT_PROOF_MAX_BUDGET_USD = process.env.OPEN_SLOP_CLAUDE_PROOF_MAX_BUDGET_USD || '0.05';
const configuredProofTimeoutMs = Number(process.env.OPEN_SLOP_CLAUDE_PROOF_TIMEOUT_MS || '90000');
const DEFAULT_PROOF_TIMEOUT_MS = Number.isFinite(configuredProofTimeoutMs) && configuredProofTimeoutMs > 0
  ? configuredProofTimeoutMs
  : 90000;

const args = process.argv.slice(2);
if (isStatusCommand(args)) {
  writeJson(await runtimeStatus());
} else if (isTurnProofCommand(args)) {
  const result = await readStdinText(128 * 1024)
    .then((prompt) => turnProof(prompt))
    .catch((error) => turnProofUnavailable(`failed to read proof prompt from stdin: ${error.message}`));
  writeJson(result);
  process.exitCode = result.success ? 0 : 1;
} else {
  writeJson(unavailable(`unsupported claude-bridge command: ${args.join(' ') || '<empty>'}`));
  process.exitCode = 2;
}

function isStatusCommand(args) {
  if (args.length === 0) {
    return true;
  }
  if (args.length === 1) {
    return args[0] === 'status' || args[0] === '--json';
  }
  if (args.length === 2) {
    return args[0] === 'status' && args[1] === '--json';
  }
  return false;
}

function isTurnProofCommand(args) {
  if (args.length === 1) {
    return args[0] === 'turn-proof';
  }
  if (args.length === 2) {
    return args[0] === 'turn-proof' && args[1] === '--json';
  }
  return false;
}

function writeJson(payload) {
  process.stdout.write(`${JSON.stringify(payload)}\n`);
}

async function runtimeStatus() {
  const warnings = [];
  const binaryPath = await findClaudeBinary(warnings);
  if (!binaryPath) {
    return unavailable('claude binary not found in PATH', warnings);
  }

  const [versionResult, helpResult] = await Promise.all([
    run(binaryPath, ['--version'], 3_000),
    run(binaryPath, ['--help'], 3_000),
  ]);

  if (!versionResult.ok) {
    warnings.push(`claude --version failed: ${versionResult.message}`);
  }

  if (!helpResult.ok) {
    warnings.push(`claude --help failed: ${helpResult.message}`);
  }

  const helpText = helpResult.ok ? helpResult.stdout + helpResult.stderr : '';
  const helpSignals = collectHelpSignals(helpText);

  return {
    kind: 'claude_runtime_status',
    runtime: 'claude-code-cli',
    available: versionResult.ok,
    bridge: BRIDGE,
    binaryPath,
    cliVersion: versionResult.ok ? clean(versionResult.stdout || versionResult.stderr) : null,
    nodeVersion: process.version,
    checkedAt: new Date().toISOString(),
    capabilities: capabilitiesFromSignals(helpSignals),
    helpSignals,
    warnings,
  };
}

async function turnProof(prompt) {
  const cleanPrompt = String(prompt || '').trim();
  if (!cleanPrompt) {
    return turnProofUnavailable('missing proof prompt');
  }

  const status = await runtimeStatus();
  if (!status.available || !status.binaryPath) {
    return turnProofUnavailable('claude runtime unavailable', status, status.warnings);
  }

  return runClaudeTurn(status.binaryPath, cleanPrompt, Buffer.byteLength(cleanPrompt, 'utf8'));
}

function unavailable(reason, extraWarnings = []) {
  return {
    kind: 'claude_runtime_status',
    runtime: 'claude-code-cli',
    available: false,
    bridge: BRIDGE,
    binaryPath: null,
    cliVersion: null,
    nodeVersion: process.version,
    checkedAt: new Date().toISOString(),
    capabilities: {
      runtimeDiscovery: false,
      cliPrintJson: false,
      cliStreamJsonOutput: false,
      cliStreamJsonInput: false,
      cliSessionResume: false,
      cliExplicitSessionId: false,
      cliPermissionMode: false,
      cliMcpConfig: false,
      bridgeTurnStreaming: false,
      bridgeSessionMirror: false,
      bridgeNativeApprovals: false,
      bridgeTracingHandoff: false,
    },
    helpSignals: [],
    warnings: [reason, ...extraWarnings],
  };
}

function turnProofUnavailable(reason, status = null, extraWarnings = []) {
  return {
    kind: 'claude_turn_proof_result',
    runtime: 'claude-code-cli',
    success: false,
    runtimeAvailable: status?.available === true,
    bridge: BRIDGE,
    model: null,
    sessionId: null,
    resultText: '',
    assistantText: '',
    eventCount: 0,
    eventTypes: [],
    toolUseCount: 0,
    malformedEventCount: 0,
    sessionPersistence: 'disabled',
    totalCostUsd: null,
    durationMs: null,
    exitCode: null,
    signal: null,
    timedOut: false,
    promptBytes: 0,
    warnings: [reason, ...extraWarnings],
  };
}

async function findClaudeBinary(warnings) {
  const explicit = process.env.CLAUDE_CODE_BINARY;
  if (explicit) {
    try {
      await access(explicit, constants.X_OK);
      return explicit;
    } catch (error) {
      warnings.push(`CLAUDE_CODE_BINARY is not executable: ${explicit}: ${error.message}`);
    }
  }

  const result = await run('command', ['-v', 'claude'], 2_000, { shell: true });
  if (result.ok) {
    const candidate = clean(result.stdout).split('\n')[0];
    if (candidate) {
      return candidate;
    }
  }

  const whichResult = await run('which', ['claude'], 2_000);
  if (whichResult.ok) {
    const candidate = clean(whichResult.stdout).split('\n')[0];
    if (candidate) {
      return candidate;
    }
  }

  if (result.message) {
    warnings.push(`command -v claude failed: ${result.message}`);
  }
  return null;
}

function collectHelpSignals(helpText) {
  const checks = [
    ['--print', /(?:^|\s)--print(?:\s|,|$)/],
    ['--output-format', /--output-format/],
    ['--output-format=stream-json', /stream-json/],
    ['--input-format=stream-json', /--input-format[\s\S]*stream-json/],
    ['--resume', /--resume/],
    ['--continue', /--continue/],
    ['--session-id', /--session-id/],
    ['--permission-mode', /--permission-mode/],
    ['--mcp-config', /--mcp-config/],
  ];

  return checks
    .filter(([, pattern]) => pattern.test(helpText))
    .map(([signal]) => signal);
}

function capabilitiesFromSignals(signals) {
  const has = new Set(signals);
  return {
    runtimeDiscovery: true,
    cliPrintJson: has.has('--print') && has.has('--output-format'),
    cliStreamJsonOutput: has.has('--output-format=stream-json'),
    cliStreamJsonInput: has.has('--input-format=stream-json'),
    cliSessionResume: has.has('--resume') || has.has('--continue'),
    cliExplicitSessionId: has.has('--session-id'),
    cliPermissionMode: has.has('--permission-mode'),
    cliMcpConfig: has.has('--mcp-config'),
    bridgeTurnStreaming: false,
    bridgeSessionMirror: false,
    bridgeNativeApprovals: false,
    bridgeTracingHandoff: false,
  };
}

function runClaudeTurn(binaryPath, prompt, promptBytes) {
  return new Promise((resolve) => {
    const argv = [
      '-p',
      '--verbose',
      '--output-format',
      'stream-json',
      '--input-format',
      'text',
      '--tools',
      '',
      '--permission-mode',
      'dontAsk',
      '--no-session-persistence',
      '--model',
      DEFAULT_PROOF_MODEL,
      '--max-budget-usd',
      DEFAULT_PROOF_MAX_BUDGET_USD,
    ];

    const eventTypes = new Set();
    const warnings = [];
    const assistantTextParts = [];
    let eventCount = 0;
    let toolUseCount = 0;
    let malformedEventCount = 0;
    let sessionId = null;
    let model = null;
    let resultEvent = null;
    let stderr = '';
    let stdoutBuffer = '';
    let timedOut = false;

    const child = spawn(binaryPath, argv, {
      cwd: process.cwd(),
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    const timeout = setTimeout(() => {
      timedOut = true;
      warnings.push(`claude turn proof timed out after ${DEFAULT_PROOF_TIMEOUT_MS}ms`);
      child.kill('SIGTERM');
    }, DEFAULT_PROOF_TIMEOUT_MS);

    child.stdout.setEncoding('utf8');
    child.stdout.on('data', (chunk) => {
      stdoutBuffer += chunk;
      let newlineIndex;
      while ((newlineIndex = stdoutBuffer.indexOf('\n')) >= 0) {
        const line = stdoutBuffer.slice(0, newlineIndex).trim();
        stdoutBuffer = stdoutBuffer.slice(newlineIndex + 1);
        if (line) {
          handleStreamLine(line);
        }
      }
    });

    child.stderr.setEncoding('utf8');
    child.stderr.on('data', (chunk) => {
      stderr += chunk;
      if (stderr.length > 16_384) {
        stderr = stderr.slice(-16_384);
      }
    });

    child.on('error', (error) => {
      warnings.push(`failed to launch claude turn: ${error.message}`);
    });

    child.stdin.on('error', (error) => {
      warnings.push(`failed to write proof prompt to claude stdin: ${error.message}`);
    });

    child.on('close', (code, signal) => {
      clearTimeout(timeout);
      const leftover = stdoutBuffer.trim();
      if (leftover) {
        handleStreamLine(leftover);
      }

      if (signal) {
        warnings.push(`claude exited with signal ${signal}`);
      }
      if (stderr.trim()) {
        warnings.push(`stderr: ${stderr.trim()}`);
      }

      const assistantText = assistantTextParts.join('').trim();
      const resultText = clean(resultEvent?.result || assistantText);
      const resultSuccess = resultEvent?.subtype === 'success' && resultEvent?.is_error !== true;
      const success =
        code === 0 &&
        resultSuccess &&
        resultText.length > 0 &&
        !timedOut &&
        malformedEventCount === 0 &&
        toolUseCount === 0;

      resolve({
        kind: 'claude_turn_proof_result',
        runtime: 'claude-code-cli',
        success,
        runtimeAvailable: true,
        bridge: BRIDGE,
        model: resultEvent?.modelUsage ? Object.keys(resultEvent.modelUsage)[0] : model,
        sessionId: resultEvent?.session_id || sessionId,
        resultText,
        assistantText,
        eventCount,
        eventTypes: Array.from(eventTypes).sort(),
        toolUseCount,
        malformedEventCount,
        sessionPersistence: 'disabled',
        totalCostUsd: typeof resultEvent?.total_cost_usd === 'number' ? resultEvent.total_cost_usd : null,
        durationMs: typeof resultEvent?.duration_ms === 'number' ? resultEvent.duration_ms : null,
        exitCode: code,
        signal,
        timedOut,
        promptBytes,
        warnings,
      });
    });

    child.stdin.end(`${prompt}\n`);

    function handleStreamLine(line) {
      eventCount += 1;
      let event;
      try {
        event = JSON.parse(line);
      } catch (error) {
        malformedEventCount += 1;
        warnings.push(`invalid stream-json line: ${error.message}`);
        return;
      }

      const type = event.type || 'unknown';
      const subtype = event.subtype ? `:${event.subtype}` : '';
      eventTypes.add(`${type}${subtype}`);

      if (event.session_id && !sessionId) {
        sessionId = event.session_id;
      }
      if (event.model && !model) {
        model = event.model;
      }
      if (event.type === 'system' && event.model) {
        model = event.model;
      }
      if (event.type === 'result') {
        resultEvent = event;
      }
      if (event.type === 'assistant' && event.message?.model) {
        model = event.message.model;
      }
      if (event.type === 'assistant' && Array.isArray(event.message?.content)) {
        for (const item of event.message.content) {
          if (item?.type === 'tool_use') {
            toolUseCount += 1;
          }
          if (item?.type === 'text' && typeof item.text === 'string') {
            assistantTextParts.push(item.text);
          }
        }
      }
    }
  });
}

function run(command, args, timeoutMs, options = {}) {
  return new Promise((resolve) => {
    execFile(command, args, { timeout: timeoutMs, maxBuffer: 1024 * 1024, ...options }, (error, stdout, stderr) => {
      if (error) {
        resolve({ ok: false, stdout: stdout ?? '', stderr: stderr ?? '', message: error.message });
        return;
      }
      resolve({ ok: true, stdout: stdout ?? '', stderr: stderr ?? '', message: '' });
    });
  });
}

function readStdinText(maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    process.stdin.on('data', (chunk) => {
      total += chunk.length;
      if (total > maxBytes) {
        reject(new Error(`stdin payload exceeds ${maxBytes} bytes`));
        process.stdin.destroy();
        return;
      }
      chunks.push(chunk);
    });
    process.stdin.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    process.stdin.on('error', reject);
  });
}

function clean(value) {
  return String(value ?? '').trim();
}
