require 'date'
require 'fileutils'

class Media
  def self.save(path, name, date)
    ymd_structure = DateTime.now.strftime('%Y/%m/%d')
    dir_structure = File.join(path, 'content/images', ymd_structure)
    FileUtils.mkpath(dir_structure) unless File.exist?(dir_structure)
    file_path = File.join(dir_structure, name)

    File.open(file_path, 'w') do |file|
      file.write(date)
    end

    '/images/' + ymd_structure + '/' + name
  end
end
