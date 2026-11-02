# Claude Code Game Studios: trial notes (branch `try/game-studios`)

This branch tries out https://github.com/Donchitos/Claude-Code-Game-Studios (v1.2.0, MIT) on Galaxity. Nothing here is on `main`. To drop the trial, delete the branch.

## What was added
- `.claude/`: 49 agents, 72 skills (slash commands such as `/adopt`, `/playtest-report`, `/team-level`, `/team-audio`), 17 hook scripts, rules and a status line. About 490 files.
- `project.yaml`: set to Godot 4.7, GDScript, rigor `minimal` (the lightest process level).
- `design/`, `docs/`, `production/`: the template's empty design, engine-reference and production folders.
- `CLAUDE.md`: our file stays as it was. The studio's instructions are appended at the bottom.
- `.gitignore` and `.gitattributes`: the studio's entries are appended. They keep its shell scripts LF on Windows.

## What happened
- **The hooks run fine, but they never look at our code.** The studio expects Godot code in `src/`, and that path is hardcoded with no setting to change it. Ours lives in `Godot Project/my-world/`, so the commit checks for hardcoded values and TODOs skip it. The only thing the commit hook reports is a reminder when we push to `main`.
- **`/project-stage-detect`** (4 turns, about $0.12) found 286 GDScript files and 81 tests and called the game "Production". It flagged four gaps: no `design/game-brief.md`, a code root that doesn't match the template, no CI test run, and the engine name's capitalisation (now fixed).
- **`/adopt full`** (10 turns, about $0.49) found no blocking problems. It flagged 1 HIGH gap (write a game brief) and 3 MEDIUM ones (missing naming, performance and rendering settings in `project.yaml`). It estimated about 35 minutes to fix all four.
- Both commands stopped to ask "May I write...?" before saving anything. That's the studio's rule for every file edit.

## Things that would change how we work
1. Its `CLAUDE.md` rules say to **ask before every file write and never commit without being told**. That pulls against how the threads work now, where they build, commit to `main`, then pull onto the PC.
2. The hooks need Git Bash and Python on the PC. Without Python, any commit that stages a JSON file is **blocked**.
3. The deny list blocks `git reset --hard`, `git clean -f` and `rm -rf` for every session in this repo.
4. One hook checks GitHub for template updates at session start.
5. Every session loads more context: agents, rules and the session-start summary.
