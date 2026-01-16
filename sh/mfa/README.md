# About

`mfa` is a simple bash CLI to manage multi factory authentication based in OTP protocol.


# Requirements

- `bash`
- `oathtool` or equivalent
- `xclip` (optional)

# Installation

Just source the `mfa` script. If you want, source it directly in you `.bashrc`.

# Usage

```
Usage: mfa [--file FILE] <command> [options]

Commands:
    new: creates a new entry
        new <name> <otpauth_url>
        new --name <name> --url <otpauth_url>
        new --name <name> --service <service> --user <user> --secret <secret>
        new --name <name> --service <service> --secret <secret>

    rm: removes existing entry
        rm <name>
        rm --name <name>

    list: list registered entries

    <name>: provide code for registered entry

Globals:
    --file <file>: Path to the secrets file.
    --help:        Show this help message and exit.

Environment:
    MFA_SECRETS_FILE: set secrets file globally.
```

# Secrets file

After registering an entry, a secret is stored in a plain file. There are two ways to set the secrets file:
1. globally, by setting its path in the env `MFA_SECRETS_FILE`
2. locally, by passing its path to the flag `--file` while calling `mfa`.

> If both `MFA_SECRETS_FILE` and `--file` are set, the flag value overwrites the env value.

# Examples

```bash
# with secrets file set globally env
export MFA_SECRETS_FILE="$HOME/.config/mfa.txt"

mfa list
mfa new github "otpauth://totp/GitHub:user@example.com?secret=ABCDEF123..."
mfa rm github

# with secrets file set locally
mfa list --file ~/.config/mfa.txt
```

# Managing entries

To catalog of a new entry is made through a `oth` url, which has the foollowing format:

```
otpauth://totp/<service>:user@<user>?secret=<secret>"
```

While using `mfa new`, you can pass the entire url or its parts. More precisely, the following works equivalently to create a new entry named `<name>`:

```bash
mfa new <name> <url>
mfa new --name <name> --url <url>
mfa new --name <name> --service <service> --user <user> --secret <secret>
```

To delete an entry named `<name>`, you can use both syntax:

```bash
mfa rm <name>
mfa rm --name <name>
```

To list the registered entries, use just `mfa list`.

# Getting codes

To get the code of a registered entry, you use `mfa <name>`. If you want a list with all codes for all registered entries, call `mfa` without any argument.

# Bash completion

The main file `mfa` also contains a completion script for the `mfa` function, which suggests commands, global flags and registered entries.
