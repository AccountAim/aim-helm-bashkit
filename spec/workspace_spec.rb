# frozen_string_literal: true

RSpec.describe AimHelmBashkit::Workspace do
  subject(:workspace) { described_class.new(store) }

  let(:store) { HashStore.new("inputs/schema.sql" => schema, "notes.md" => "keep\n") }
  let(:schema) { "#{"-- padding\n" * 200_000}premium_amount INTEGER,\nname TEXT\n" }

  before do
    stub_const("HashStore", Class.new do
      attr_reader :documents

      def initialize(documents) = @documents = documents.dup
      def read(path) = documents[path]
      def write(path, content) = documents[path] = content
      def delete(path) = documents.delete(path)
    end)
  end

  it "copies only the listed files in and saves listed files the script writes" do
    run = workspace.execute(<<~SH, files: ["inputs/schema.sql", "outputs/money.txt"])
      ls notes.md
      rg -n premium inputs/schema.sql > outputs/money.txt
    SH

    expect(run.result.stderr).to include("notes.md")
    expect(run.written).to eq(["outputs/money.txt"])
    expect(store.documents["outputs/money.txt"]).to eq("200001:premium_amount INTEGER,\n")
    expect(store.documents["inputs/schema.sql"]).to eq(schema)
  end

  it "saves edits to and deletions of listed files" do
    run = workspace.execute("echo more >> notes.md; rm inputs/schema.sql",
                            files: %w[notes.md inputs/schema.sql])

    expect(run.written).to eq(["notes.md"])
    expect(run.deleted).to eq(["inputs/schema.sql"])
    expect(store.documents).to eq("notes.md" => "keep\nmore\n")
  end

  it "leaves a listed file the script never created out of the store" do
    run = workspace.execute("true", files: ["drafts/a.md"])

    expect(run.written).to be_empty
    expect(run.deleted).to be_empty
    expect(store.documents).not_to have_key("drafts/a.md")
  end

  it "discards unlisted files" do
    run = workspace.execute(<<~SH, files: ["outputs/deep/a b.txt"])
      echo x > scratch.txt
      echo y > /tmp/t
      echo z > "outputs/deep/a b.txt"
    SH

    expect(run.written).to eq(["outputs/deep/a b.txt"])
    expect(store.documents.keys).to contain_exactly("inputs/schema.sql", "notes.md",
                                                    "outputs/deep/a b.txt")
  end

  it "treats a listed path turned into a directory as deleted" do
    run = workspace.execute("rm notes.md; mkdir notes.md", files: ["notes.md"])

    expect(run.deleted).to eq(["notes.md"])
  end

  it "accepts absolute paths under root" do
    run = workspace.execute("echo hi >> /workspace/notes.md", files: ["/workspace/notes.md"])

    expect(run.written).to eq(["notes.md"])
  end

  it "rejects paths that escape the workspace" do
    %w[../etc/passwd /etc/passwd a//b ./a dir/].each do |path|
      expect do
        workspace.execute("true", files: [path])
      end.to raise_error(ArgumentError, /invalid workspace path/)
    end
  end

  it "saves what was written before a failure" do
    run = workspace.execute("echo partial > outputs/p.txt; exit 2", files: ["outputs/p.txt"])

    expect(run.result.exit_code).to eq(2)
    expect(store.documents["outputs/p.txt"]).to eq("partial\n")
  end

  it "passes interpreter options through" do
    run = workspace.execute("sleep 5", timeout_seconds: 0.1)

    expect(run.result.error).to include("execution timeout")
  end
end
