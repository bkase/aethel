# Combine new and grow into one command 'write'

**Status:** Refining
**Agent PID:** 45151

## Original Todo

Combine new and grow into one command 'write'

This lets you create it if it doesn't exist or update it if it already exists. If the file doesn't exist, then we need you to know all the required fields. But if the file does exist, then basically everything is optional. I guess you know it exists because if you pass a UUID, then it's updating something. If you don't pass a UUID, then it'll make a new one. But like all the flags should be the same, all the functionality should be the same, so let's combine these commands.

Make sure to update the docs/usage.md and docs/plugin.md and claude.md as part of this.

## Description

[what we're building]

## Implementation Plan

[how we are building it]

- [ ] Code change with location(s) if applicable (src/file.ts:45-93)
- [ ] Automated test: ...
- [ ] User test: ...

## Notes

[Implementation notes]