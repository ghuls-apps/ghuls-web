require_relative 'constants'

module Helpers
  # Combines organization and personal language data into a single set.
  # @param lang_data [Hash] The language data from #language_data.
  # @return [Hash] All data, including language bytes, fancy name, and colors.
  def combine_data(lang_data)
    if lang_data[:user_personal_exists] && lang_data[:org_exists]
      lang_colors = []
      demonym = nil
      adjective = StringUtility.random_line(Constants::ADJECTIVE_PATH)
      data = lang_data[:user_data].clone.update(lang_data[:org_data]) do |_, v1, v2|
        v1 + v2
      end
      data.each do |l, b|
        if b == data.values.max
          if Constants::DEMONYMS.key?(l.to_s)
            demonym = Constants::DEMONYMS.fetch(l.to_s)
          else
            demonym = "#{l} coder"
          end
        end
        lang_colors.push(GHULS::Lib.get_color_for_language(l.to_s, GH[:colors]))
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
    user_langs = GHULS::Lib.get_user_langs(user, GH[:git])
    org_langs = GHULS::Lib.get_org_langs(user, GH[:git])
    ret = {}

    if !user_langs.empty?
      adjective = StringUtility.random_line(Constants::ADJECTIVE_PATH)
      demonym = nil
      user_colors = []
      user_langs.each do |l, b|
        if b == user_langs.values.max
          if Constants::DEMONYMS.key?(l.to_s)
            demonym = Constants::DEMONYMS.fetch(l.to_s)
          else
            demonym = "#{l} coder"
          end
        end
        user_colors.push(GHULS::Lib.get_color_for_language(l.to_s, GH[:colors]))
      end

      ret[:user_data] = user_langs
      ret[:user_fancy_name] = "#{adjective} #{demonym}"
      ret[:user_colors] = user_colors
      ret[:user_personal_exists] = true
    else
      ret[:user_personal_exists] = false
    end

    if !org_langs.empty?
      adjective = StringUtility.random_line(Constants::ADJECTIVE_PATH)
      demonym = nil
      org_colors = []
      org_langs.each do |l, b|
        if b == org_langs.values.max
          if Constants::DEMONYMS.key?(l.to_s)
            demonym = Constants::DEMONYMS.fetch(l.to_s)
          else
            demonym = "#{l} coder"
          end
        end
        org_colors.push(GHULS::Lib.get_color_for_language(l.to_s, GH[:colors]))
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
      next if repos[:forks].include? r
      repo_data[r] = GHULS::Lib.get_forks_stars_watchers(r, GH[:git])
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
  # @return [Hash] The repositories and their according issues and pull counts.
  def issue_data(username, repos)
    repo_data = {}
    repos[:public].each do |r|
      next if repos[:forks].include? r
      repo_data[r] = GHULS::Lib.get_issues_pulls(r, GH[:git])
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
end