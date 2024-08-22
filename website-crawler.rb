require 'selenium-webdriver'
require "google_drive"

#First we start with the Google Spreadsheet file
session = GoogleDrive::Session.from_config("config.json")
file = nil
puts "Bitte wähle die Akquiseliste Datei aus, die das Skript nutzen soll"
instruction = "Die Folgenden Befehle sind verfügbar:\n\tls - Alle Datein im Verzeichnis anzeigen\n\tcd {Verzechnisnamen} - Das angegebene Verzeichnis betreten\n\tsel[ect] {Dateinamen} - Wählt die angegebene Datei zum verarbeiten aus\n\t?/help - Zeigt dir die Lister der verfügbaren Befehle"
puts instruction

# We get the file and the move on to the website
while file == nil
    command = gets.chomp
    if command.length > 0
        case command.split(' ')[0]
        when 'ls'
            session.spreadsheets.each do |file|
                p file.title
            end
            if(session.is_a?(GoogleDrive::Session))
                session.collections.each do |folder|
                    puts "<DIR>      #{folder.title}"
                end
            else
                session.subcollections.each do |folder|
                    puts "<DIR>     #{folder.title}"
                end
            end
        when 'cd'
            begin
                if !command.split(' ',2)[1].nil? && !session.collection_by_title(command.split(' ',2)[1]).nil?
                    session = session.collection_by_title(command.split(' ',2)[1])
                    session.files.each do |file|
                        p file.title
                    end
                else
                    puts "Das Verzeichnis wurde nicht gefunden!"
                end
            rescue StandardError => e
                puts "Der Befehl ist ungültig!"
            end
        when 'sel','sele','selec','select'
            begin
                if !command.split(' ',2)[1].nil?
                    if !session.file_by_title(command.split(' ',2)[1]).nil?
                        file = session.file_by_title(command.split(' ',2)[1])
                    else
                        num_of_files = 0
                        session.spreadsheets.each do |file|
                            num_of_files += 1 if file.title.start_with?(command.split(' ',2)[1])
                        end
                        case num_of_files
                        when 0
                            puts "Die Datei existiert nicht!"
                        when 1
                            session.spreadsheets.each do |f|
                                file = f if f.title.start_with?(command.split(' ',2)[1])
                            end
                        else
                            session.spreadsheets.each do |file|
                                puts file.title if file.title.start_with?(command.split(' ',2)[1])
                            end
                        end
                    end
                elsif command.split(' ',2)[1].nil?
                    puts "Die Datei wurde nicht gefunden."
                end
            rescue StandardError => e
                puts "Der Befehl ist ungültig!"
            end
        when '?','help','h'
            puts instruction
        else
            puts "Der Befehl ist ungültig."
        end
    else
        puts instruction
    end
end

#We have our google spreasheet file ready and now we have to find out where the row with the 'ID' starts
file = file.worksheets.first
row = 1
while file["A"+row.to_s] != 'ID'
    row += 1
end

#Now we have to scroll to the end of the table to start adding data there
row_end = row
space = 0
while (space < 10)
    if file["B"+row_end.to_s].length > 0 then space = 0 else space += 1 end
    row_end += 1
end

#In order not to add anything twice, we will save all websites and company names in a list and check whether the company is already noted down before adding
company_list = []
website_list = []
row += 1
while (row < row_end)
    if (file["B"+row.to_s].length > 0)
        company_list << file["B"+row.to_s]
        website_list << file["F"+row.to_s]
    end
    row += 1
end

row_end -= 10

#Now we ask the user what he wants to search for
search = ''
loop do
    puts "Nach welchem Begriff soll gesucht werden:"
    search = gets.chomp
    break if(!search.empty? && search.gsub(/\s+/, "").length > 0)
end

#Open log file for errors
log_file = File.open("log.txt", "w")
log_file.write "info: Script wurde gestartet, Suchbegriff ist #{search}\n"

#Open the webbrowser
wait = Selenium::WebDriver::Wait.new(:timeout => 10)
driver = Selenium::WebDriver.for :chrome

