#!/usr/bin/ruby

require 'json'
require 'net/http'
require 'uri'

class Generator
  FIVE_MINUTES = 300

  attr_reader :current_page

  def initialize
    @current_page = 1
    @sentences ||= []
  end

  def cache
    JSON.parse(File.read(cache_file))
  end

  def cached?
    c = File.exist?(cache_file) && !(Time.at(File::ctime(cache_file)).to_i <= Time.now.to_i - FIVE_MINUTES)
    puts 'Cache hit!' if c
    c
  end

  def cache_file
    "#{Dir.pwd}/jokes_cache"
  end

  def populate_sentences
    uri = URI.parse("https://icanhazdadjoke.com/search?page=#{@current_page}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Accept'] = 'application/json'
    raw_response = http.request(request)
    puts "Getting jokes on page: #{current_page}"
    response = JSON.parse(raw_response.body)

    @sentences += response['results'].map { |result| result['joke'] }

    unless response['current_page'] == response['total_pages']
      @current_page = response['current_page'] + 1
      populate_sentences
    end
  end

  def sentences
    return cache if cached?
    puts 'Cache miss populating cache.'
    populate_sentences
    write_cache(@sentences)
    @sentences
  end

  def write_cache(content)
    File.open(cache_file, 'w') { |file| file.write(content.to_json) }
  end

  def self.sentences
    s = new
    s.sentences
  end
end

class Dictionary
  attr_reader :dictionary

  def initialize
    @dictionary = {}
    categorize
  end

  def add_word(current, next_word, type)
    @dictionary[type] ||= {}
    @dictionary[type][current] ||= []
    @dictionary[type][current] << next_word
  end

  def categorize
    sentences.each do |sentence|
      parts = sentence.split(/[.|?|,]/)
      leadups = parts[0]
      if leadups
        leadups= leadups.split
        leadups.each_with_index do |word, index|
          add_word(word, leadups[index + 1], :leadups)
        end
      end

      punchlines = parts[1]
      if punchlines
        punchlines = punchlines.split
        punchlines.each_with_index do |word, index|
          add_word(word, punchlines[index + 1], :punchlines)
        end
      end
    end
  end

  def generate_sentence
    sentence = []

    sentence << dictionary[:leadups].keys.sample.capitalize if sentence.empty?

    until dictionary[:leadups].key?(sentence.last) === false
      sentence << dictionary[:leadups][sentence.last].sample
    end

    sentence << dictionary[:punchlines].keys.sample

    until dictionary[:punchlines].key?(sentence.last) === false
      sentence << dictionary[:punchlines][sentence.last].sample
    end

    sentence.join(' ')
  end

  def sentences
    @sentences ||= Generator.sentences
  end

  def self.generate_sentence
    new.generate_sentence
  end
end

puts Dictionary.generate_sentence
