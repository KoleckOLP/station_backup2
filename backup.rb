# encoding: utf-8
stations = []

path = File.expand_path(File.dirname(__FILE__)) + "/"

###### Konfigurace ######
backup_location = "#{path}bck/"
err_location = "#{path}err/"
log_location = "#{path}log/"

####### přečíst stanice a zapsat je ######
# stations[0][0] = stanice 1 IP
# stations[0][1] = stanice 1 share
# stations[0][2] = stanice 1 jméno uživatele
# stations[0][3] = stanice 1 heslo uživatele
# stations[0][4] = cesta která se má zálohovat
File.readlines("#{path}stations.csv").each { |line|
    station = line.encode('UTF-8', :invalid => :replace).delete("\n").split(";")
    stations.append(station)
}

year_week = Time.now.strftime("%Y-%W") # Rok a týden

system("del /Q #{err_location.gsub("/","\\")}*.*")  # smaže všechny předchozí errory
system("del /Q #{log_location.gsub("/","\\")}*.*")  # smaže všechny předchozí logy
system("del /Q #{path.gsub("/","\\")}log.7z")  # smaže log co byl minule poslán emailem
system("del /Q #{path.gsub("/","\\")}errors.txt")  # smaže error log z minula

####### vytvoření backupů ######
stations.each_with_index { |station, i|
    if system("ping -w 800 #{station[0]} -n 4")  # backup only if station is online
        #station[4] = "\"#{station[4]}\""  # přidání uvozovek

        puts("\n ==== připojit disk ====")
        connect = "net use Q: \\\\#{station[0]}\\#{station[1]}"
        if station[2] != ""  # pokud je uvedené jméno
            connect = connect +  " /user:#{station[2]} #{station[3]}"
        end
        system(connect) # připojit síťový disk

        puts("==== start archivace ====")
        system("#{path}programy/7z_x64/7za.exe u -r -up1q0r2x1y2z1w2 -y -bb #{backup_location}backup_#{station[0]}_#{year_week}.7z " +
               "#{station[4]} 1> #{log_location}log-#{station[0]}.txt 2> #{err_location}err-#{station[0]}.txt")  # vytvořit backup
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

error_logs = Dir.glob("#{err_location}err*.txt")
puts("#{err_location}err*" + error_logs.to_s)

error_logs.each { |log|
    unless File.zero?(log)
        error_logs2.append(log)
    end
}

File.open("#{path}errors.txt", "w") { |f|
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
system("#{path}programy/7z_x64/7za.exe a log.7z #{log_location}log*")

# odelsání mailu
system("#{path}programy/blat_x64/blat.exe #{path}errors.txt -ti 45 -to \"smaple@mail.com\" -subject \"backup scada 2\" -f backup_scada@noreply.com -server smtp.fosfa.cz -attach #{path}log.7z")
