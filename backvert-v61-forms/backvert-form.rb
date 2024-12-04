require "json"

#####################################################################################
######                            Functions                                    ######
#####################################################################################

#Check if element is a section (Will contain sub-element sections) and recurse through
def recurseIntoElements (currentElement)
  currentElement['elements'].each do |element|
    if element['type'] == 'section'
      #if section, then recurse into section
      recurseIntoElements(element)
    end
    if $arrayOfStringToRemove.any? {|s| element.key?(s)}
      #If element contains any of the strings in the array to remove
      $arrayOfStringToRemove.each do |stringToRemove|
        begin
          element.delete(stringToRemove)
        rescue
          puts "ERROR REMOVING"
        end
      end
    end
  end
end

#Iterate files and append to global list

def retrieveFormFiles (baseurl)
  #If file, handle values and return (Single file option)
  if File.directory?(baseurl)
    if baseurl.end_with?('.json')
      $FileList.append(baseurl)
      return
    end
  end
  #Iterate each file in folder
  Dir.entries(baseurl).each do |file|
    #Skip directory stuff
    if file == '.' || file == '..'
      next
    end
    puts "File #{file}"
    newurl = (baseurl + '/' + file)
    if File.directory?(newurl)
      puts "Traversing into directory #{baseurl}/#{file}"
      #Recurse into folder
      retrieveFormFiles(newurl)
    else
      #If file AND Json- append to global files var - You could also call cleanup here
      if newurl.end_with?('.json')
        puts "Appending file to list #{newurl}"
        $FileList.append(newurl);
      end
    end
  end
end

#####################################################################################
######                            Main Code                                    ######
#####################################################################################

stringToRemove1 = "defaultDataSource"
stringToRemove2 = "choicesDataSource"
$arrayOfStringToRemove = [stringToRemove1, stringToRemove2]

puts 'Type full file/folder path(ex: C:/my files/file.json OR C:/my files/)'
fileOption = $stdin.gets.chomp
if fileOption[-1] == '/'
  #Remove trailing slash 
  fileOption = fileOption.chop
end
#Global array
$FileList = []

#Build file list
retrieveFormFiles(fileOption)

#Read file
preconvertedFile = File.read('C:\temp\pre-convert-test.json')
preconvertedHash = JSON.parse(preconvertedFile)

#Remove empty integrations section
begin
  preconvertedHash['form'].delete('integrations')
rescue

end

#Iterate through all pages in form
preconvertedHash['form']['pages'].each do |page|
  recurseIntoElements(page)
end

#Export to file

File.open('C:\temp\post-convert-test.json','w') do |f|
  f.write(preconvertedHash.to_json)
end