require 'sinatra'
require 'chartkick'
require 'yaml'
require 'string-utility'
require 'ghuls/lib'

gh = GHULS::Lib.configure_stuff(token: ENV['GHULS_TOKEN'])
demonyms = YAML.load_file('public/demonyms.yml')
adjective_path = 'public/adjectives.txt'

get '/' do
  erb :index
end

get '/analyze' do
  if params[:user].nil?
    random = GHULS::Lib.get_random_user(gh[:git])
    redirect to("/analyze?user=#{random}")
  end
  analyze(params[:user], gh, demonyms, adjective_path)
end

# Gets all the data possible. Will not get any user or org analyzed data if the
#   user does not exist, to prevent unnecessary API calls.
# @param user [Any] The user ID or name.
# @param gh [Octokit::Client] The instance of Octokit::Client.
def get_data(user, gh)
  ret = {}
  ret[:user_info] = GHULS::Lib.get_user_and_check(user, gh)
  if ret[:user_info] != false
    ret[:user_data] = GHULS::Lib.analyze_user(user, gh)
    ret[:orgs_data] = GHULS::Lib.analyze_orgs(user, gh)
  end

  ret
end

def analyze(user, gh, demonyms, adjective_path)
  all_data = get_data(user, gh[:git])
  variables = {}
  if all_data[:user_info] == false
    erb :fail, locals: { user: user, error: 'UserNotFound' }
  elsif all_data[:user_data].nil? && all_data[:orgs_data].nil?
    erb :fail, locals:  {
      user: all_data[:user_info][:username],
      avatar: all_data[:user_info][:avatar],
      error: 'NoDataFound'
    }
  else
    variables[:avatar] = all_data[:user_info][:avatar]

    if !all_data[:user_data].nil?
      user_adjective = StringUtility.random_line(adjective_path)
      user_colors = []
      user_demonym = nil
      all_data[:user_data].each do |l, p|
        if p == all_data[:user_data].values.max
          if demonyms.key?(l.to_s)
            user_demonym = demonyms.fetch(l.to_s)
          else
            user_demonym = "#{l} coder"
          end
        end
        user_colors.push(GHULS::Lib.get_color_for_language(l.to_s, gh[:colors]))
      end

      user_fancy_name = "#{user_adjective} #{user_demonym}"
      variables[:user_data] = all_data[:user_data]
      variables[:user] = all_data[:user_info][:username]
      variables[:user_fancy_name] = user_fancy_name
      variables[:user_colors] = user_colors
      variables[:user_personal_exists] = true
    else
      variables[:user_personal_exists] = false
    end

    if !all_data[:orgs_data].nil?
      org_adjective = StringUtility.random_line(adjective_path)
      org_colors = []
      org_demonym = nil
      all_data[:orgs_data].each do |l, p|
        if p == all_data[:orgs_data].values.max
          if demonyms.key?(l.to_s)
            org_demonym = demonyms.fetch(l.to_s)
          else
            org_demonym = "#{l} coder"
          end
        end
        org_colors.push(GHULS::Lib.get_color_for_language(l.to_s, gh[:colors]))
      end

      orgs_fancy_name = "#{org_adjective} #{org_demonym}"
      variables[:org_data] = all_data[:orgs_data]
      variables[:org_fancy_name] = orgs_fancy_name
      variables[:org_colors] = org_colors
      variables[:org_exists] = true
    else
      variables[:org_exists] = false
    end

    erb :result, locals: variables
  end
end
