# frozen_string_literal: true

module AimHelmBashkit
  # Runs a script against chosen documents from a store, then saves what changed.
  #
  # The store is any object with `read(path) -> String | nil`, `write(path, content)`,
  # and `delete(path)`. Store paths are relative ("inputs/schema.sql") and appear
  # under `root` in the shell ("/workspace/inputs/schema.sql").
  #
  # Each `execute` uses a fresh interpreter. `files` is the only way in or out:
  # listed documents are copied in, and afterwards each listed path is saved,
  # deleted, or left alone to match the shell. Anything else the script writes
  # is discarded.
  class Workspace
    Run = Data.define(:result, :written, :deleted)

    attr_reader :store, :root

    def initialize(store, root: "/workspace")
      raise ArgumentError, "root must be absolute: #{root.inspect}" unless root.start_with?("/")

      @store = store
      @root = root.chomp("/")
    end

    def execute(script, files: [], **)
      files = files.map { relative(it) }.uniq
      bash = Bash.new(cwd: root, **)
      loaded = copy_in(bash, files)
      result = bash.execute(script)
      written, deleted = copy_out(bash, loaded)

      Run.new(result:, written:, deleted:)
    ensure
      bash&.close
    end

    private

    # Parent directories exist for every listed path, so a script can write a
    # new document without `mkdir -p`.
    def copy_in(bash, files)
      files.to_h do |path|
        content = store.read(path)
        bash.mkdir(File.dirname(absolute(path)), recursive: true)
        bash.write_file(absolute(path), content) if content
        [path, content]
      end
    end

    def copy_out(bash, loaded)
      written = []
      deleted = []

      loaded.each do |path, before|
        after = read_shell_file(bash, path)

        if after.nil?
          next unless before

          store.delete(path)
          deleted << path
        elsif after != before
          store.write(path, after)
          written << path
        end
      end

      [written, deleted]
    end

    # A listed path the script removed, or turned into a directory, counts as absent.
    def read_shell_file(bash, path)
      bash.read_file(absolute(path))
    rescue Error => e
      raise unless e.code == Native::IO_ERROR

      nil
    end

    def absolute(path) = "#{root}/#{path}"

    def relative(path)
      path = path.to_s.delete_prefix("#{root}/")
      raise ArgumentError, "invalid workspace path: #{path.inspect}" unless valid?(path)

      path
    end

    def valid?(path)
      segments = path.split("/", -1)
      segments.any? && segments.none? { it.empty? || %w[. ..].include?(it) }
    end
  end
end
