# Combine new and grow into one command 'write'

**Status:** InProgress
**Agent PID:** 45151

## Original Todo

Combine new and grow into one command 'write'

This lets you create it if it doesn't exist or update it if it already exists. If the file doesn't exist, then we need you to know all the required fields. But if the file does exist, then basically everything is optional. I guess you know it exists because if you pass a UUID, then it's updating something. If you don't pass a UUID, then it'll make a new one. But like all the flags should be the same, all the functionality should be the same, so let's combine these commands.

Make sure to update the docs/usage.md and docs/plugin.md and claude.md as part of this.

## Description

We're building a unified 'write' command that combines the functionality of both 'new' and 'grow' commands. This single command will intelligently determine whether to create a new artifact or append to an existing one based on the presence of a UUID parameter. When no UUID is provided, it creates a new artifact (requiring type parameter). When UUID is provided, it appends content to the existing artifact. This simplifies the API by having one command for all write operations while maintaining backward compatibility with existing scripts.

## Implementation Plan

Based on the codebase analysis, here's how we'll implement the unified 'write' command:

- [x] Add Write command variant to CLI enum in src/cli.rs with optional UUID, type, title, body/content, and fields parameters
- [x] Create src/commands/write.rs implementing the unified logic that checks UUID presence to determine create vs append mode
- [x] Update src/commands/mod.rs to export the new write module
- [x] In write.rs, reuse logic from new.rs for artifact creation when UUID is None
- [x] In write.rs, reuse logic from grow.rs for content appending when UUID is provided
- [x] Add validation to ensure type is provided when creating new artifacts (UUID is None)
- [x] Update CLI match statement in src/cli.rs to handle Write command execution
- [x] Remove New and Grow command variants from CLI enum and their execute matches
- [x] Delete src/commands/new.rs and src/commands/grow.rs files
- [x] Update docs/usage.md to document the new write command and remove new/grow documentation
- [x] Update docs/plugin.md if it references the old commands
- [x] Update CLAUDE.md to reflect the new write command examples
- [ ] Add tests for write command covering both create and append scenarios
- [ ] Ensure backward compatibility by maintaining same output format (UUID for create, silent for append)

## Notes

[Implementation notes]