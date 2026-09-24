# frozen_string_literal: true

RSpec.describe AimHelmBashkit::Bash do
  subject(:bash) { described_class.new }

  after { bash.close }

  it "keeps shell state and files across executions" do
    bash.execute("export GREETING=hi; mkdir -p /data; echo one > /data/a.txt")
    result = bash.execute("echo $GREETING; cat /data/a.txt")

    expect(result).to have_attributes(stdout: "hi\none\n", exit_code: 0, error: nil)
    expect(result).to be_success
  end

  it "applies constructor options" do
    bash = described_class.new(cwd: "/work", env: { "APP" => "x" },
                               files: { "/work/in.txt" => "data\n" })

    expect(bash.execute("pwd; echo $APP; cat in.txt").stdout).to eq("/work\nx\ndata\n")
  ensure
    bash.close
  end

  it "reports nonzero exits and stderr" do
    result = bash.execute("echo oops >&2; exit 3")

    expect(result).to have_attributes(exit_code: 3, stderr: "oops\n", error: nil)
  end

  it "returns failed runs as results" do
    result = bash.execute("echo 'unterminated")

    expect(result.exit_code).to eq(1)
    expect(result.error).to include("unterminated single quote")
  end

  it "raises BashError from execute! on failure" do
    expect { bash.execute!("exit 4") }.to raise_error(AimHelmBashkit::BashError) { expect(it.exit_code).to eq(4) }
    expect(bash.execute!("true")).to be_success
  end

  it "enforces the timeout" do
    bash = described_class.new(timeout_seconds: 0.2)

    expect(bash.execute("sleep 5").error).to include("execution timeout")
  ensure
    bash.close
  end

  it "flags truncated output" do
    bash = described_class.new(max_output_bytes: 10)

    expect(bash.execute("seq 1 100").stdout_truncated).to be(true)
  ensure
    bash.close
  end

  it "rejects unknown options" do
    expect { described_class.new(max_widgets: 1) }.to raise_error(ArgumentError, /max_widgets/)
    expect do
      described_class.new(profile: :bogus)
    end.to raise_error(AimHelmBashkit::Error, /invalid configuration/)
  end

  it "cancels from another thread without blocking Ruby" do
    ticks = 0
    ticker = Thread.new do
      loop do
        ticks += 1
        sleep 0.01
      end
    end
    Thread.new do
      sleep 0.2
      bash.cancel
    end

    result = bash.execute("sleep 1; sleep 1; echo never")
    ticker.kill

    expect(result.error).to eq("execution cancelled")
    expect(ticks).to be > 5
    expect(bash.execute("echo again").error).to eq("execution cancelled")

    bash.clear_cancel
    expect(bash.execute("echo again").stdout).to eq("again\n")
  end

  it "resets shell state and files" do
    bash.execute("X=1; echo hi > /tmp/f")
    bash.reset

    expect(bash.execute("echo ${X:-unset}; cat /tmp/f").stdout).to eq("unset\n")
  end

  describe "files" do
    it "round-trips content" do
      bash.mkdir("/data/nested", recursive: true)
      bash.write_file("/data/nested/a.txt", "héllo\n")

      expect(bash.read_file("/data/nested/a.txt")).to eq("héllo\n")
      expect(bash.execute("cat /data/nested/a.txt").stdout).to eq("héllo\n")
    end

    it "raises for missing files and parents" do
      expect { bash.read_file("/missing") }.to raise_error(AimHelmBashkit::Error, /not found/)
      expect { bash.write_file("/no/parent.txt", "x") }.to raise_error(AimHelmBashkit::Error)
    end

    it "removes files and trees" do
      bash.mkdir("/d")
      bash.write_file("/d/a", "1")
      bash.remove("/d", recursive: true)

      expect(bash.execute("test -e /d").exit_code).to eq(1)
    end
  end

  it "raises once closed" do
    bash.close

    expect { bash.execute("true") }.to raise_error(AimHelmBashkit::Error, "bash is closed")
  end
end
