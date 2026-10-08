# Altrobyte AI Trainer (VS Code extension)

A hands-on lab instructor inside VS Code. It looks at your real setup (PlatformIO, your board on USB, your
serial output, your files), teaches without doing the work for you, and marks a milestone done only when a
real check passes.

The extension is the UI. Everything that needs your computer runs in the **Altrobyte Helper**
(`altrocoach-backend/helper`), a small local service that only listens on `127.0.0.1`.

## Try it (development)

1. `pip install -r ../../altrocoach-backend/helper/requirements.txt` (Python 3.10+).
2. `npm install` then `npm run build` in this folder.
3. In VS Code: open this folder and press **F5** (or run `code --extensionDevelopmentPath .`).
4. Click the robot icon in the activity bar, **Sign in**, **Start session**.

If the helper is not next to this repo, set `altrobyte.helperDir` to the folder containing `altrobyte_helper`.

## Install a build

`npm run package` makes `altrobyte-trainer-0.1.0.vsix`; install it with
`code --install-extension altrobyte-trainer-0.1.0.vsix`.

## What you control

- **Connectors** (Installed tools and USB, Project files, Build and upload, Serial monitor, MQTT) are switches in the
  panel. Off means the trainer never uses it. **Build and upload always ask first.**
- **What was sent**: "Show what the trainer did and what was sent" lists every request made of your computer and a
  preview of everything sent to the cloud. Passwords and keys are hidden before anything is sent.
- No internet? **Check my progress** runs the same checks on your computer with no AI and no connection.

## Tests

- `npm test`: unit tests plus the real helper started from Node (settings, offline checks, events, speech).
- `npm run test:vscode`: starts the installed VS Code with this extension (clean profile, no other extensions,
  a window opens for a few seconds) and checks it from inside the editor.

Not covered by automated tests: the sign-in prompts and the build/upload approval dialogs (they need a person).
