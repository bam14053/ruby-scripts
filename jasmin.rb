require 'selenium-webdriver'

search = 'Metallbau'
/loop do
    puts "Nach welchem Begriff soll gesucht werden:"
    search = gets.chomp/
    #break if(!search.empty? && search.gsub(/\s+/, "").length > 0)
#end

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
        puts "Seite #{page}\nEs befinden sich #{customers.length} Kunden auf der Seite."
        puts "Firmenname\tStraße & Hausnummer\tPLZ\tOrt\tWebseite\tVorname und Nachname\tPosition\tTelefonnummer"
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
            company_name = ''
            street = ''
            plz = ''
            ort = ''
            website = ''
            name = ''
            position = ''
            telefon = ''

            begin
                company_name = e.text
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

                # Get all the required infos on wlw
                company_info = driver.find_element(class: 'business-card__address').text
                street = company_info.split(',')[0].strip
                plz = company_info.split(',')[1].scan(/(\d{2,})/)[0][0].strip
                ort = company_info.scan(/(\w+)\s?$/)[0][0].strip
                website = driver.find_element(class: 'website-button').attribute("website")
                driver.find_element(class: 'website-button__button').click

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
                if(element.text.downcase == 'impressum')
                    driver.navigate.to element.attribute("href") if(!element.attribute("href").nil?)
                    #now to the hard part
                    driver.find_elements(:tag_name,'p').each { |element|
                        #First we need the phone number
                        if(telefon == '' && element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/).length > 0) 
                            begin
                                telefon = element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/)[0][0].gsub(/\s+/, "")
                            rescue Array::NoMethodError
                                telefon = element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/)
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

                if(name == '' && position == '' && telefon == '')
                    driver.find_elements(:tag_name,'div').each { |element|
                        if(element.text.downcase == 'impressum')
                            driver.navigate.to element.attribute("href") if(!element.attribute("href").nil?)
                            #now to the hard part
                            driver.find_elements(:tag_name,'p').each { |element|
                                #First we need the phone number
                                if(telefon == '' && element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/).length > 0) 
                                    begin
                                        telefon = element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/)[0][0].gsub(/\s+/, "")
                                    rescue Array::NoMethodError
                                        telefon = element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/)
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

                if(name == '' && position == '' && telefon == '')
                    driver.find_elements(:tag_name,'a').each { |element|
                        if(element.text.downcase == 'kontakt')
                            driver.navigate.to element.attribute("href") if(!element.attribute("href").nil?)
                                #now to the hard part
                                driver.find_elements(:tag_name,'p').each { |element|
                                #First we need the phone number
                                if(telefon == '' && element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/).length > 0) 
                                    begin
                                        telefon = element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/)[0][0].gsub(/\s+/, "")
                                    rescue Array::NoMethodError
                                        telefon = element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/)
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

                if(name == '' && position == '' && telefon == '')
                    driver.find_elements(:tag_name,'div').each { |element|
                        if(element.text.downcase == 'kontakt')
                            driver.navigate.to element.attribute("href") if(!element.attribute("href").nil?)
                                #now to the hard part
                                driver.find_elements(:tag_name,'p').each { |element|
                                #First we need the phone number
                                if(telefon == '' && element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/).length > 0) 
                                    begin
                                        telefon = element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/)[0][0].gsub(/\s+/, "")
                                    rescue Array::NoMethodError
                                        telefon = element.text.downcase.scan(/telefon.?\n?\s*([+]?\d.*)/)
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
            rescue StandardError => e
                log_file.write "error: #{caller.join("\n")}\n"
            ensure
                puts "#{company_name}\t#{street}\t#{plz}\t#{ort}\t#{website}\t#{name}\t#{position}\t#{telefon}"
                #Log the things not fount into our log file
                log_file.write "\terror: Webseite wurde nicht gefunden\n" if website == ''
                log_file.write "\terror: Name vom Inhaber wurde nicht gefunden\n" if name == ''
                log_file.write "\terror: Telefon wurde nicht gefunden\n" if telefon == ''
                
                driver.window_handles.each do |handle|
                    if handle != original_window
                        driver.switch_to.window handle
                        driver.close
                    end
                end
                driver.switch_to.window original_window
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