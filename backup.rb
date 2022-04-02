# encoding: utf-8
stations = []
path = File.expand_path(File.dirname(__FILE__)) + "/"
start_time = Time.now.strftime("%H:%M")

###### Konfigurace ######
backup_location = "#{path}bck/"
err_location = "#{path}err/"
log_location = "#{path}log/"

####### přečíst stanice a zapsat je ######
# stations[0][0] = stanice 1 IP
# stations[0][1] = stanice 1 jméno uživatele
# stations[0][2] = stanice 1 heslo uživatele
# stations[0][3] = cesta která se má zálohovat
File.readlines("#{path}stations.csv").each do |line|
    station = line.encode('UTF-8', :invalid => :replace).split(";")
    stations.append(station)
end

Year_Week = Time.now.strftime("%Y-%W") # Rok a týden

####### vytvoření backupů ######
stations.each_with_index { |station, i|
    if system("ping -w 800 #{station[0]} -n 4")  # backup only if station is online
        station[3] = "\"#{station[3]}\""  # přidání uvozovek

        puts("\n ==== připojit disk ====")°°
        connect = "net use Q: \\\\#{station[0]}\\c$"
        if station[1] != ""  # pokud je uvedené jméno
            connect = connect +  " /user:#{station[1]} #{station[2]}"
        end
        system(connect) # připojit síťový disk

        puts("==== start archivace ====")
		system("#{path}programy/7z2107_x64/7za.exe u -r -up1q0r2x1y2z1w2 -y -bb #{backup_location}backup_#{station[0]}_#{Year_Week}.7z " +
			   "#{station[3]} 1> #{log_location}log-#{station[0]}.txt 2> #{err_location}err-#{station[0]}.txt")  # vytvořit backup
        puts("==== konec archivace ===")

        puts("\n ==== odpojit disk ====")
        system("net use Q: /d /y") # odpojit připojený síťový disk

        date_Time = Time.now.strftime("\n%-d.%-m.%Y\n%H:%M")
        File.open("#{log_location}log-#{station[0]}.txt", "a") { |f|
            f.write(date_Time) }
    else
        File.open("#{err_location}err-#{station[0]}.txt", "w") { |f|
            f.write(" !!!!!!!!!!!!!!!!!!!! #{station[0]} OFFLINE! !!!!!!!!!!!!!!!!!!!!") }
    end
    puts("==================== Dokončeno #{i+1}. #{station[0]} ====================\n")
}

end_time = Time.now.strftime("%H:%M")

puts("spuštěn v: #{start_time}\ndokončeno v #{end_time}")

###### Tělo emailu ######
error_logs2 = []

error_logs = Dir.glob("#{err_location}err*.txt")
puts("#{err_location}err*" + error_logs.to_s)

error_logs.each { |log|
    if !File.zero?(log)
        error_logs2.append(log)
    end
}

File.open("#{path}errors.txt", "w") { |f|
    error_logs2.each { |log|
        f.write("==================== #{log} ====================\n\n")
        File.readlines(log).each { |line|
            if line != "\n"
                f.write(line)
            end
            }
        f.write("\n\n")
        }
    }

# zabalení logů do log.7z
system("#{path}programy/7z2107_x64/7za.exe a log.7z #{log_location}log*")

# odelsání mailu
system("#{path}programy/blat3222_x64/blat.exe #{path}errors.txt -ti 45 -to \"kurz@fosfa.cz\" -subject \"backup scada\" -f backup_scada@noreply.com -server smtp.fosfa.cz -attach #{path}log.7z")
