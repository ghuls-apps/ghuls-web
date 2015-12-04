require 'sinatra'
require 'chartkick'
require 'yaml'
require 'string-utility'
require 'ghuls/lib'
require 'dotenv'
require 'github/calendar'

Dotenv.load
gh = GHULS::Lib.configure_stuff(token: ENV['GHULS_TOKEN'])
demonyms = YAML.load_file('public/demonyms.yml')
adjective_path = 'public/adjectives.txt'

get '/' do
  erb :index
end

get '/analyze' do
  if params[:user].nil? || params[:user].empty? || !params[:user].is_a?(String)
    random = GHULS::Lib.get_random_user(gh[:git])
    redirect to("/analyze?user=#{random[:username]}")
  end
  user = GHULS::Lib.get_user_and_check(params[:user], gh[:git])
  if user == false
    erb :fail, locals: {
      user: params[:user],
      error: 'UserNotFound'
    }
  end

  user_repos = GHULS::Lib.get_user_repos(user[:username], gh[:git])
  org_repos = GHULS::Lib.get_org_repos(user[:username], gh[:git])
  lang_data = language_data(user[:username], gh, demonyms, adjective_path)
  follow = GHULS::Lib.get_followers_following(user[:username], gh[:git])
  user_forkage = fork_data(user[:username], user_repos, gh[:git])
  org_forkage = fork_data(user[:username], org_repos, gh[:git])
  user_issues = issue_data(user[:username], user_repos, gh[:git])
  org_issues = issue_data(user[:username], org_repos, gh[:git])
  user_repo_totals = repo_count(user_repos)
  org_repo_totals = repo_count(org_repos)
  totals = {
    user: get_totals(user_forkage, user_issues),
    orgs: get_totals(org_forkage, org_issues)
  }
  locals = {
    username: user[:username],
    avatar: user[:avatar],
    language_data: lang_data,
    follow_data: follow,
    user_forks: user_forkage,
    org_forks: org_forkage,
    user_issues: user_issues,
    org_issues: org_issues,
    user_repo_totals: user_repo_totals,
    org_repo_totals: org_repo_totals,
    totals: totals,
    streaks: {
      longest: GitHub::Calendar.get_longest_streak(user[:username]),
      current: GitHub::Calendar.get_current_streak(user[:username])
    },
    calendar: {
      weekly: GitHub::Calendar.get_weekly(user[:username]),
      total_year: GitHub::Calendar.get_total_year(user[:username]),
      daily: GitHub::Calendar.get_daily(user[:username]),
      monthly: GitHub::Calendar.get_monthly(user[:username])
    },
    average: {
      week: GitHub::Calendar.get_average_week(user[:username]),
      day: GitHub::Calendar.get_average_day(user[:username]),
      month: GitHub::Calendar.get_average_month(user[:username])
    }
  }
  locals[:combined_langs] = combine_data(lang_data, demonyms, gh[:colors],
                                         adjective_path)
  erb :result, locals: locals
end

# Combines organization and personal language data into a single set.
# @param lang_data [Hash] The language data from #language_data.
# @param demonyms [Hash] The demonyms hash obtained by YAML.
# @param colors [Hash] The colors obtained by GHULS::Lib#configure_stuff.
# @param adjective_path [String] The path to the adjective file.
# @return [Hash] All data, including language bytes, fancy name, and colors.
def combine_data(lang_data, demonyms, colors, adjective_path)
  if lang_data[:user_personal_exists] && lang_data[:org_exists]
    lang_colors = []
    demonym = nil
    adjective = StringUtility.random_line(adjective_path)
    data = lang_data[:user_data].clone.update(lang_data[:org_data]) do |_, v1, v2|
      v1 + v2
    end
    data.each do |l, b|
      if b == data.values.max
        if demonyms.key?(l.to_s)
          demonym = demonyms.fetch(l.to_s)
        else
          demonym = "#{l} coder"
        end
      end
      lang_colors.push(GHULS::Lib.get_color_for_language(l.to_s, colors))
    end
    {
      data: data,
      fancy_name: "#{adjective} #{demonym}",
      colors: lang_colors
    }
  else
    nil
  end
end


# Gets language data for the user. This includes both personal and organization
# data.
# @param user [String] The username.
# @param gh [Hash] The hash obtained by GHULS::Lib.configure_stuff
# @param demonyms [Hash] The demonyms hash obtained by YAML.
# @param adjective_path [String] The path to the adjective file.
# @return [Hash] A hash containing all language data possible.
def language_data(user, gh, demonyms, adjective_path)
  user_langs = GHULS::Lib.get_user_langs(user, gh[:git])
  org_langs = GHULS::Lib.get_org_langs(user, gh[:git])
  ret = {}

  if !user_langs.empty?
    adjective = StringUtility.random_line(adjective_path)
    demonym = nil
    user_colors = []
    user_langs.each do |l, b|
      if b == user_langs.values.max
        if demonyms.key?(l.to_s)
          demonym = demonyms.fetch(l.to_s)
        else
          demonym = "#{l} coder"
        end
      end
      user_colors.push(GHULS::Lib.get_color_for_language(l.to_s, gh[:colors]))
    end

    ret[:user_data] = user_langs
    ret[:user_fancy_name] = "#{adjective} #{demonym}"
    ret[:user_colors] = user_colors
    ret[:user_personal_exists] = true
  else
    ret[:user_personal_exists] = false
  end

  if !org_langs.empty?
    adjective = StringUtility.random_line(adjective_path)
    demonym = nil
    org_colors = []
    org_langs.each do |l, b|
      if b == org_langs.values.max
        if demonyms.key?(l.to_s)
          demonym = demonyms.fetch(l.to_s)
        else
          demonym = "#{l} coder"
        end
      end
      org_colors.push(GHULS::Lib.get_color_for_language(l.to_s, gh[:colors]))
    end

    ret[:org_data] = org_langs
    ret[:org_fancy_name] = "#{adjective} #{demonym}"
    ret[:org_colors] = org_colors
    ret[:org_exists] = true
  else
    ret[:org_exists] = false
  end

  ret
