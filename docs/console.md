# Console walkthrough

`bin/console` opens IRB with the gem loaded. This session uses a local directory as the store, so
you can watch files change on disk. Paste the blocks in order.

## A directory-backed store

```ruby
class DirStore
  def initialize(dir) = @dir = File.expand_path(dir)
  def read(path) = File.exist?(full(path)) ? File.read(full(path)) : nil
  def delete(path) = FileUtils.rm_f(full(path))
  def full(path) = File.join(@dir, path)

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(full(path)))
    File.write(full(path), content)
  end
end

disk = DirStore.new("tmp")
ws = AimHelmBashkit::Workspace.new(disk)

FileUtils.mkdir_p("tmp/inputs")
File.write("tmp/inputs/schema.sql", <<~SQL)
  CREATE TABLE policies (
    id INTEGER,
    premium_amount INTEGER,
    commission_rate REAL,
    holder_name TEXT
  );
SQL
File.write("tmp/notes.md", "# Notes\n")
```

## Read an input, write an output

```ruby
run = ws.execute("rg -ni 'amount|premium|commission' inputs/schema.sql > outputs/money.txt",
                 files: ["inputs/schema.sql", "outputs/money.txt"])
run.written                        # => ["outputs/money.txt"]
File.read("tmp/outputs/money.txt") # => "3:  premium_amount INTEGER,\n4:  commission_rate REAL,\n"
```

## Edit a listed file

```ruby
run = ws.execute("echo '- found money columns' >> notes.md; cat notes.md", files: ["notes.md"])
run.result.stdout  # => "# Notes\n- found money columns\n"
run.written        # => ["notes.md"]
```

## Unlisted files do not exist in the shell

```ruby
ws.execute("cat notes.md").result.stderr  # => "cat: notes.md: io error: file not found\n"
```

## Pipelines

```ruby
run = ws.execute(<<~SH, files: ["inputs/schema.sql", "outputs/ints.txt"])
  grep -o '[a-z_]* INTEGER' inputs/schema.sql | cut -d' ' -f1 | sort > outputs/ints.txt
  wc -l < outputs/ints.txt
SH
run.result.stdout                 # => "2\n"
File.read("tmp/outputs/ints.txt") # => "id\npremium_amount\n"

ws.execute(<<~'SH', files: ["inputs/schema.sql", "outputs/columns.csv"])
  awk '/INTEGER|REAL|TEXT/ { gsub(/,/, ""); print $1 "," $2 }' inputs/schema.sql \
    > outputs/columns.csv
SH
File.read("tmp/outputs/columns.csv") # => "id,INTEGER\npremium_amount,INTEGER\n..."
```

## Delete a listed file

```ruby
run = ws.execute("rm outputs/ints.txt", files: ["outputs/ints.txt"])
run.deleted                          # => ["outputs/ints.txt"]
File.exist?("tmp/outputs/ints.txt")  # => false
```

## Scratch files are discarded

Only listed files are saved.

```ruby
run = ws.execute("echo temp > scratch.txt; echo kept > outputs/kept.txt",
                 files: ["outputs/kept.txt"])
run.written  # => ["outputs/kept.txt"]
```

## awk differences

Bashkit's `awk` differs from GNU awk in two places found so far:

- A regex field separator (`-F'[ ,]+'`) yields empty fields. Single-character separators (`-F,`)
  work.
- `sub()` on a field (`sub(/,/, "", $2)`) leaves the field unchanged. `gsub()` on the whole line
  works.
