require 'tmx_importer/version'
require 'xml'
require 'open-uri'
require 'pretty_strings'

Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

module TmxImporter
  class Tmx
    attr_reader :file_path, :encoding
    def initialize(file_path:, encoding:)
      @file_path = file_path
      @encoding = encoding.upcase
      @doc = {
        source_language: "",
        tu: { id: "", counter: 0, vals: [], lang: "", creation_date: "" },
        seg: { lang: "", counter: 0, vals: [], role: "" },
        language_pairs: []
      }
      raise "Encoding type not supported. Please choose an encoding of UTF-8, UTF-16LE, or UTF-16BE" unless @encoding.eql?('UTF-8') || @encoding.eql?('UTF-16LE') || @encoding.eql?('UTF-16BE')
    end

    def stats
      File.open(@file_path, "rb:#{encoding}") do |file|
        file.each do |line|
          analyze_line(line)
        end
      end
      {tu_count: @doc[:tu][:counter], seg_count: @doc[:seg][:counter], language_pairs: @doc[:language_pairs].uniq}
    end

    def import
      reader = read_file
      parse_file(reader)
      [@doc[:tu][:vals], @doc[:seg][:vals]]
    end

    private

    def read_file
      XML::Reader.io(open(file_path), options: XML::Parser::Options::NOERROR, encoding: set_encoding)
    end

    def analyze_line(line)
      @doc[:source_language] = line.scan(/(?<=srclang=\S)\S+(?=")|(?=')/)[0] if line.include?('srclang=')
      @doc[:tu][:counter] += line.scan(/<\/tu>/).count
      @doc[:seg][:counter] += line.scan(/<\/seg>/).count
      if line.include?('lang')
        @doc[:seg][:lang] = line.scan(/(?<=[^cn]lang=\S)\S+(?=")|(?=')/)[0]
        write_language_pair
      end
    end

    def set_encoding
      case encoding
      when 'UTF-8'
        xml_encoding = XML::Encoding::UTF_8
      when 'UTF-16LE'
        xml_encoding = XML::Encoding::UTF_16LE
      when 'UTF-16BE'
        xml_encoding = XML::Encoding::UTF_16BE
      end
    end

    def parse_file(reader)
      tag_stack = []
      generate_unique_id
      while reader.read do
        tag_stack.delete_if { |d| d.bytes.to_a == [101, 112, 116] ||
                                  d.bytes.to_a == [98, 112, 116] ||
                                  d.bytes.to_a == [112, 114, 111, 112] ||
                                  d.bytes.to_a == [112, 104] }
        if !tag_stack.include?(reader.name)
          tag_stack.push(reader.name)
          eval_state_initial(tag_stack, reader)
        elsif tag_stack.last == reader.name
          d = tag_stack.dup.pop
          tag_stack.pop if d.bytes.to_a == [35, 116, 101, 120, 116]
          generate_unique_id if tag_stack.length > 3 && tag_stack.pop.bytes.to_a == [116, 117]
        end
      end
      reader.close
    end

    def eval_state_initial(tag_stack, reader)
      case tag_stack.last.bytes.to_a
      when [104, 101, 97, 100, 101, 114]
        @doc[:source_language] = reader.get_attribute("srclang").force_encoding("UTF-8") if @doc[:source_language].empty? && reader.has_attributes? && reader.get_attribute("srclang")
      when [116, 117]
        write_tu(reader)
        @doc[:tu][:counter] += 1
      when [116, 117, 118]
        seg_lang = reader.get_attribute("lang") || reader.get_attribute("xml:lang")
        @doc[:seg][:lang] = seg_lang.force_encoding("UTF-8") unless seg_lang.empty?
      when [115, 101, 103]
        write_seg(reader)
        write_language_pair
        @doc[:seg][:counter] += 1
      end
    end

    def write_language_pair
      return if @doc[:seg][:lang].nil? || @doc[:seg][:lang].empty? || @doc[:source_language].nil? || @doc[:source_language].empty?
      if @doc[:seg][:lang] != @doc[:source_language] &&
         @doc[:seg][:lang].split('-')[0].downcase != @doc[:source_language].split('-')[0].downcase &&
         @doc[:source_language] != '*all*'
        @doc[:language_pairs] << [@doc[:source_language], @doc[:seg][:lang]]
        @doc[:seg][:role] = 'source'
      elsif @doc[:source_language] == '*all*'
        @doc[:source_language] = @doc[:seg][:lang]
        @doc[:seg][:role] = 'source'
      else
        @doc[:seg][:role] = 'target'
      end
    end

    def write_tu(reader)
      @doc[:tu][:lang] = reader.get_attribute("srclang")
      @doc[:tu][:creation_date] = reader.get_attribute("creationdate").nil? ? DateTime.now.to_s : DateTime.parse(reader.get_attribute("creationdate")).to_s
      @doc[:tu][:vals] << [@doc[:tu][:id], @doc[:tu][:creation_date]]
    end

    def write_seg(reader)
      return if reader.read_string.nil?
      text = PrettyStrings::Cleaner.new(reader.read_string.force_encoding('UTF-8')).pretty.gsub("\\","&#92;").gsub("'",%q(\\\'))
      word_count = text.gsub("\s+", ' ').split(' ').length
      @doc[:seg][:vals] << [@doc[:tu][:id], @doc[:seg][:role], word_count, @doc[:seg][:lang], text, @doc[:tu][:creation_date]]
    end

    def generate_unique_id
      @doc[:tu][:id] = [(1..4).map{rand(10)}.join(''), Time.now.to_i, @doc[:tu][:counter] += 1 ].join("-")
    end
  end
end
