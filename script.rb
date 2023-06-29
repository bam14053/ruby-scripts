require "open-uri"
require 'uri'

def download(filename, path)
  puts "Downloading #{filename}"
  path = URI.escape(path)
  retries = 0;
  begin
    File.open(filename, "w") do |f|
      IO.copy_stream(open(path), f)
    end
  rescue
    if(retries < 3)
      retries += 1
      retry
    else
      File.delete(filename)
      puts filename+" has an error with path: "+path
    end
  end
end

Dir.chdir("/Users/abi/Music/")

link = ''
http_link = ''
loop do
  puts "Please enter the link where I should download from: "
  link = gets.chomp
  http_link = link.scan(/(\S+(.net|.com))\//)[0][0]
  break if !http_link.empty?
end

puts "Enter folder name, where the files should be download: "
dir = gets.chomp

if (dir.length > 0 )
   Dir.mkdir(dir) unless Dir.exist?(dir)
end
Dir.chdir(dir)

mp3_files = open(link).read.scan(/href=['|"](.+.mp3)['|"][\s|>]/)
puts "Found #{mp3_files.length} downloadable files, is this correct? "
mp3_files.each do |file|
  uri_path = file.join
  if !uri_path.include? http_link
    uri_path = http_link + "/" + uri_path
  end
  uri_path.gsub! '\\', '/'
  file_name = uri_path.scan(/\S+\/(.+.mp3)/)[0][0]
  download(file_name,uri_path) unless File.exist?(file_name)
end
