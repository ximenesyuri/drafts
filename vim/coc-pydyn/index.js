const {
  workspace,
  languages,
  CompletionItemKind,
  Uri,
} = require('coc.nvim');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * Try to auto-detect a project venv python by:
 * - walking up from the file's directory
 * - looking for pyproject.toml
 * - using <that-dir>/.venv/bin/python (or .venv/Scripts/python.exe on Windows)
 */
function detectVenvPython(filename) {
  const startDir = filename ? path.dirname(filename) : process.cwd();
  let dir = startDir;

  while (true) {
    const pyproject = path.join(dir, 'pyproject.toml');
    if (fs.existsSync(pyproject)) {
      const candUnix = path.join(dir, '.venv', 'bin', 'python');
      const candWin = path.join(dir, '.venv', 'Scripts', 'python.exe');
      if (fs.existsSync(candUnix)) return candUnix;
      if (fs.existsSync(candWin)) return candWin;
      break;
    }

    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  return null;
}

/**
 * Resolve python path:
 * - 1st: pydyn.pythonPath from coc-settings.json (if non-empty)
 * - 2nd: auto-detect from pyproject.toml + .venv
 * - 3rd: 'python3'
 */
function getPythonPath(filename) {
  const config = workspace.getConfiguration('pydyn');
  const configured = (config.get('pythonPath', '') || '').trim();
  if (configured) {
    return configured;
  }

  const detected = detectVenvPython(filename);
  if (detected) {
    return detected;
  }

  return 'python3';
}

function cleanSourceForCompletion(source, currentLine) {
  const lines = source.split(/\r?\n/);
  
  if (currentLine < lines.length) {
    const origLine = lines[currentLine];
    const indentMatch = origLine.match(/^\s*/);
    const indent = indentMatch ? indentMatch[0] : '';
    lines[currentLine] = indent + 'pass  # coc-pydyn: neutered line';
  }
  
  return lines.map(line => {
    if (line.match(/\b(run|start|serve|listen|main)\s*\(/)) {
      const indentMatch = line.match(/^(\s*)/);
      const indent = indentMatch ? indentMatch[1] : '';
      return indent + 'pass  # coc-pydyn: neutered execution';
    }
    
    if (line.match(/^\s*if\s+__name__\s*==/)) {
      const indentMatch = line.match(/^(\s*)/);
      const indent = indentMatch ? indentMatch[1] : '';
      return indent + 'if False:  # coc-pydyn: disabled main block';
    }
    
    return line;
  }).join('\n');
}

const PY_HELPER = `
import sys, os, json, types, traceback, io
from contextlib import redirect_stdout, redirect_stderr
import signal

def timeout_handler(signum, frame):
    print("[]")
    sys.exit(1)

if hasattr(signal, 'SIGALRM'):
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(2)

def compute_sys_paths(filename):
    dirname = os.path.dirname(filename)
    add_paths = []
    if dirname:
        add_paths.append(dirname)

    path = dirname
    last_pkg = None
    while path and path != os.path.dirname(path):
        if os.path.isfile(os.path.join(path, "__init__.py")):
            last_pkg = path
            path = os.path.dirname(path)
        else:
            break

    if last_pkg:
        project_root = os.path.dirname(last_pkg)
        if project_root and project_root not in add_paths:
            add_paths.append(project_root)

    return add_paths

def main():
    if len(sys.argv) < 4:
        print("[]")
        return

    filename, expr, attr_prefix = sys.argv[1:4]
    src = sys.stdin.read()

    add_paths = compute_sys_paths(filename)
    remove_paths = []
    for p in add_paths:
        if p and p not in sys.path:
            sys.path.insert(0, p)
            remove_paths.append(p)

    try:
        mod = types.ModuleType("__dyn__")
        mod.__file__ = filename
        g = mod.__dict__

        stdout_buf = io.StringIO()
        stderr_buf = io.StringIO()

        try:
            with redirect_stdout(stdout_buf), redirect_stderr(stderr_buf):
                code = compile(src, filename, "exec")
                exec(code, g, g)
                obj = eval(expr, g, g)
        except Exception as e:
            print("[]")
            sys.exit(0)

        try:
            names = []
            for a in dir(obj):
                if not a.startswith(attr_prefix):
                    continue
                names.append(a)
        except Exception:
            names = []

        print(json.dumps(names))
    except Exception:
        print("[]")
    finally:
        for p in remove_paths:
            try:
                sys.path.remove(p)
            except ValueError:
                pass

if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("[]")
`;

function getDynamicAttrs(pythonPath, filename, expr, attrPrefix, source) {
  return new Promise((resolve) => {
    console.error('[coc-pydyn] spawning python:', pythonPath);

    const child = spawn(
      pythonPath,
      ['-c', PY_HELPER, filename, expr, attrPrefix]
    );

    let stdoutData = '';
    let stderrData = '';

    child.stdout.on('data', (data) => {
      stdoutData += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderrData += data.toString();
    });

    child.on('close', (code) => {
      if (code !== 0 && code !== null) {
        if (stderrData) {
          console.error('[coc-pydyn] python stderr:\n' + stderrData);
        } else {
          console.error('[coc-pydyn] python exited with code', code);
        }
        resolve([]);
        return;
      }

      const stdout = stdoutData.trim();
      if (!stdout) {
        resolve([]);
        return;
      }

      try {
        const arr = JSON.parse(stdout);
        if (Array.isArray(arr)) {
          resolve(arr);
        } else {
          resolve([]);
        }
      } catch (e) {
        console.error('[coc-pydyn] JSON parse error:', e.message, 'output:', stdout);
        resolve([]);
      }
    });

    child.on('error', (error) => {
      console.error('[coc-pydyn] spawn error:', error);
      resolve([]);
    });

    child.stdin.write(source);
    child.stdin.end();

    const timeout = setTimeout(() => {
      console.error('[coc-pydyn] python execution timed out, killing process');
      child.kill('SIGKILL');
      resolve([]);
    }, 2000);

    child.on('close', () => {
      clearTimeout(timeout);
    });
  });
}

async function activate(context) {
  console.error('[coc-pydyn] activated');

  const provider = {
    triggerCharacters: ['.'],

    provideCompletionItems: async (document, position) => {
      console.error('[coc-pydyn] completion requested');

      if (document.languageId !== 'python') {
        return [];
      }

      const lineText = document.lineAt(position.line).text;
      const prefixLine = lineText.slice(0, position.character);

      const m = prefixLine.match(
        /([A-Za-z_][A-Za-z0-9_\\.]*?)\.([A-Za-z_][A-Za-z0-9_]*)?$/
      );
      if (!m) {
        return [];
      }

      const expr = m[1];
      const attrPrefix = m[2] || '';

      const filename = Uri.parse(document.uri).fsPath;

      const pythonPath = getPythonPath(filename);

      const sourceForExec = cleanSourceForCompletion(document.getText(), position.line);

      console.error('[coc-pydyn] expr =', expr, 'attrPrefix =', attrPrefix);

      const attrs = await getDynamicAttrs(
        pythonPath,
        filename,
        expr,
        attrPrefix,
        sourceForExec
      );

      console.error('[coc-pydyn] dynamic attrs:', attrs);

      const seen = new Set();
      const items = [];

      for (const name of attrs) {
        if (seen.has(name)) continue;
        seen.add(name);

        const isPrivate = name.startsWith('_');
        const sortKey = (isPrivate ? '1' : '0') + name.toLowerCase();

        items.push({
          label: name,
          kind: CompletionItemKind.Property,
          detail: '[DYN]',
          insertText: name,
          filterText: name,
          sortText: sortKey  
        });
      }

      console.error('[coc-pydyn] returning', items.length, 'items');
      return items;
    },
  };

  context.subscriptions.push(
    languages.registerCompletionItemProvider(
      'pydyn',
      'PYDYN',
      ['python'],
      provider,
      ['.'],
      0
    )
  );
}

exports.activate = activate;
