require "json"

#####################################################################################
######                            Functions                                    ######
#####################################################################################


########################################################################################
#Check if element is a section (Will contain sub-element sections) and recurse through #
########################################################################################
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

###################################################################
#            Iterate files and append to global list              #
###################################################################
def retrieveFormFiles (baseurl)
  #If file, handle values and return (Single file option)
  if !File.directory?(baseurl)
    puts "BaseURL is file"
    if baseurl.end_with?('.json')
      puts "Baseurl is JSON File"
      $FileList.append(baseurl)
      return
    end
  end
  $FolderList.append(baseurl);
  #Iterate each file in folder
  Dir.entries(baseurl).each do |file|
    #Skip directory stuff
    if file == '.' || file == '..'
      next
    end
    puts "File #{file}"
    newurl = File.join(baseurl,file)
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

###########################################################
# Create destination directories before re-creating files #
###########################################################

def createDestinationDirectory (startingUrl,newUrl)
  $FolderList.each do |folder| 
    destfolder = folder.sub(startingUrl,newUrl);
    puts "dest: #{destfolder}"
    Dir.mkdir(destfolder) unless Dir.exist?(destfolder);
  end unless $FolderList.empty?
end

#####################################################################################
######                            Main Code                                    ######
#####################################################################################

stringToRemove1 = "defaultDataSource"
stringToRemove2 = "choicesDataSource"
$arrayOfStringToRemove = [stringToRemove1, stringToRemove2, 'choicesResourceProperty']

puts 'Type full file/folder path(ex: C:/my files/file.json OR C:/my files)'
startingUrl = File.path($stdin.gets.chomp).gsub('"','')
if startingUrl[-1] == File::SEPARATOR #If trailing /
  #Remove trailing slash 
  startingUrl = startingUrl.chop
  baseUrl = File.dirname(startingUrl)
  filename = File.basename(startingUrl)
elsif File.file?(startingUrl) #If single file
  baseUrl = File.dirname(startingUrl)
  filename = File.basename(startingUrl)
else #All other cases - Typical
  baseUrl = startingUrl
end

puts "Type destination folder(ex: C:/results)"
destinationPath = File.path($stdin.gets.chomp)
destinationPath = File.path(destinationPath + '/') if destinationPath[-1] != '/'


#Global array
$FileList = []
$FolderList = []

#Build file list
puts "Building file list"
retrieveFormFiles(startingUrl)
puts "Converting files"
createDestinationDirectory(baseUrl,destinationPath)
#Read file
puts "Files #{$FileList}"

#Create base directory if it doesn't exist
#This may be handled in createDestinationDirectory - need to confirm and remove
Dir.mkdir(destinationPath) unless Dir.exist?(destinationPath)
$FileList.each do |file|
  puts file
  #Confirm directory of destination already exists - create if missing
  #directoryPath = File.dirname(File.path(file).gsub(startingUrl,destinationPath))
  fullFilePath = File.path(file).gsub(baseUrl, destinationPath)
  directoryPath = File.dirname(fullFilePath)
  puts "New file: #{fullFilePath}"
  #Dir.mkdir(directoryPath) unless Dir.exist?(directoryPath)
  preconvertedFile = File.read(file)

  #Iterate each item in configuration array - if array
  if JSON.parse(preconvertedFile).class == Array
    JSON.parse(preconvertedFile).each {|file_item|

      #If form, convert
      if file_item.has_key?('form')
        #Remove empty integrations section
        begin
          file_item['form'].delete('integrations')
        rescue
        end
        #Iterate through all pages in form
        file_item['form']['pages'].each do |page|
          recurseIntoElements(page)
        end
      end
    }
  else #If single item
    convertedHash = JSON.parse(preconvertedFile)
    if convertedHash.has_key?('form')
      #Remove empty integrations section
      begin
        convertedHash['form'].delete('integrations')
      rescue
      end
      #Iterate through all pages in form
      convertedHash['form']['pages'].each do |page|
        recurseIntoElements(page)
      end
    end
  end
  
  
  #Export to file
  File.open(fullFilePath,'w') do |f|
    f.write(convertedHash.to_json)
  end
end

