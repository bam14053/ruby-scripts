def depth (a)
    return 0 unless a.is_a?(Array)
    return 1 + depth(a[0])
end  

begin
    file = File.open("log.txt", "w")
    file.write "Stop being a dork"
ensure 
    file.close
end