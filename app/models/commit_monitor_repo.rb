class CommitMonitorRepo < ActiveRecord::Base
  has_many :branches, :class_name => :CommitMonitorBranch, :dependent => :destroy

  validates :name, :presence => true, :uniqueness => true
  validates :path, :presence => true, :uniqueness => true

  def self.create_from_github!(upstream_user, name, path)
    MiqToolsServices::MiniGit.call(path) do |git|
      git.checkout("master")
      git.pull

      repo = self.create!(
        :upstream_user => upstream_user,
        :name          => name,
        :path          => File.expand_path(path)
      )

      repo.branches.create!(
        :name        => "master",
        :commit_uri  => CommitMonitorBranch.github_commit_uri(upstream_user, name),
        :last_commit => git.current_ref
      )

      repo
    end
  end

  def fq_name
    "#{upstream_user}/#{name}"
  end

  def path=(val)
    super(File.expand_path(val))
  end

  def with_git_service
    raise "no block given" unless block_given?
    MiqToolsServices::MiniGit.call(path) { |git| yield git }
  end

  def with_github_service
    raise "no block given" unless block_given?
    MiqToolsServices::Github.call(:repo => name, :user => upstream_user) { |github| yield github }
  end

  def with_travis_service
    raise "no block given" unless block_given?
    client = Travis::Client.new
    client.github_auth(Settings.github_credentials.password) # Assumes password is holding a token
    repo = client.repo(fq_name)
    yield repo
  end
end
