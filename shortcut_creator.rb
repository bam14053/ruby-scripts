require "win32/shortcut"
include Win32

directories = Dir.glob('**/*.[a-z]*')

for x in 0..directories.length-1 do
  file = directories[x]
  next if(File.extname(file) == ".lnk")
  for y in (x+1)..directories.length-1 do
    f = directories[y]
    #no need to continue when dealing with a shortcut, so next =>
    next if(File.extname(f) == ".lnk")
    #check whether file is correct to be deleted
    begin
      if(File.basename(f) == File.basename(file) && File.size(f) == File.size(file))
        Shortcut.new(File.dirname(f)+'/'+File.basename(f,".*")+'.lnk') do |s|
          s.description       = File.basename(file)
          s.path              = File.expand_path(file)
          s.show_cmd          = Shortcut::SHOWNORMAL
          s.working_directory = File.expand_path(file)[0,3]
        end
        #delete the file from the pc and the array
        File.delete f
      end
      rescue Errno::ENOENT
        next
      end
    end
  end
