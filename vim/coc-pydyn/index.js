const {
  workspace,
  languages,
  CompletionItemKind,
  Uri,
} = require('coc.nvim');
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

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

const PY_HELPER = `
import sys, os, json, types, traceback

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

        try:
            code = compile(src, filename, "exec")
            exec(code, g, g)
        except Exception:
            traceback.print_exc()
            sys.exit(1)

        try:
            obj = eval(expr, g, g)
        except Exception:
            traceback.print_exc()
            sys.exit(1)

        try:
            names = []
            for a in dir(obj):
                if not a.startswith(attr_prefix):
                    continue
                names.append(a)
        except Exception:
            names = []

        print(json.dumps(names))
    finally:
        for p in remove_paths:
            try:
                sys.path.remove(p)
            except ValueError:
                pass

if __name__ == "__main__":
    main()
`;

function getDynamicAttrs(pythonPath, filename, expr, attrPrefix, source) {
  console.error('[coc-pydyn] spawning python:', pythonPath);
  const result = spawnSync(
    pythonPath,
    ['-c', PY_HELPER, filename, expr, attrPrefix],
    {
      encoding: 'utf8',
      input: source,
    }
  );

  if (result.error) {
    console.error('[coc-pydyn] spawn error:', result.error);
    return [];
  }

  if (result.status !== 0) {
    if (result.stderr) {
      console.error('[coc-pydyn] python stderr:\n' + result.stderr);
    } else {
      console.error('[coc-pydyn] python exited with code', result.status);
    }
    return [];
  }

  const stdout = (result.stdout || '').trim();
  if (!stdout) {
    console.error('[coc-pydyn] empty stdout from python');
    return [];
  }

  try {
    const arr = JSON.parse(stdout);
    if (Array.isArray(arr)) {
      console.error('[coc-pydyn] dynamic attrs:', arr);
      return arr;
    }
    console.error('[coc-pydyn] stdout not array JSON:', stdout);
  } catch (e) {
    console.error('[coc-pydyn] JSON parse error:', e, 'output:', stdout);
  }
  return [];
}

async function activate(context) {
  console.error('[coc-pydyn] activated');

  const provider = {
    triggerCharacters: ['.'],

    provideCompletionItems: async (document, position) => {
      console.error('[coc-pydyn] completion requested');

      if (document.languageId !== 'python') {
        console.error('[coc-pydyn] not python, languageId=', document.languageId);
        return [];
      }

      const lineText = document.lineAt(position.line).text;
      const prefixLine = lineText.slice(0, position.character);
      console.error('[coc-pydyn] line:', prefixLine);

      const m = prefixLine.match(
        /([A-Za-z_][A-Za-z0-9_\\.]*?)\.([A-Za-z_][A-Za-z0-9_]*)?$/
      );
      if (!m) {
        console.error('[coc-pydyn] no expr match');
        return [];
      }

      const expr = m[1];
      const attrPrefix = m[2] || '';
      console.error('[coc-pydyn] expr =', expr, 'attrPrefix =', attrPrefix);

      const filename = Uri.parse(document.uri).fsPath;
      console.error('[coc-pydyn] filename =', filename);

      const pythonPath = getPythonPath(filename);
      console.error('[coc-pydyn] using python:', pythonPath);

      let lines = document.getText().split(/\r?\n/);
      if (position.line < lines.length) {
        const origLine = lines[position.line];
        const indentMatch = origLine.match(/^\s*/);
        const indent = indentMatch ? indentMatch[0] : '';
        lines[position.line] = indent + 'pass';
      }
      const sourceForExec = lines.join('\n');

      const attrs = getDynamicAttrs(
        pythonPath,
        filename,
        expr,
        attrPrefix,
        sourceForExec
      );

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
