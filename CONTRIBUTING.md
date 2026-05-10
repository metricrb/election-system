# Contributing to ElectionSystem

Thank you for your interest in contributing to ElectionSystem! This document provides guidelines and instructions for contributing code, documentation, and bug reports.

## Code of Conduct

- Be respectful and constructive in all interactions
- Focus on the code and ideas, not the people
- Help each other grow as developers
- Report violations to the maintainers

## Getting Started

### Prerequisites

- [Rojo](https://rojo.space/) — for syncing Lua code between Studio and filesystem
- [Wally](https://wally.run/) — for dependency management
- Roblox Studio
- Git
- Basic familiarity with Lua and Roblox APIs

### Setting Up Your Development Environment

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/election-system.git
   cd election-system
   ```

2. **Install dependencies**
   ```bash
   wally install
   ```

3. **Start Rojo for live syncing**
   ```bash
   rojo serve default.project.json
   ```

4. **Open in Roblox Studio**
   - Create a new place
   - In Studio, go to `Rojo` → `Connect` (the plugin should auto-detect the server)
   - Studio will sync code from your filesystem in real-time

5. **Run tests**
   ```bash
   # Tests use TestEZ and are located in /tests
   # Open the test suite in Studio to run them
   ```

## What to Contribute

### High-Priority Areas

- **Bug fixes** — Any voting method calculation errors, DataStore issues, or core system bugs
- **Test coverage** — New test cases for edge cases and complex voting methods
- **Documentation** — Clearer explanations, examples, and guides for common tasks
- **Performance improvements** — Optimization for large elections or many players

### Voting Methods

If you're adding a new voting method:

1. Create `src/Modules/VotingMethods/YourMethod.lua`
2. Implement the required interface (see `VotingMethods/FPTP.lua` for reference)
3. Add tests in `tests/VotingMethods_spec.lua`
4. Update `Settings.lua` to include your method in the list
5. Document how it works in the README

### Core System Changes

Changes to `src/Modules/` (ElectionManager, Store, Data, Network, ResultCalculator, etc.):

1. Add tests before or alongside your changes
2. Update type definitions in `Types.lua` if needed
3. Update the API documentation (inline comments)
4. Test with multiple scenarios (fresh election, reopen, alt detection enabled, etc.)

### Documentation

- Guides live in `/docs`
- Keep examples up-to-date and tested
- Include code snippets when explaining functionality
- Use clear, beginner-friendly language

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

Use `feature/` for new features and `fix/` for bug fixes.

### 2. Make Your Changes

- Keep commits focused and atomic
- Write descriptive commit messages
- Follow the code style (see Code Style section below)
- Add tests for new functionality

### 3. Run Tests

Before pushing, ensure all tests pass:

```bash
# In Studio, open the test place and run the test suite
```

Also test manually:
- Start a fresh election
- Test the affected voting method (if applicable)
- Check DataStore persistence
- Test with alt detection enabled

### 4. Push and Create a Pull Request

```bash
git push origin feature/your-feature-name
```

Then open a PR on GitHub. Use the PR template provided (automatic when you create the PR).

## Code Style

### Lua Conventions

- **Variables:** `camelCase` for local variables and functions, `SCREAMING_SNAKE_CASE` for constants
- **Functions:** Clear, descriptive names; include type hints in comments
- **Comments:** Explain *why*, not *what*; code is self-documenting
- **Spacing:** 2-space indentation (no tabs)
- **Line length:** Keep lines under 100 characters where reasonable

### Example

```lua
local function calculateWinner(votes, candidates, method)
    -- Validate inputs before processing
    if not votes or #votes == 0 then
        return nil
    end
    
    -- Use the appropriate voting method
    local calculator = VOTING_METHODS[method]
    return calculator:calculate(votes, candidates)
end
```

### Module Structure

```lua
local MyModule = {}
local private = {}

-- Public interface
function MyModule:publicMethod(arg1, arg2)
    return private.helper(arg1, arg2)
end

-- Private helpers
function private.helper(arg1, arg2)
    -- Implementation
    return result
end

return MyModule
```

### Type Hints

Use comment-based type hints for clarity:

```lua
-- @type Ballot: { {candidateId: string, rank: number} }
-- @type Result: { winner: Candidate, votes: {Candidate: number} }
-- @return Result
local function calculateResult(votes, candidates)
    -- ...
end
```

## Testing

### Writing Tests

- Use [TestEZ](https://github.com/Kampfkarren/testez) (already included)
- Test both happy paths and edge cases
- Aim for clear, descriptive test names

### Example Test

```lua
describe("FPTP voting method", function()
    it("should declare the candidate with the most votes as winner", function()
        local votes = {
            { { candidateId = "alice", rank = 1 } },
            { { candidateId = "alice", rank = 1 } },
            { { candidateId = "bob", rank = 1 } },
        }
        
        local result = FPTP:calculate(votes, candidates)
        expect(result.winner.candidateId).to.equal("alice")
    end)
    
    it("should handle ties by returning nil", function()
        local votes = {
            { { candidateId = "alice", rank = 1 } },
            { { candidateId = "bob", rank = 1 } },
        }
        
        local result = FPTP:calculate(votes, candidates)
        expect(result.winner).to.equal(nil)
    end)
end)
```

### Running Tests in Studio

1. Build the place: `rojo build default.project.json --output ElectionSystem.rbxl`
2. Open in Studio
3. In Studio's command bar, run the test suite or manually verify behavior

## Pull Request Guidelines

### Before Submitting

- [ ] Tests pass locally
- [ ] Manual testing complete (voting, DataStore, results)
- [ ] Code follows style guidelines
- [ ] Commit messages are clear and descriptive
- [ ] PR description explains *why* the change is needed
- [ ] Documentation updated (if applicable)

### PR Title Format

```
[type]: Brief description

Examples:
- feature: Add Condorcet voting method
- fix: Correct vote counting in IRV with ties
- docs: Clarify Settings.lua configuration
- test: Add edge case tests for alt detection
```

Types: `feature`, `fix`, `docs`, `test`, `refactor`, `perf`

### PR Description Template

Include:
- What problem does this solve?
- What did you change?
- How did you test it?
- Any breaking changes?
- Links to related issues

## Reporting Bugs

### Before Opening an Issue

- Check existing issues to avoid duplicates
- Verify the bug still exists in the latest version
- Test with a minimal reproducible example

### Bug Report Template

When opening a bug issue, include:
- **What you expected:** Clear description of the expected behavior
- **What actually happened:** Actual behavior with details
- **Steps to reproduce:** Numbered steps to reliably reproduce
- **Screenshots/videos:** If applicable (especially for UI issues)
- **Environment:** Rojo version, Roblox Studio version, OS
- **Voting method:** Which voting method was active (if applicable)
- **Sample Settings:** Minimal Settings.lua configuration that triggers the bug

### Example

```
Title: FPTP voting fails with single candidate

Expected: Single candidate should win with 100% vote share
Actually: Error "Invalid vote format" when only one candidate exists

Steps to reproduce:
1. Create Settings.lua with 1 candidate
2. Submit a vote for that candidate
3. Check results

Voting method: FPTP
Settings: See attached minimal_settings.lua
```

## Requesting Features

### Before Opening an Issue

- Check if the feature already exists
- Check if there's an open discussion about it
- Consider if it fits the project's scope (universal, modular election system)

### Feature Request Template

When opening a feature request:
- **What problem does it solve?** Clear use case
- **Proposed solution:** How you'd like it to work
- **Alternative approaches:** Other ways to solve the problem
- **Examples:** Real-world scenarios where this would be useful

## Review Process

### What Maintainers Look For

1. **Code quality:** Clear, tested, follows conventions
2. **Alignment:** Fits project goals (universal, modular, well-documented)
3. **Testing:** Edge cases covered; behavior verified
4. **Documentation:** Changes documented; existing docs updated
5. **Performance:** No unnecessary overhead; large elections still work

### Feedback

- Maintainers may request changes before merging
- Respond to feedback promptly and ask for clarification if needed
- Feel free to ask questions in the PR comments

## Release Process

Releases are tagged manually by maintainers using semantic versioning:

```bash
git tag v1.2.3
git push origin v1.2.3
```

This triggers CI/CD to build and release the `.rbxl` file. Contributors don't need to handle this.

## Getting Help

- **Questions about contributing?** Open a discussion on GitHub
- **Stuck on setup?** Check the README and GETTING_STARTED guide
- **Need Rojo/Wally help?** Consult their official docs
- **Unclear requirements?** Ask in the PR or issue discussion

## Recognition

Contributors will be recognized in:
- PR merges (visible in GitHub history)
- Release notes (for significant contributions)
- CONTRIBUTORS.md file (coming soon)

Thank you for contributing to ElectionSystem! 🎉
