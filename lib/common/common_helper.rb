# encoding: UTF-8

LIB_DIR              = File.expand_path(File.join(File.dirname(__FILE__), '..'))
ROOT_DIR             = File.expand_path(File.join(LIB_DIR, '..')) 
DATA_DIR             = File.join(ROOT_DIR, 'data')
CONF_DIR             = File.join(ROOT_DIR, 'conf')
CACHE_DIR            = File.join(ROOT_DIR, 'cache')
VANE_LIB_DIR         = File.join(LIB_DIR, 'vane')
VANETOOLS_LIB_DIR    = File.join(LIB_DIR, 'vanetools')
UPDATER_LIB_DIR      = File.join(LIB_DIR, 'updater')
COMMON_LIB_DIR       = File.join(LIB_DIR, 'common')
MODELS_LIB_DIR       = File.join(COMMON_LIB_DIR, 'models')
COLLECTIONS_LIB_DIR  = File.join(COMMON_LIB_DIR, 'collections')

LOG_FILE             = File.join(ROOT_DIR, 'log.txt')

# Plugins directories
COMMON_PLUGINS_DIR   = File.join(COMMON_LIB_DIR, 'plugins')
VANE_PLUGINS_DIR      = File.join(VANE_LIB_DIR, 'plugins') # Not used ATM
VANETOOLS_PLUGINS_DIR = File.join(VANE_LIB_DIR, 'plugins')

# Data files
PLUGINS_FILE        = File.join(DATA_DIR, 'plugins.txt')
PLUGINS_FULL_FILE   = File.join(DATA_DIR, 'plugins_full.txt')
PLUGINS_VULNS_FILE  = File.join(DATA_DIR, 'plugin_vulns.json')
THEMES_FILE         = File.join(DATA_DIR, 'themes.txt')
THEMES_FULL_FILE    = File.join(DATA_DIR, 'themes_full.txt')
THEMES_VULNS_FILE   = File.join(DATA_DIR, 'theme_vulns.json')
WP_VULNS_FILE       = File.join(DATA_DIR, 'wp_vulns.json')
WP_VERSIONS_FILE    = File.join(DATA_DIR, 'wp_versions.xml')
LOCAL_FILES_FILE    = File.join(DATA_DIR, 'local_vulnerable_files.xml')
# VULNS_XSD           = File.join(DATA_DIR, 'vuln.xsd')
WP_VERSIONS_XSD     = File.join(DATA_DIR, 'wp_versions.xsd')
LOCAL_FILES_XSD     = File.join(DATA_DIR, 'local_vulnerable_files.xsd')
USER_AGENTS_FILE    = File.join(DATA_DIR, 'user-agents.txt')

VANE_VERSION       = '1.0'

$LOAD_PATH.unshift(LIB_DIR)
$LOAD_PATH.unshift(VANE_LIB_DIR)
$LOAD_PATH.unshift(MODELS_LIB_DIR)

def kali_linux?
  begin
    File.readlines("/etc/debian_version").grep(/^kali/i).any?
  rescue
    false
  end
end

require 'environment'

# TODO : add an exclude pattern ?
def require_files_from_directory(absolute_dir_path, files_pattern = '*.rb')
  files = Dir[File.join(absolute_dir_path, files_pattern)]

  # Files in the root dir are loaded first, then those in the subdirectories
  files.sort_by { |file| [file.count("/"), file] }.each do |f|
    f = File.expand_path(f)
    #puts "require #{f}" # Used for debug
    require f
  end
end

require_files_from_directory(COMMON_LIB_DIR, '**/*.rb')

# Add protocol
def add_http_protocol(url)
  url =~ /^https?:/ ? url : "http://#{url}"
end

def add_trailing_slash(url)
  url =~ /\/$/ ? url : "#{url}/"
end

def missing_db_file?
  DbUpdater::FILES.each do |db_file|
    return true unless File.exist?(File.join(DATA_DIR, db_file))
  end
  false
end

# Define colors
def colorize(text, color_code)
  if $COLORSWITCH
    "#{text}"
  else
    "\e[#{color_code}m#{text}\e[0m"
  end
end

def bold(text)
  colorize(text, 1)
end

def red(text)
  colorize(text, 31)
end

def green(text)
  colorize(text, 32)
end

def amber(text)
  colorize(text, 33)
end

def blue(text)
  colorize(text, 34)
end

def critical(text)
  red(text)
end

def warning(text)
  amber(text)
end

def info(text)
  green(text)
end

def notice(text)
  blue(text)
end

def banner
  puts 'Vane - a Free WordPress vulnerability scanner'
end

def xml(file)
  Nokogiri::XML(File.open(file)) do |config|
    config.noblanks
  end
end

def json(file)
  content = File.open(file).read

  begin
    JSON.parse(content)
  rescue => e
    puts "[ERROR] In JSON file parsing #{file} #{e}"
    raise
  end
end

def redefine_constant(constant, value)
  Object.send(:remove_const, constant)
  Object.const_set(constant, value)
end

# Gets the string all elements in stringarray ends with
def get_equal_string_end(stringarray = [''])
  already_found = ''
  looping = true
  counter = -1
  # remove nils (# Issue #232)
  stringarray = stringarray.compact
  if stringarray.kind_of? Array and stringarray.length > 1
    base = stringarray.first
    while looping
      character = base[counter, 1]
      stringarray.each do |s|
        if s[counter, 1] != character
          looping = false
          break
        end
      end
      if looping == false or (counter * -1) > base.length
        break
      end
      already_found = "#{character if character}#{already_found}"
      counter -= 1
    end
  end
  already_found
end

def remove_base64_images_from_html(html)
  # remove data:image/png;base64, images
  base64regex = %r{(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?}
  imageregex = %r{data\s*:\s*image/[^\s;]+\s*;\s*base64\s*,\s*}
  html.gsub(/["']\s*#{imageregex}#{base64regex}\s*["']/, '""')
end

# @return [ Integer ] The memory of the current process in Bytes
def get_memory_usage
  `ps -o rss= -p #{Process.pid}`.to_i * 1024 # ps returns the value in KB
end

# Use the wc system command to count the number of lines in the file
# instead of using File.open which will use to much memory for large file (10 times the size of the file)
#
# @return [ Integer ] The number of lines in the given file
def count_file_lines(file)
  `wc -l #{file.shellescape}`.split[0].to_i
end

# Truncates a string to a specific length and adds ... at the end
def truncate(input, size, trailing = '...')
  size = size.to_i
  trailing ||= ''
  return input if input.nil? or size <= 0 or input.length <= size or
      trailing.length >= input.length or size-trailing.length-1 >= input.length
  return "#{input[0..size-trailing.length-1]}#{trailing}"
end

# Gets a random User-Agent
#
# @return [ String ] A random user-agent from data/user-agents.txt
def get_random_user_agent
  user_agents = []
  f = File.open(USER_AGENTS_FILE, 'r')
  f.each_line do |line|
    # ignore comments
    next if line.empty? or line =~ /^\s*(#|\/\/)/
    user_agents << line.strip
  end
  f.close
  # return ransom user-agent
  user_agents.sample
end

# Directory listing enabled on url?
#
# @return [ Boolean ]
def directory_listing_enabled?(url)
  Browser.get(url.to_s).body[%r{<title>Index of}] ? true : false
end
