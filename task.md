# Add --body argument to new command

**Status:** InProgress
**Agent PID:** 6967

## Original Todo

Specify a way to write the body of an Aethel file at the same time as `new` so that you don't have to do `new` and then `grow`.

I think just make it another --argument called --body.

## Description

Add a `--body` argument to the `aethel new` command that allows users to specify the content of an artifact when creating it. This eliminates the need to run separate `new` and `grow` commands when you want to create an artifact with initial content.

## Implementation Plan

- [x] Add `body: Option<String>` field to the `New` command in `src/cli.rs:31`
- [ ] Update pattern match in `src/main.rs:26-32` to pass body parameter to execute function
- [ ] Modify `execute()` function signature in `src/commands/new.rs:12-16` to accept `body: Option<&str>`
- [ ] Update artifact creation in `src/commands/new.rs:58-61` to use provided body or empty string
- [ ] Test: Create artifact with --body and verify content is saved
- [ ] Test: Create artifact without --body and verify it still works with empty content
- [ ] Run cargo fmt and cargo clippy to ensure code quality

## Notes

The implementation leverages the existing artifact creation flow, simply providing initial content instead of an empty string when the --body argument is supplied.