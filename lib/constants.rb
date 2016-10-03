require 'yaml'

module Constants
  DEMONYMS = YAML.load_file("#{Dir.pwd}/public/demonyms.yml").freeze
  ADJECTIVE_PATH = "#{Dir.pwd}/public/adjectives.txt".freeze
  ADJECTIVE_LINES = File.readlines(ADJECTIVE_PATH).freeze
  ADJECTIVE_NUM_LINES = ADJECTIVE_LINES.length
  MONTH_MAP = {
    '01' => 'January',
    '02' => 'February',
    '03' => 'March',
    '04' => 'April',
    '05' => 'May',
    '06' => 'June',
    '07' => 'July',
    '08' => 'August',
    '09' => 'September',
    '10' => 'October',
    '11' => 'November',
    '12' => 'December'
  }.freeze
end
