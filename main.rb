require_relative 'lib/constants'
require_relative 'lib/helpers'
require 'sinatra'
require 'chartkick'
require 'yaml'
require 'string-utility'
require 'ghuls/lib'
require 'dotenv'
require 'github/calendar'

Dotenv.load

GH = GHULS::Lib.new(token: ENV['GHULS_TOKEN'])

helpers Helpers

get '/' do
  erb :index
end

get '/analyze' do
  if params[:user].nil? || params[:user].empty? || !params[:user].is_a?(String)
    random = GHULS::Lib.get_random_user
    redirect to("/analyze?user=#{random[:username]}")
  end
  user = GH.get_user_and_check(params[:user])
  unless user
    erb :fail, locals: { user: params[:user], error: 'UserNotFound' }
  end

  user_repos = GH.get_user_repos(user[:username])
  org_repos = GH.get_org_repos(user[:username])
  lang_data = language_data(user[:username])
  follow = GH.get_followers_following(user[:username])
  user_forkage = fork_data(user[:username], user_repos)
  org_forkage = fork_data(user[:username], org_repos)
  user_issues = issue_data(user[:username], user_repos)
  org_issues = issue_data(user[:username], org_repos)
  user_repo_totals = repo_count(user_repos)
  org_repo_totals = repo_count(org_repos)
  totals = {
    user: get_totals(user_forkage, user_issues),
    orgs: get_totals(org_forkage, org_issues)
  }

  months = GitHub::Calendar.get_monthly(user[:username])
  month_colors = [StringUtility.random_color_six]
  months.keys.each do |k|
    months[Constants::MONTH_MAP[k]] = months.delete(k) if Constants::MONTH_MAP[k]
  end
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
    calendar: {
      total_year: GitHub::Calendar.get_total_year(user[:username]),
      monthly: months,
      month_colors: month_colors
    },
    average: {
      week: GitHub::Calendar.get_average_week(user[:username]),
      day: GitHub::Calendar.get_average_day(user[:username]),
      month: GitHub::Calendar.get_average_month(user[:username])
    }
  }
  locals[:combined_langs] = combine_data(lang_data)
  erb :result, locals: locals
end
