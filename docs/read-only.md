# Read-only execution

To let a script read documents without writing anything, seed the files at construction and set
`readonly_filesystem`. Every write then fails, including `Bash#write_file`, which is why the files
go in through `files:`.

```ruby
bash = AimHelmBashkit::Bash.new(
  cwd: "/workspace",
  readonly_filesystem: true,
  files: { "/workspace/inputs/schema.sql" => store.read("inputs/schema.sql") },
)

bash.execute("rg -n premium inputs/schema.sql | tr a-z A-Z").stdout
# => "2:PREMIUM_AMOUNT INTEGER\n"

bash.execute("echo x > /tmp/t").stderr
# => "bash: /tmp/t: filesystem is read-only\n"

bash.close
```

Pipes work; redirects to any file, including `/tmp`, fail. `files:` takes text content.
