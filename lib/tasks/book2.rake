require 'zip'
require 'nokogiri'

desc "Generate the book html for the sites (by downloading from atlas)"
task :genbook2 => :environment do
  if ENV['GENLANG']
    books = Book.where(:edition => 2, :code => ENV['GENLANG'])
  else
    books = Book.where(:edition => 2, :processed => false)
  end

  nav = '<div id="nav"><a href="[[nav-prev]]">prev</a> | <a href="[[nav-next]]">next</a></div>'

  books.each do |book|
    html_file = download(book.ebook_html) # download processed html ebook
    Zip::File.open(html_file) do |zip_file|
      # Handle entries one by one
      max_chapter = 0

      # go through all the files and order them properly
      chapters = {}
      zip_file.glob("*.html").each do |entry|
        if m = /(app|ch)(.*?).html/.match(entry.name)
          chapter_type = m[1]
          chapter_number = m[2]
          if chapter_type == 'app'
            chapters["xapp#{chapter_number}"] = ['appendix', chapter_number.to_i, entry.name]
          else
            chapters["ch#{chapter_number}"] = ['chapter', chapter_number.to_i, entry.name]
          end
        end
      end

      # sort and create the numbers in order
      number = 0
      chapters.sort.each_with_index do |data, index|
        number = index + 1
        chapter_type, chapter_number, file = data[1]
        content = zip_file.find_entry(file).get_input_stream.read

        doc = Nokogiri::HTML(content)
        chapter = doc.at("section[@data-type=#{chapter_type}]")
        chapter_title = doc.at("section[@data-type=#{chapter_type}] > h1").text
        pretext = doc.at("section[@data-type=#{chapter_type}] > p").to_html

        schapter = book.chapters.where(:number => number).first_or_create
        schapter.title = chapter_title.to_s
        schapter.chapter_type = chapter_type
        schapter.chapter_number = chapter_number
        schapter.sha = book.ebook_html
        schapter.save

        schapter.sections.delete_all # clear out this chapter before rebuilding it

        section = 1
        chapter.search("section[@data-type=sect1]").each do |sec|
          section_title = sec.attribute('data-pdf-bookmark')
          html = pretext + sec.inner_html.to_s + nav

          html.gsub!('<h3', '<h4')
          html.gsub!(/\/h3>/, '/h4>')
          html.gsub!('<h2', '<h3')
          html.gsub!(/\/h2>/, '/h3>')
          html.gsub!('<h1', '<h2')
          html.gsub!(/\/h1>/, '/h2>')

          if subsec = html.scan(/<h3>(.*?)<\/h3>/)
            subsec.each do |sub|
              sub = sub.first
              id = sub.gsub(' ', '-')
              html.gsub!(/<h3>#{sub}<\/h3>/, "<h3 id=\"#{id}\"><a href=\"##{id}\">#{sub}</a></h3>") rescue nil
            end
          end

          puts "\t\t#{chapter_type} #{chapter_number}.#{section} : #{chapter_title} . #{section_title} - #{html.size}"

          csection = schapter.sections.where(:number => section).first_or_create
          csection.title = section_title.to_s
          csection.html = html
          csection.save

          section += 1
          pretext = ""
        end # loop through sections
        extra = schapter.sections.where("number >= #{section}")
        extra.delete_all
      end # if it's a chapter
      extra = book.chapters.where("number > #{number}")
      extra.delete_all
    end

    book.processed = true
    # book.save

    book.sections.each do |section|
      section.set_slug
      section.save
    end

  end
end


def self.download(url)
  puts "downloading #{url}"
  file = File.new("#{Rails.root}/tmp/download" + Time.now.to_i.to_s + Random.new.rand(100).to_s, 'wb')
  begin
    uri = URI.parse(url)
    Net::HTTP.start(uri.host,uri.port) do |http|
      http.request_get(uri.path) do |resp|
        resp.read_body do |segment|
          file.write(segment)
        end
      end
    end
    puts "Done."
  ensure
    file.close
  end
  file.path
end