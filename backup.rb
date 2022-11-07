require 'time'

# encoding: utf-8
time_start = Time.now

stations = []

path = File.expand_path(File.dirname(__FILE__)) + "\\"

path = path.gsub("/","\\")

###### Konfigurace ######
# backup_location = "S:\\Automatizace\\Backup_scada2\\bck\\"
# err_location = "S:\\Automatizace\\Backup_scada2\\err\\"
# log_location = "S:\\Automatizace\\Backup_scada2\\log\\"
backup_location = "\\\\fosfa.local\\data\\Teams\\Automatizace\\Backup_scada2\\bck\\"
err_location = "\\\\fosfa.local\\data\\Teams\\Automatizace\\Backup_scada2\\err\\"
log_location = "\\\\fosfa.local\\data\\Teams\\Automatizace\\Backup_scada2\\log\\"

####### přečíst stanice a zapsat je ######
# stations[0][0] = stanice 1 IP
# stations[0][1] = stanice 1 share
# stations[0][2] = stanice 1 jméno uživatele
# stations[0][3] = stanice 1 heslo uživatele
# stations[0][4] = cesta která se má zálohovat
# stations[0][5] = vyjímky zálohování
File.readlines("#{path}stations.csv").each { |line|
    station = line.encode('UTF-8', :invalid => :replace).delete("\n").split(";")
    stations.append(station)
}

year_week = Time.now.strftime("%Y-%W") # Rok a týden

system("del /Q #{err_location.gsub("/","\\")}*.*")  # smaže všechny předchozí errory
system("del /Q #{log_location.gsub("/","\\")}*.*")  # smaže všechny předchozí logy
system("del /Q #{path.gsub("/","\\")}log.7z")  # smaže log co byl minule poslán emailem .7z
system("del /Q #{path.gsub("/","\\")}log.rar")  # smaže log co byl minule poslán emailem .rar
system("del /Q #{path.gsub("/","\\")}errors.txt")  # smaže error log z minula

####### vytvoření backupů ######
stations.each_with_index { |station, i|
    if system("ping -w 800 #{station[0]} -n 4")  # backup only if station is online

        puts("\n ==== připojit disk ====")
        connect = "net use /y Q: \\\\#{station[0]}\\#{station[1]}"
        if station[2] != ""  # pokud je uvedené jméno
            connect = connect +  " /user:#{station[2]} #{station[3]}"
        end
        system(connect) # připojit síťový disk

        puts("==== start archivace ====")

        if station[5].to_s != ""  # přídání
            archive_end = "#{station[4]} "+station[5]+" 1> #{log_location}log-#{station[0]}.txt 2> #{err_location}err-#{station[0]}.txt"
        else
            archive_end = "#{station[4]} 1> #{log_location}log-#{station[0]}.txt 2> #{err_location}err-#{station[0]}.txt"
        end 

        if ARGV[1] == "rar"
            archive_cmd = "#{path}programy\\WinRar611_x64\\Rar.exe a -u -r -as -y -m5 -o+ -dh #{backup_location}backup_#{station[0]}_#{year_week}.rar " + archive_end       
        else
            archive_cmd = "#{path}programy\\7z2200_x64\\7za.exe u -r -up1q0r2x1y2z1w2 -y -bb #{backup_location}backup_#{station[0]}_#{year_week}.7z " + archive_end
        end
        system(archive_cmd)
        puts("==== konec archivace ===")

        puts("\n ==== odpojit disk ====")
        system("net use Q: /d /y") # odpojit připojený síťový disk

        date_time = Time.now.strftime("\n%-d.%-m.%Y\n%H:%M")
        File.open("#{log_location}log-#{station[0]}.txt", "a") { |f|
            f.write(date_time) }
    else
        File.open("#{err_location}err-#{station[0]}.txt", "w") { |f|
            f.write(" !!!!!!!!!!!!!!!!!!!! #{station[0]} OFFLINE! !!!!!!!!!!!!!!!!!!!!") }
    end
    puts("==================== Dokončeno #{i+1}. #{station[0]} ====================\n")
}

###### Tělo emailu ######
error_logs2 = []

error_logs = Dir.glob("#{err_location.gsub("\\","/")}err*.txt")
puts("#{err_location}err*" + error_logs.to_s)

error_logs.each { |log|
    unless File.zero?(log)
        error_logs2.append(log)
    end
}

time_end = Time.now
time_taken = time_end - time_start

File.open("#{path}errors.txt", "w") { |f|
    f.write("Spuštěno v #{time_start.strftime("%k:%M:%S")}, ukončeno v #{time_end.strftime("%k:%M:%S")}, zabralo #{Time.at(time_taken).utc.strftime("%H:%M:%S")}\n\n\n")
	
    error_logs2.each { |log|
        f.write("==================== #{log} ====================\n\n")
        File.readlines(log, :encoding => "CP852").each { |line|  # otevřít soubor v kódové stránce 852
            if line != "\n"
                line = line.encode("UTF-8")  # překódování textu z CP852 na UTF-8
                f.write(line)
                puts(line)
            end
            }
        f.write("\n\n")
        }
    }

# zabalení logů do log.7z
if ARGV[1] == "rar"
    system("#{path}programy/WinRar611_x64/Rar.exe a log.rar #{log_location}log*")
    log = path+"log.rar"
else
    system("#{path}programy/7z2200_x64/7za.exe a log.7z #{log_location}log*")
    log = path+"log.7z"
end

# odelsání mailu
if ARGV[0] == "log"
	system("#{path}programy/blat3222_x64/blat.exe #{path}errors.txt -ti 45 -to \"kurz@fosfa.cz, cypris@fosfa.cz\" -subject \"backup scada 2\" -f backup_scada@noreply.com -server smtp.fosfa.cz -attach #{log}")
else
	system("#{path}programy/blat3222_x64/blat.exe #{path}errors.txt -ti 45 -to \"kurz@fosfa.cz\" -subject \"TESTING backup scada 2\" -f backup_scada@noreply.com -server smtp.fosfa.cz -attach #{log}")
end
