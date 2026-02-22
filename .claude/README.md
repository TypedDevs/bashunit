# Claude Code Configuration for bashunit

This directory contains custom Claude Code configuration to enhance AI-assisted development for the bashunit project.

## 📁 Directory Structure

```
.claude/
├── CLAUDE.md              # Main project instructions (read this first!)
├── rules/                 # Modular rules by topic
│   ├── bash-style.md      # Bash 3.0+ compatibility & style
│   ├── testing.md         # Testing patterns & guidelines
│   └── tdd-workflow.md    # TDD Red-Green-Refactor cycle
├── skills/                # Custom reusable workflows
│   ├── tdd-cycle/         # Complete TDD cycle automation
│   ├── fix-test/          # Debug and fix failing tests
│   ├── add-assertion/     # Add new assertions with tests
│   ├── check-coverage/    # Analyze test coverage
│   └── pre-release/       # Pre-release validation
├── commands/              # Structured end-to-end workflows
│   ├── gh-issue.md        # Complete GitHub issue workflow
│   └── README.md          # Commands documentation
├── agents/                # Programmatic automation (Agent SDK)
│   ├── README.md          # Agent SDK documentation
│   └── examples/          # Example automation scripts
│       ├── tdd-bot.py     # Automated TDD workflow
│       └── pr-validator.py # PR quality validation
└── README.md              # This file

```

## 🚀 Quick Start

### For Claude Code Users

When working on bashunit, Claude Code will automatically:
1. Read `CLAUDE.md` for project context
2. Follow rules in `rules/` for code standards
3. Offer custom skills via `/skill-name`

### Using Custom Skills & Commands

Invoke skills and commands with slash commands:

**Commands** (end-to-end workflows):
```bash
/gh-issue 42      # Complete GitHub issue workflow (fetch → plan → implement → PR)
```

**Skills** (focused tasks):
```bash
/tdd-cycle        # Run complete TDD cycle
/fix-test         # Debug failing tests
/add-assertion    # Add new assertion function
/check-coverage   # Analyze test coverage
/pre-release      # Pre-release validation
```

### For Automation

Use Agent SDK agents for CI/CD:

```bash
# Install Agent SDK
pip install claude-agent-sdk

# Set API key
export ANTHROPIC_API_KEY="your-key"

# Run automated TDD bot
python .claude/agents/examples/tdd-bot.py

# Validate PR
python .claude/agents/examples/pr-validator.py <pr-number>
```

## 📖 Core Documents

### 1. CLAUDE.md - Project Instructions

**Primary source of truth** for Claude Code. Contains:
- Project overview & architecture
- Development workflow
- Common commands
- Key files & patterns
- Definition of Done

**Read this first!** All other files support it.

### 2. Rules (Modular Guidelines)

#### `rules/bash-style.md`
- **Bash 3.0+ compatibility** (critical for macOS)
- Coding standards
- ShellCheck compliance
- Documentation patterns
- Security best practices

#### `rules/testing.md`
- Test organization (unit/functional/acceptance)
- Assertion patterns
- Test doubles (mocks/spies)
- Data providers
- Lifecycle hooks
- Anti-patterns to avoid

#### `rules/tdd-workflow.md`
- **Red → Green → Refactor** cycle
- Task file requirements
- Quality gates
- Definition of Done
- Common TDD mistakes

### 3. Commands (End-to-End Workflows)

#### `/gh-issue` - GitHub Issue Workflow
Complete workflow from issue to PR:
- Fetch issue from GitHub
- Create branch and task file
- Plan implementation
- Implement following TDD
- Create commit and PR

**Example:**
```bash
User: /gh-issue 42
Claude: [Fetches issue, creates branch, plans, implements, opens PR]
```

See `.claude/commands/README.md` for details.

### 4. Skills (Reusable Workflows)

#### `/tdd-cycle` - TDD Automation
Complete TDD workflow:
- Verify task file
- Write failing test (RED)
- Implement minimal fix (GREEN)
- Refactor & improve
- Update task file

#### `/fix-test` - Test Debugging
Systematically debug and fix:
- Identify failures
- Categorize (test bug, implementation bug, flaky)
- Apply appropriate fix
- Verify stability

#### `/add-assertion` - New Assertions
Add assertions following TDD:
- Plan new assertion
- Study existing patterns
- Implement with full test coverage
- Document and integrate

#### `/check-coverage` - Coverage Analysis
Analyze test coverage:
- Generate coverage report
- Identify untested code
- Prioritize gaps
- Suggest tests to add

#### `/pre-release` - Release Validation
Comprehensive pre-release check:
- Run all tests
- Static analysis
- Documentation review
- Compatibility checks
- Git status verification

## 🎯 How It Works

### Claude Code Workflow

```
User: "Add new assertion for JSON validation"
    ↓
Claude reads: CLAUDE.md → rules/ → AGENTS.md
    ↓
Claude offers: /add-assertion skill
    ↓
User: /add-assertiond
    ↓
Skill executes: TDD cycle with comprehensive tests
    ↓
Result: New assertion with tests, docs, all quality checks passing
```

### File Priority

Claude Code reads in this order:
1. `.claude/CLAUDE.md` - Project instructions
2. `.claude/rules/*.md` - Topic-specific rules
3. `AGENTS.md` - Detailed workflow instructions
4. `.github/CONTRIBUTING.md` - Contributing guidelines