begin
    driver.navigate.to 'https://www.wlw.de/'
    driver.find_element(name: 'q').send_keys search, :return
    
    #wait for the browser
    wait.until {!driver.find_element(class: 'filter-item').text.empty?}
    
    #Get rid of cookies notification and wait until the notification disappears
    if(driver.find_element(id: 'CybotCookiebotDialogBodyContentText').displayed?)
        driver.find_element(id: 'CybotCookiebotDialogFooterButtonAcceptAll').find_element(name: 'button').click 
        wait.until {!driver.find_element(id: 'CybotCookiebotDialogBodyContentText').displayed?}
    end
    
    #Lieferantentyp Eingeben
    driver.find_elements(class: 'filter-item').each { |item|
        if(item.find_element(class: 'filter-item-content').text == 'Lieferantentyp')
            item.click
            wait.until {driver.find_element(class: 'filter-body').displayed?}
            driver.find_element(class: 'filter-body').find_elements(class: 'item').each{|element|
                element.click if(element.text.include?('Hersteller'))
            }
            driver.find_element(class: 'bottom-navi').find_element(class: 'apply-button').click
            break
        end
    }

    #wait for the browser
    wait.until {driver.find_element(class: 'company-tile').displayed?}

    #Get rid of cookies notification and wait until the notification disappears
    if(driver.find_element(id: 'CybotCookiebotDialogBodyContentText').displayed?)
        driver.find_element(id: 'CybotCookiebotDialogFooterButtonAcceptAll').find_element(name: 'button').click 
        wait.until {!driver.find_element(id: 'CybotCookiebotDialogBodyContentText').displayed?}
    end

    page = 0
    while driver.find_element(class: 'pagination').find_element(class: 'next').displayed?
        page += 1
        customers = []
        driver.find_elements(class: 'company-tile').each {|element|
            customers << element.find_element(class: 'company-title-link') if(element.find_element(class: 'address').text.start_with?("DE-"))
        }
        /
            Wir brauchen: 
            Firmenname	
            Straße & Hausnummer	
            PLZ	
            Ort	
            Webseite	
            Vorname	
            Nachname	
            Position
            Telefonnummer/
        
        customers.each { |e|            
            # Store the ID of the original window and second tab
            original_window = driver.window_handle
            second_tab = 0 

            #Get all the infos, we need from the clients website
            company_name = e.text
            street = ''
            plz = ''
            ort = ''
            website = ''
            name = ''
            position = ''
            telefon = ''
            if(!company_list.include? company_name)
                begin
                    #Website of company in wlw
                    href = e.attribute("href")
        
                    #Write to logfile which customer is being processed for error handling
                    log_file.write "info: Firma #{company_name} wird gerade verarbeitet.\n"
                    
                    # Open a new tab and switch the windows handler to it, but important save the handler ID for later
                    driver.execute_script("window.open()")
                    wait.until { driver.window_handles.length == 2 }
                    
                    #Loop through until we find a new window handle
                    driver.window_handles.each do |handle|
                        if handle != original_window
                            driver.switch_to.window handle
                            second_tab = handle
                            break
                        end
                    end

                    #Navigate company's website on wlw
                    driver.navigate.to href

                    #In case the company name isn't registered
                    company_name = driver.find_element(class: 'flex-1').find_element(class: 'company-name').text if company_name == ''
                    puts company_name

                    # Get all the required infos on wlw
                    company_info = driver.find_element(class: 'text-lg').text
                    street = company_info.split(',')[0].strip
                    plz = company_info.split(',')[1].scan(/(\d{2,})/)[0][0].strip
                    ort = company_info.split.last.strip

                    website = driver.find_element(class: 'website-button').find_element(tag_name: 'span').text
                    puts website
                    if !website_list.include? website
                        driver.navigate.to driver.find_element(class: 'website-button').attribute("href")

                        #Log the websites address for error handlng
                        log_file.write "\tinfo: Link zur Webseite: #{website}.\n"

                        # Wait for the new window or tab
                        wait.until { driver.window_handles.length == 3 }

                        #Loop through until we find the new tab handler
                        driver.window_handles.each do |handle|
                            if handle != original_window && handle != second_tab
                                driver.switch_to.window handle
                                break
                            end
                        end

                        #The search is divided in two sections, first I search for 'a' links. Then I search for divs if nothing is found
                        #search for the impressum first, then search for contacts
                        driver.find_elements(:tag_name,'a').each { |element|
                            if element.text.downcase.include? 'impressum'
                                if(!element.attribute("href").nil?)
                                    driver.navigate.to element.attribute("href")
                                else
                                    driver.navigate.to website+"/impressum"
                                end
                                #now to the hard part
                                driver.find_elements(:tag_name,'div').each { |element|
                                    #First we need the phone number
                                    if(telefon == '' && element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/).length > 0) 
                                        begin
                                            telefon = element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/)[0][0].gsub(/\s+/, "")
                                        rescue Array::NoMethodError
                                            telefon = element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/)
                                        end
                                    end
                                    #Then the Geschaäftsführer or Inhaber
                                    if(name == '' && element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/).length == 1)
                                        position = 'Geschäfts' + element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/)[0][0]
                                        name = element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/)[0][1]
                                    end
                                }
                                break
                            end
                        }    

                        if(name == '' || position == '' || telefon == '')
                            driver.find_elements(:tag_name,'div').each { |element|
                                if element.text.downcase.include? 'impressum'
                                    if(!element.attribute("href").nil?)
                                        driver.navigate.to element.attribute("href")
                                    else
                                        driver.navigate.to website+"/impressum"
                                    end
                                    #now to the hard part
                                    driver.find_elements(:tag_name,'div').each { |element|
                                        #First we need the phone number
                                        if(telefon == '' && element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/).length > 0) 
                                            begin
                                                telefon = element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/)[0][0].gsub(/\s+/, "")
                                            rescue Array::NoMethodError
                                                telefon = element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/)
                                            end
                                        end
                                        #Then the Geschaäftsführer or Inhaber
                                        if(name == '' && element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/).length == 1)
                                            position = 'Geschäfts' + element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/)[0][0]
                                            name = element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/)[0][1]
                                        end
                                    }
                                    break
                                end
                            }
                        end

                        if(name == '' || position == '' || telefon == '')
                            driver.find_elements(:tag_name,'a').each { |element|
                                if element.text.downcase.include? 'kontakt'
                                    if(!element.attribute("href").nil?)
                                        driver.navigate.to element.attribute("href")
                                    else
                                        driver.navigate.to website+"/kontakt"
                                    end
                                    #now to the hard part
                                    driver.find_elements(:tag_name,'div').each { |element|
                                    #First we need the phone number
                                    if(telefon == '' && element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/).length > 0) 
                                        begin
                                            telefon = element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/)[0][0].gsub(/\s+/, "")
                                        rescue Array::NoMethodError
                                            telefon = element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/)
                                        end
                                    end
                                    #Then the Geschaäftsführer or Inhaber
                                    if(name == '' && element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/).length == 1)
                                        position = 'Geschäfts' + element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/)[0][0]
                                        name = element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/)[0][1]
                                    end
                                }
                                    break
                                end
                            }
                        end

                        if(name == '' || position == '' || telefon == '')
                            driver.find_elements(:tag_name,'div').each { |element|
                                if element.text.downcase.include? 'kontakt'
                                    if(!element.attribute("href").nil?)
                                        driver.navigate.to element.attribute("href")
                                    else
                                        driver.navigate.to website+"/kontakt"
                                    end
                                    #now to the hard part
                                    driver.find_elements(:tag_name,'div').each { |element|
                                    #First we need the phone number
                                    if(telefon == '' && element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/).length > 0) 
                                        begin
                                            telefon = element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/)[0][0].gsub(/\s+/, "")
                                        rescue Array::NoMethodError
                                            telefon = element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/)
                                        end
                                    end
                                    #Then the Geschaäftsführer or Inhaber
                                    if(name == '' && element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/).length == 1)
                                        position = 'Geschäfts' + element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/)[0][0]
                                        name = element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/)[0][1]
                                    end
                                }
                                break
                            end
                            }
                        end

                        if(name == '' || position == '' || telefon == '')
                            driver.navigate.to website
                            element = driver.find_element(:tag_name,'body')
                            #First we need the phone number
                            if(telefon == '' && element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/).length > 0) 
                                begin
                                    telefon = element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/)[0][0].gsub(/\s+/, "")
                                rescue Array::NoMethodError
                                    telefon = element.text.downcase.scan(/(?:tel|telefon).?\n?\s*([+]?\d.*)/)
                                end
                            end

                            #Then the Geschaäftsführer or Inhaber
                            if(name == '' && element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/).length == 1)
                                position = 'Geschäfts' + element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/)[0][0]
                                name = element.text.downcase.scan(/(führer|inhaber)\S*\s*\n?(\w.+)/)[0][1]
                            end
                        end
                    end
                rescue StandardError => e
                    log_file.write "error: #{e}\n"
                ensure
                    if !website_list.include? website
                        #Write to file
                        file["B"+row_end.to_s] = company_name
                        file["C"+row_end.to_s] = street
                        file["D"+row_end.to_s] = plz
                        file["E"+row_end.to_s] = ort
                        file["F"+row_end.to_s] = website
                        file["G"+row_end.to_s] = name
                        file["I"+row_end.to_s] = position
                        file["J"+row_end.to_s] = telefon

                        #Save changes to the spreadsheet
                        file.save if row_end%10 == 0 
                        
                        #Increase the row
                        row_end += 1

                        #Log the things not fount into our log file
                        log_file.write "\terror-2: Webseite wurde nicht gefunden\n" if website == ''
                        log_file.write "\terror: Name vom Inhaber wurde nicht gefunden\n" if name == ''
                        log_file.write "\terror: Telefon wurde nicht gefunden\n" if telefon == ''
                    end

                    driver.window_handles.each do |handle|
                        if handle != original_window
                            driver.switch_to.window handle
                            driver.close
                        end
                    end
                    driver.switch_to.window original_window
                end
            end
        }
        driver.navigate.to driver.find_element(class: 'pagination').find_element(class: 'next').attribute('href')
        wait.until {driver.find_element(class: 'pagination').displayed?}
    end
rescue Selenium::WebDriver::Error::NoSuchElementError => e
    log_file.write "info: Es wurde insgesamt #{page} Seiten verarbeitet\n"
ensure
    log_file.close
    driver.quit
end
