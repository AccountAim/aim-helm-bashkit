# Stores

`AimHelmBashkit::Workspace` reads and saves documents through a store: any object with

- `read(path)` returning the content, or `nil` when missing;
- `write(path, content)`;
- `delete(path)`.

Paths are relative (`inputs/schema.sql`). The store's scope decides which documents a workspace can
reach; the shell sees only the paths listed in each `execute` call.

## aim-helm-rails Workspace adapter

`AimHelmRails::Features::Workspace::Adapters::ActiveRecord` already implements the contract over
`WorkspaceDocument`, scoped by tenant, optional actor, kind, and key:

```ruby
store = AimHelmRails::Features::Workspace::Adapters::ActiveRecord.new(
  kind: :artifacts,
  key: chat.id,
  tenant: current_tenant,
)

run = AimHelmBashkit::Workspace.new(store).execute(
  "rg -ni premium inputs/schema.sql > outputs/money.txt",
  files: ["inputs/schema.sql", "outputs/money.txt"],
  timeout_seconds: 30,
)

run.written  # => ["outputs/money.txt"], now a WorkspaceDocument row
```

## Any Active Record model

A model with `path` and `content` columns works through a scoped relation:

```ruby
class RecordStore
  def initialize(scope) = @scope = scope

  def read(path) = @scope.where(path:).pick(:content)
  def write(path, content) = @scope.find_or_initialize_by(path:).update!(content:)
  def delete(path) = @scope.where(path:).delete_all
end

store = RecordStore.new(Document.where(chat_id: chat.id))
```

## Concurrency

Saves are last-writer-wins: a document edited elsewhere while a script runs is overwritten by the
script's version.
