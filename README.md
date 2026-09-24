# aim-helm-bashkit

Ruby bindings for [Bashkit](https://github.com/everruns/bashkit), a sandboxed bash interpreter
written in Rust. Scripts run in-process against a virtual filesystem: no external shell, no host
filesystem, no network. `grep`, `rg`, `sed`, `awk`, `jq`, pipes, and redirects are Bashkit's own
implementations.

The gem calls Bashkit's C ABI through `ffi` and mirrors the core of the Python binding's `Bash` API.
`AimHelmBashkit::Workspace` adds a sync layer for running scripts over documents kept in a database.

## Installation

```ruby
gem "aim-helm-bashkit"
```

Platform gems bundle `libbashkit` for `x86_64-linux-gnu`, `aarch64-linux-gnu`, `x86_64-darwin`, and
`arm64-darwin` (Linux needs glibc 2.34+). The source gem downloads the same checksum-verified
library from the Bashkit release on install. Set `AIM_HELM_BASHKIT_LIB_PATH` to use your own build. The
pinned version is `AimHelmBashkit::BASHKIT_VERSION`.

## Bash

```ruby
bash = AimHelmBashkit::Bash.new(cwd: "/work", env: { "CI" => "1" }, timeout_seconds: 30)

bash.execute("echo hello > greeting.txt")
result = bash.execute("cat greeting.txt | tr a-z A-Z")
result.stdout     # => "HELLO\n"
result.exit_code  # => 0
result.success?   # => true

bash.execute!("exit 3")  # raises AimHelmBashkit::BashError
bash.close
```

Shell state and files persist across `execute` calls on one instance. `reset` discards both.

A script that cannot finish still returns a result, with `exit_code` 1 and a message in `error`.
This covers parse errors, exceeded limits, timeouts, and cancellation. ABI failures such as bad
configuration raise `AimHelmBashkit::Error`.

Constructor options: `profile` (`:hardened`, `:standard`, `:interactive`), `cwd`, `env`, `files`
(text, `{ "/path" => "content" }`), `username`, `hostname`, `timeout_seconds`,
`parser_timeout_seconds`, `max_commands`, `max_input_bytes`, `max_output_bytes`,
`readonly_filesystem`, `capture_final_env`.

### Cancellation

`execute` releases the GVL, so other threads keep running. `cancel` is safe from any thread and
stops the script at its next command boundary. It is sticky until `clear_cancel`.

```ruby
Thread.new { sleep 1; bash.cancel }
bash.execute("sleep 10").error  # => "execution cancelled"
bash.clear_cancel
```

### Files

```ruby
bash.mkdir("/data", recursive: true)
bash.write_file("/data/config.json", '{"debug": true}')
bash.read_file("/data/config.json")
bash.remove("/data", recursive: true)
```

`write_file` requires the parent directory to exist. Bashkit processes text: shell commands that
emit invalid UTF-8 replace those bytes with U+FFFD.

## Workspace

`Workspace` runs a script over chosen documents from a store and saves what changed. The store is
any object with `read(path)` (returning `nil` when missing), `write(path, content)`, and
`delete(path)`.

```ruby
workspace = AimHelmBashkit::Workspace.new(store, root: "/workspace")

run = workspace.execute(
  "rg -ni 'amount|premium' inputs/schema.sql > outputs/money.txt",
  files: ["inputs/schema.sql", "outputs/money.txt"],
  timeout_seconds: 30,
)

run.result   # => AimHelmBashkit::ExecResult
run.written  # => ["outputs/money.txt"]
run.deleted  # => []
```

`files` names every document the script may read or write. Each call:

1. Creates a fresh interpreter and copies in the listed documents that exist, at `root/<path>`.
   Parent directories are created for every listed path.
2. Runs the script. Unlisted documents do not exist in the shell.
3. Saves listed files the script created or changed and deletes listed files it removed. Anything
   else the script wrote is discarded.

Store paths are relative (`inputs/schema.sql`); paths containing `.`, `..`, or empty segments are
rejected. Files written before a failure or timeout are still saved. Writes are last-writer-wins
against the store.

## Examples

- [Console walkthrough](docs/console.md): a directory-backed store, reading, writing, editing, and
  deleting files, plus known `awk` differences.
- [Stores](docs/stores.md): the aim-helm-rails Workspace adapter and a store over any Active Record
  model.
- [Read-only execution](docs/read-only.md): let a script read documents without writing anything.

## Development

```sh
bundle install
bundle exec rake native:fetch
bundle exec rspec
bundle exec rubocop
bin/console   # IRB with `bash`, `store`, and `workspace` ready
```

## Releasing

Tag `vX.Y.Z` and push. The release workflow packages platform gems plus the source gem and publishes
to RubyGems via trusted publishing.

## License

MIT
