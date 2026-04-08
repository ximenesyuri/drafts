# About

This is an extension for [coc.nvim](https://github.com/neoclide/coc.nvim) that provides completion of dynamic attributes in Python files.

# Install

1. Ensure you have `coc.nvim` installed.
2. Clone the repository somewhere (typically inside the `coc` extensions directory `$HOME/.config/coc/extensions`)
3. Install the extension in `coc`:

```bash
cd $HOME/.config/coc
npm install /path/to/coc-pydyn
```

# venv

To work properly, the extension need to find the Python interpreter inside the `venv` of your project. You can statically define it in your `coc-settings.json`, as follows:

```json
{
    ...
    "pydyn": {
        "pythonPath": "/path/to/your/venv/bin/python"
    }
    ...
}
```

If not set, `coc-pydyn` will automatically try to find the `venv` by:
1. looking for some parent directory containing `pyproject.toml` or `requirements.txt`, which is considered as the `<project_root>`
2. then taking `pythonPath = <project_root>/.venv/bin/pythonPath`

# Completions

If you have no `coc` extension that provides completion for static attributes (as, for example, [coc-pyright](https://github.com/fannheyward/coc-pyright)), then `coc-pydyn` you provide completion for static and dynamic attributes.

However, if you already have static completion, `coc-pydyn` will provide completion only for dynamic attributes in the same list where the already existing static attributes are listed.

# Strategy

The strategy used is quite simple: In Python, dynamic attributes are computed at runtime and can be accessed with the `dir(entity)` builtin function. So, what the extension does is precisely introduced in the completion system, at runtime, the content of `dir(entity)`.
