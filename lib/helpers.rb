require_relative 'constants'

module Helpers
  # @return [String] A random line from the adjective file.
  def random_adjective
    Constants::ADJECTIVE_LINES[rand(Constants::ADJECTIVE_NUM_LINES)]
  end

  # Combines organization and personal language data into a single set.
  # @param lang_data [Hash] The language data from #language_data.
  # @return [Hash] All data, including language bytes, fancy name, and colors.
  def combine_data(lang_data)
    if lang_data[:user_personal_exists] && lang_data[:org_exists]
      lang_colors = []
      demonym = nil
      adjective = random_adjective
      data = lang_data[:user_data].clone.update(lang_data[:org_data]) do |_, v1, v2|
        v1 + v2
      end
      max = data.values.max
      data.each do |l, b|
        if b ==  max
          demonym = Constants::DEMONYMS.key?(l.to_s) ? Constants::DEMONYMS.fetch(l.to_s) : "#{l} coder"
        end
        lang_colors << GH.get_color_for_language(l.to_s)
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
  # @return [Hash] A hash containing all language data possible.
  def language_data(user)
    user_langs = GH.get_user_langs(user)
    org_langs = GH.get_org_langs(user)
    ret = {}

    if !user_langs.empty?
      adjective = random_adjective
      demonym = nil
      user_colors = []
      max = user_langs.values.max
      user_langs.each do |l, b|
        if b == max
          demonym = Constants::DEMONYMS.key?(l.to_s) ? Constants::DEMONYMS.fetch(l.to_s) : "#{l} coder"
        end
        user_colors << GH.get_color_for_language(l.to_s)
      end

      ret[:user_data] = user_langs
      ret[:user_fancy_name] = "#{adjective} #{demonym}"
      ret[:user_colors] = user_colors
      ret[:user_personal_exists] = true
    else
      ret[:user_personal_exists] = false
    end

    if !org_langs.empty?
      adjective = random_adjective
      demonym = nil
      org_colors = []
      max = org_langs.values.max
      org_langs.each do |l, b|
        if b == max
          demonym = Constants::DEMONYMS.key?(l.to_s) ? Constants::DEMONYMS.fetch(l.to_s) : "#{l} coder"
        end
        org_colors << GH.get_color_for_language(l.to_s)
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
  # @return [Hash] The repositories and their according forks, stars, and watchers
  def fork_data(username, repos)
    repo_data = {}
    repos[:public].each do |r|
      next if repos[:forks].include?(r)
      repo_data[r] = GH.get_forks_stars_watchers(r)
    end
    ret = [
      { name: 'Forks', data: [] },
      { name: 'Stargazers', data: [] },
      { name: 'Watchers', data: [] }
    ]
    repo_data.each do |repo, hash|
      rep = repo.sub("#{username}/", '')
      next if hash[:forks] < 1 && hash[:stars] < 1 && hash[:watchers] < 1
      ret[0][:data] << [rep, hash[:forks]]
      ret[1][:data] << [rep, hash[:stars]]
      ret[2][:data] << [rep, hash[:watchers]]
    end
    ret
  end

  # Gets issue data for the repositories.
  # @param username [String] See #fork_data
  # @param repos [Hash] See #fork_data
  # @return [Hash] The repositories and their according issues and pull counts.
  def issue_data(username, repos)
    repo_data = {}
    repos[:public].each do |r|
      next if repos[:forks].include?(r)
      repo_data[r] = GH.get_issues_pulls(r)
    end
    ret = [
      { name: 'Open Issues', data: [] },
      { name: 'Closed Issues', data: [] },
      { name: 'Open Pulls', data: [] },
      { name: 'Merged Pulls', data: [] },
      { name: 'Closed Pulls', data: [] }
    ]
    repo_data.each do |repo, hash|
      rep = repo.sub("#{username}/", '')
      next if hash[:issues][:open] < 1 && hash[:issues][:closed] < 1 && hash[:pulls][:open] < 1 &&
              hash[:pulls][:merged] < 1 && hash[:pulls][:closed] < 1
      ret[0][:data] << [rep, hash[:issues][:open]]
      ret[1][:data] << [rep, hash[:issues][:closed]]
      ret[2][:data] << [rep, hash[:pulls][:open]]
      ret[3][:data] << [rep, hash[:pulls][:merged]]
      ret[4][:data] << [rep, hash[:pulls][:closed]]
    end
    ret
  end

  # Gets the repository total for each category.
  # @param repos [Hash] See #fork_data
  # @return [Hash] A hash containing the totals for all repo types.
  def repo_count(repos)
    {
      'Public': repos[:public].size,
      'Forks': repos[:forks].size,
      'Mirrors': repos[:mirrors].size,
      'Privates': repos[:privates].size
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
end
