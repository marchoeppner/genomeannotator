require 'json'

json = JSON.parse(IO.readlines("nextflow_schema.json").join("\n"))

categories = json["definitions"]

puts "# Genomeannotator command line options"
puts ""

categories.keys.each do |ck|

    c = categories[ck]
    
    puts "## #{ck} #{c['title']}"
    puts ""
    
    properties = c["properties"]
    
    properties.keys.each do |k|
    
            pr = properties[k]
            
            puts "### --#{k} [ #{pr['type']} ]"
            puts "#{pr['description']}"
            puts ""
            
    end

end
