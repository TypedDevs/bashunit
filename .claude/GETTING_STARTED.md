# Getting Started with Claude Code for bashunit

Welcome! This 5-minute guide will get you started with the custom Claude Code configuration for bashunit.

## What You Get

✨ **Custom Skills** - One-command workflows:
- `/tdd-cycle` - Complete TDD workflow
- `/fix-test` - Debug failing tests
- `/add-assertion` - Add new assertions with tests
- `/check-coverage` - Analyze test coverage
- `/pre-release` - Pre-release validation

🎯 **Custom Commands** - End-to-end workflows:
- `/gh-issue 42` - Complete GitHub issue → PR workflow

📚 **Code Standards** - Automatic enforcement:
- Bash 3.2+ compatibility
- TDD methodology (RED → GREEN → REFACTOR)
- Testing patterns
- Quality checks

## Quick Start

### 1. Try Your First Skill

In Claude Code, try:
```
/tdd-cycle
```

Claude will guide you through:
- RED: Write failing test
- GREEN: Minimal implementation
- REFACTOR: Improve code
- Quality checks

### 2. Work on a GitHub Issue

```
/gh-issue 42
```

Claude will:
1. Fetch the issue
2. Create a branch
3. Plan implementation
4. Implement with TDD
5. Create a PR

### 3. Understand the Standards

Claude automatically follows these rules (from `.claude/CLAUDE.md`):

**TDD Workflow:**
- Write tests before code
- Fail for the right reason
- Minimal implementation
- Refactor while green

**Bash 3.2+ Compatible:**
- No `declare -A` (associative arrays)
- No `[[ ]]` (use `[ ]`)
- No `${var,,}` (case conversion)
- Works on macOS default bash

**Quality Standards:**
```bash
make sa          # ShellCheck
make lint        # EditorConfig
./bashunit tests/  # All tests pass
```

## Common Workflows

### Starting New Work

**Option 1: From GitHub Issue**
```
/gh-issue 123
```

**Option 2: Direct TDD**
```
/tdd-cycle
```

### Fixing Failing Tests
```
/fix-test
```

### Before Release
```
/pre-release
```

## Key Files

- **`.claude/CLAUDE.md`** - Primary instructions (comprehensive)
- **`.claude/QUICK_REFERENCE.md`** - One-page cheat sheet
- **`.claude/README.md`** - Full documentation
- **`.claude/rules/`** - Detailed guidelines
- **`.claude/skills/`** - Skill definitions
- **`.claude/commands/`** - Command definitions

## Understanding Skills vs Commands

**Skills** = Focused workflows
- `/tdd-cycle` - Run one TDD cycle
- `/fix-test` - Fix specific test failures

**Commands** = End-to-end processes
- `/gh-issue` - Complete issue → PR workflow

## Tips

### 1. Reference Files with @

Claude understands references:
```
Read @.claude/rules/bash-style.md
Follow @.claude/rules/testing.md
```

### 2. Use Tab Completion

Type `/` and tab to see available skills and commands.

### 3. Read the Quick Reference

Keep it handy:
```bash
cat .claude/QUICK_REFERENCE.md
```

### 4. Check Examples

Study existing patterns:
- `tests/unit/assert_test.sh` - Assertion patterns
- `tests/functional/doubles_test.sh` - Mocks/spies
- `tests/acceptance/bashunit_test.sh` - CLI tests

## What Claude Automatically Enforces

✅ **TDD workflow** - Tests before code
✅ **Bash 3.2+ compatibility** - No modern bash features
✅ **Quality checks** - make sa && make lint
✅ **Test patterns** - Use existing patterns only
✅ **Commit format** - Conventional commits (no AI mentions!)

## Common Questions

**Q: Do I need task files?**
A: No, they're optional. Use for complex work to track progress.

**Q: Can I customize the skills?**
A: Yes! Edit files in `.claude/skills/` and they'll update.

**Q: How do I add my own skill?**
A: Create `.claude/skills/my-skill/SKILL.md` following existing patterns.

**Q: Where are the instructions for CI/CD?**
A: See `.claude/agents/README.md` for Agent SDK examples.

## Next Steps

1. **Try a skill** - `/tdd-cycle` or `/gh-issue`
2. **Read comprehensive docs** - `.claude/CLAUDE.md`
3. **Check quick reference** - `.claude/QUICK_REFERENCE.md`
4. **Explore examples** - Look at `.claude/skills/` and `.claude/rules/`

## Help

- **Documentation**: `.claude/README.md`
- **Quick ref**: `.claude/QUICK_REFERENCE.md`
- **Primary config**: `.claude/CLAUDE.md`
- **bashunit docs**: https://bashunit.typeddevs.com

---

**Ready?** Try `/tdd-cycle` and let Claude guide you through the TDD workflow!