end

# Gets fork data for the repositories.
# @param username [String] The username.
# @param repos [Hash] The repositories hash given by GHULS::Lib.
# @param gh [Octokit::Client] The instance of Octokit.
# @return [Hash] The repositories and their according forks, stars, and watchers
def fork_data(username, repos, gh)
  repo_data = {}
  repos[:public].each do |r|
    next if repos[:forks].include? r
    repo_data[r] = GHULS::Lib.get_forks_stars_watchers(r, gh)
  end
  ret = [
    { name: 'Forks', data: [] },
    { name: 'Stargazers', data: [] },
    { name: 'Watchers', data: [] }
  ]
  repo_data.each do |repo, hash|
    repo = repo.sub("#{username}/", '')
    next if hash[:forks] < 1 && hash[:stars] < 1 && hash[:watchers] < 1
    ret[0][:data].push([repo, hash[:forks]])
    ret[1][:data].push([repo, hash[:stars]])
    ret[2][:data].push([repo, hash[:watchers]])
  end
  ret
end

# Gets issue data for the repositories.
# @param username [String] See #fork_data
# @param repos [Hash] See #fork_data
# @param gh [Octokit::Client] See #fork_data
# @return [Hash] The repositories and their according issues and pull counts.
def issue_data(username, repos, gh)
  repo_data = {}
  repos[:public].each do |r|
    next if repos[:forks].include? r
    repo_data[r] = GHULS::Lib.get_issues_pulls(r, gh)
  end
  ret = [
    { name: 'Open Issues', data: [] },
    { name: 'Closed Issues', data: [] },
    { name: 'Open Pulls', data: [] },
    { name: 'Merged Pulls', data: [] },
    { name: 'Closed Pulls', data: [] }
  ]
  repo_data.each do |repo, hash|
    repo = repo.sub("#{username}/", '')
    next if hash[:issues][:open] < 1 && hash[:issues][:closed] < 1 &&
            hash[:pulls][:open] < 1 && hash[:pulls][:merged] < 1 &&
            hash[:pulls][:closed] < 1
    ret[0][:data].push([repo, hash[:issues][:open]])
    ret[1][:data].push([repo, hash[:issues][:closed]])
    ret[2][:data].push([repo, hash[:pulls][:open]])
    ret[3][:data].push([repo, hash[:pulls][:merged]])
    ret[4][:data].push([repo, hash[:pulls][:closed]])
  end
  ret
end

# Gets the repository total for each category.
# @param repos [Hash] See #fork_data
# @return [Hash] A hash containing the totals for all repo types.
def repo_count(repos)
  publics = 0
  forks = 0
  mirrors = 0
  privates = 0
  repos[:public].each { |_| publics += 1 }
  repos[:forks].each { |_| forks += 1 }
  repos[:mirrors].each { |_| mirrors += 1 }
  repos[:privates].each { |_| privates += 1 }
  {
    'Public': publics,
    'Forks': forks,
    'Mirrors': mirrors,
    'Privates': privates
  }
end

# Gets the total issues and fork/star/watch data for the given hashes.
# @param forkage [Hash] Return value of #fork_data.
# @param issues [Hash] Return value of #issue_data.
# @return [Hash] Combined totals of forks and issues.
def get_totals(forkage, issues)
  total_open_issues = 0
  total_closed_issues = 0
  total_open_pulls = 0
  total_merged_pulls = 0
  total_closed_pulls = 0
  total_forks = 0
  total_stars = 0
  total_watchers = 0
  issues[0][:data].each { |i| total_open_issues += i[1] }
  issues[1][:data].each { |i| total_closed_issues += i[1] }
  issues[2][:data].each { |i| total_open_pulls += i[1] }
  issues[3][:data].each { |i| total_merged_pulls += i[1] }
  issues[4][:data].each { |i| total_closed_pulls += i[1] }
  forkage[0][:data].each { |i| total_forks += i[1] }
  forkage[1][:data].each { |i| total_stars += i[1] }
  forkage[2][:data].each { |i| total_watchers += i[1] }

  {
    issues: {
      open: total_open_issues,
      closed: total_closed_issues
    },
    pulls: {
      open: total_open_pulls,
      merged: total_merged_pulls,
      closed: total_closed_pulls
    },
    forks: total_forks,
    stars: total_stars,
    watchers: total_watchers
  }
end
