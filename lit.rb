require "pathname"
require "fileutils"

require_relative './refs'
require_relative './author'
require_relative './workspace'
require_relative './database'
require_relative './entry'

command = ARGV.shift

case command
when "init"
  path = ARGV.fetch(0, Dir.getwd)

  root_path = Pathname.new(File.expand_path(path))
  git_path = root_path.join(".git")

  %w(objects refs).each do |dir|
    begin
      FileUtils.mkdir_p(git_path.join(dir))
    rescue Errno::EACCES => error
      $stderr.puts "fatal: #{ error.message }"
      exit 1
    end
  end

  puts "Initialized empty lit repository in #{ git_path }"

when "commit"
  root_path = Pathname.new(Dir.getwd)
  git_path = root_path.join(".git")
  db_path = git_path.join("objects")

  workspace = Workspace.new(root_path)
  database = Database.new(db_path)
  refs = Refs.new(git_path)

  entries = workspace.list_files.map do |path|
    data = workspace.read_file(path)
    blob = Blob.new(data)

    database.store(blob)

    Entry.new(path, blob.oid)
  end

  tree = Tree.new(entries)
  database.store(tree)

  parent = refs.read_head
  email = ENV.fetch("GIT_AUTHOR_EMAIL")
  name = ENV.fetch("GIT_AUTHOR_NAME")
  author = Author.new(name, email, Time.now)
  message = $stdin.read
  commit = Commit.new(parent, tree.oid, author, message)

  database.store(commit)

  File.open(git_path.join("HEAD"), File::WRONLY | File::CREAT) do |file|
    file.puts(commit.oid)
  end

  puts "[#{parent.nil? ? "(root commit)" : ""} #{ commit.oid }] #{ message.lines.first }"
  exit 0

else
  $stderr.puts "lit: '#{command}' is not a valid lit command"
  exit 1
end

