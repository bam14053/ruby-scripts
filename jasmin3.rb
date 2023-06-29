

company_info = ' Rudolf-Diesel-Strasse 13, DE-33428 Harsewinkel '
            street = company_info.split(',')[0].strip
            plz = company_info.split(',')[1].scan(/(\d{2,})/)[0][0].strip
            ort = company_info.scan(/(\w+)\s?$/)[0][0].strip

            puts street
            puts plz
            puts ort