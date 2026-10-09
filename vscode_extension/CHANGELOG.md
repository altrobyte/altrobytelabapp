# Changelog

## 0.1.7
- "Start session" now lets you choose: the ready-made courses first, then the experiments of your modules.

## 0.1.6
- The ready-made courses are now written lessons that run on their own: instant, the same for everyone, and they keep working even when the AI is busy. The AI only answers your own questions.
- Suggested answers appear as a picker; press Esc to type your own.
- A helper left running by an older app or extension is replaced automatically.

## 0.1.5
- "Experiments" now starts with the ready-made courses (welcome, set up your laptop, first program), then the experiments of your modules.

## 0.1.4
- Beginner-friendly lessons: the trainer asks quick questions (you pick an answer from a list) and checks your understanding as you go.
- Build tools come inside the extension (PlatformIO Core), so building and uploading work without installing anything else.

## 0.1.3
- First run is easier: if you have not opened a folder, a starter folder is made for you (the same one the desktop app uses), and a folder that no longer exists is replaced instead of causing an error.
- If PlatformIO is not on your computer, you are offered a one-click install (it is needed to build and upload to your board).

## 0.1.2
- A module can have several experiments, each made from one of its notes. Pick the one you want in "Experiments".
- Lighter: the helper trims its own logs and the panel does less work while idle.

## 0.1.1
- One helper per computer: the extension joins the helper another Altrobyte app already started, instead of starting its own, so settings and the board stay in sync. It ends itself when nobody is connected.
- Restart the helper really restarts it.

## 0.1.0
- First release: AI lab instructor in VS Code. Sign in with your Altrobyte account (WhatsApp OTP for learners).
- Looks at your real setup only with your permission; build and upload always ask first.
- Shows wiring pictures beside your editor and opens your file at the exact line to write code.
- Carries its own Python runtime: nothing else to install.