**More specific = Higher priority**

### Context Loading

Claude automatically loads:
- ✅ `CLAUDE.md` - Always read
- ✅ `rules/` - Loaded based on file paths
- ✅ Skills - Offered when relevant
- ✅ Referenced files via `@file.md` syntax

## 🔧 Customization

### Adding New Rules

Create modular rule files:

```markdown
---
paths:
    - "src/**/*.sh"
---

# Your Rule Name

Rule content here...
```

Reference from CLAUDE.md:
```markdown
## Code Standards

@.claude/rules/your-rule.md
```

### Creating New Skills

1. Create directory: `.claude/skills/skill-name/`
2. Add `SKILL.md`:

```markdown
---
name: skill-name
description: Brief description
allowed-tools: Read, Edit, Bash
---

# Skill Instructions

Workflow steps...
```

3. Use with: `/skill-name`

### Custom Subagents

For specific domains, create custom agents:

```markdown
# .claude/agents/bash-3.0-expert/agent.md

You are a Bash 3.0 compatibility expert for bashunit.

Your expertise:
- Identify Bash 4+ features
- Suggest Bash 3.0 alternatives
- Explain compatibility trade-offs

When consulted:
1. Analyze code for compatibility
2. Suggest portable alternatives
3. Explain why changes needed
```

## 📚 Integration with Existing Docs

bashunit already has excellent documentation:

- `AGENTS.md` - Primary TDD workflow (source of truth)
- `.github/CONTRIBUTING.md` - Contributing guide
- `.github/copilot-instructions.md` - GitHub Copilot instructions

**Two-way sync rule:** When updating Claude Code configuration, evaluate if changes should also update existing docs (and vice versa).

## 🤖 Automation Examples

### GitHub Actions - TDD Bot

```yaml
name: Automated TDD

on:
  push:
    branches: [ feature/* ]

jobs:
    tdd-bot:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v3
            - uses: actions/setup-python@v4
            - run: pip install claude-agent-sdk
            - run: python .claude/agents/examples/tdd-bot.py
              env:
                  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

### GitHub Actions - PR Validation

```yaml
name: PR Validator

on:
  pull_request:
    types: [ opened, synchronize ]

jobs:
    validate:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v3
            - uses: actions/setup-python@v4
            - run: pip install claude-agent-sdk
            - run: python .claude/agents/examples/pr-validator.py ${{ github.event.pull_request.number }}
              env:
                  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
                  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 🎓 Best Practices

### 1. Keep CLAUDE.md Concise

- High-level overview
- Link to detailed rules
- Common commands
- Critical guardrails

### 2. Use Modular Rules

- One topic per file
- Path-scoped when possible
- Reference from main CLAUDE.md

### 3. Skills Should Be Focused

- One clear purpose
- Reusable workflow
- Clear success criteria

### 4. Sync with Existing Docs

- Update AGENTS.md when changing workflow
- Keep copilot-instructions.md aligned
- Document sync decisions in task files

### 5. Test Your Configuration

```bash
# Test skills work
/tdd-cycle

# Test rules are followed
# (Claude should enforce Bash 3.0+ compatibility)

# Test agents run
python .claude/agents/examples/tdd-bot.py --help
```

## 🐛 Troubleshooting

### Skills Not Showing

- Verify `SKILL.md` format
- Check skill name matches directory
- Restart Claude Code

### Rules Not Applied

- Check file is in `.claude/rules/`
- Verify referenced in `CLAUDE.md`
- Check path patterns match

### Agents Fail

```bash
# Check API key
echo $ANTHROPIC_API_KEY

# Install SDK
pip install claude-agent-sdk

# Test imports
python -c "from claude_agent_sdk import query"
```

## 📈 Metrics

Track configuration effectiveness:

- **Test coverage** - Use `/check-coverage`
- **Code quality** - ShellCheck/lint pass rate
- **TDD adherence** - Task file usage rate
- **PR quality** - Validation pass rate

## 🔗 Resources

### Claude Code
- [Documentation](https://code.claude.com/docs)
- [Skills Guide](https://code.claude.com/docs/en/skills.md)
- [Memory/Context](https://code.claude.com/docs/en/memory.md)

### Agent SDK
- [SDK Documentation](https://platform.claude.com/docs/agent-sdk)
- [API Reference](https://docs.anthropic.com)
- [Examples](https://github.com/anthropics/claude-agent-sdk)

### bashunit
- [Official Docs](https://bashunit.typeddevs.com)
- [GitHub](https://github.com/TypedDevs/bashunit)
- [Contributing](https://github.com/TypedDevs/bashunit/blob/main/.github/CONTRIBUTING.md)

## 🤝 Contributing

When enhancing this configuration:

1. **Test thoroughly** - Verify skills/rules work
2. **Update docs** - Keep this README current
3. **Sync with AGENTS.md** - Maintain two-way sync
4. **Get feedback** - Ask team if useful
5. **Commit properly** - Conventional commits

Example commit:
```
docs: add custom skill for coverage analysis

- Created /check-coverage skill
- Added documentation and examples
- Tested with sample project
```

## 📝 License

This configuration is part of the bashunit project and follows the same MIT license.

---

**Questions?** Open an issue or discussion on the [bashunit repo](https://github.com/TypedDevs/bashunit).
