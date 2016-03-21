require 'tmx_importer/version'
require 'xml'
require 'open-uri'
require 'pretty_strings'
require 'charlock_holmes'
require 'nokogiri'

module TmxImporter
  class Tmx
    attr_reader :file_path, :encoding
    def initialize(file_path:, **args)
      @file_path = file_path
      @content = File.read(open(@file_path)) if !args[:encoding].eql?('UTF-8')
      if args[:encoding].nil?
        @encoding = CharlockHolmes::EncodingDetector.detect(@content[0..100_000])[:encoding]
        if @encoding.nil?
          encoding_in_file = @content.dup.force_encoding('utf-8').scrub!("*").gsub!(/\0/, '').scan(/(?<=encoding=").*(?=")/)[0].upcase
          if encoding_in_file.eql?('UTF-8')
            @encoding = ('UTF-8')
          elsif encoding_in_file.eql?('UTF-16')
            @encoding = ('UTF-16LE')
          end
        end
      else
        @encoding = args[:encoding].upcase
      end
      @doc = {
        source_language: "",
        tu: { id: "", counter: 0, vals: [], lang: "", creation_date: "" },
        seg: { lang: "", counter: 0, vals: [], role: "" },
        language_pairs: []
      }
      raise "Encoding type could not be determined. Please set an encoding of UTF-8, UTF-16LE, or UTF-16BE" if @encoding.nil?
      raise "Encoding type not supported. Please choose an encoding of UTF-8, UTF-16LE, or UTF-16BE" unless @encoding.eql?('UTF-8') || @encoding.eql?('UTF-16LE') || @encoding.eql?('UTF-16BE')
      @text = CharlockHolmes::Converter.convert(@content, @encoding, 'UTF-8') if !@encoding.eql?('UTF-8')
    end

    def stats
      if encoding.eql?('UTF-8')
        analyze_stats_utf_8
      else
        analyze_stats_utf_16
      end
      {tu_count: @doc[:tu][:counter], seg_count: @doc[:seg][:counter], language_pairs: @doc[:language_pairs].uniq}
    end

    def import
      if encoding.eql?('UTF-8')
        reader = read_file
        parse_file(reader)
      else
        import_utf_16
      end
      [@doc[:tu][:vals], @doc[:seg][:vals]]
    end

    private

    def import_utf_16
      doc = Nokogiri::XML(@text.gsub(/(?<=encoding=").*(?=")/, 'utf-8')) do |config|
        config.options = Nokogiri::XML::ParseOptions::NOERROR
      end
      @doc[:source_language] = doc.css("header").attr("srclang").to_s
      doc.css("tu").each_with_index do |tu, index|
        create_nokogiri_tu(tu)
        tu.css("tuv").each_with_index do |tuv, i|
          determine_segment_role(tuv, i)
          write_seg_nokogiri(tuv.css("seg").text)
        end
      end
    end

    def analyze_stats_utf_8
      File.readlines(@file_path).each do |line|
        analyze_line(line)
      end
    end

    def analyze_stats_utf_16
      @text.each_line do |line|
        analyze_line(line)
      end
    end

    def create_nokogiri_tu(tu)
      generate_unique_id
      @doc[:tu][:creation_date] = tu.attr("creationdate").nil? ? DateTime.now.to_s : DateTime.parse(tu.attr("creationdate").to_s).to_s
      @doc[:tu][:vals] << [@doc[:tu][:id], @doc[:tu][:creation_date]]
    end

    def determine_segment_role(tuv, i)
      if tuv.attr("xml:lang").to_s.nil? || tuv.attr("xml:lang").to_s.empty?
        @doc[:seg][:lang] = tuv.attr("lang").to_s
      else
        @doc[:seg][:lang] = tuv.attr("xml:lang").to_s
      end
      if @doc[:seg][:lang].nil? || @doc[:seg][:lang].empty?
        if i.eql?(0)
          @doc[:seg][:role] = 'source'
        else
          @doc[:seg][:role] = 'target'
        end
      else
        if @doc[:seg][:lang] != @doc[:source_language] &&
           @doc[:seg][:lang].split('-')[0].downcase != @doc[:source_language].split('-')[0].downcase &&
           @doc[:source_language] != '*all*'
          @doc[:seg][:role] = 'source'
        elsif @doc[:source_language] == '*all*'
          if i.eql?(0)
            @doc[:seg][:role] = 'source'
          else
            @doc[:seg][:role] = 'target'
          end
        else
          @doc[:seg][:role] = 'target'
        end
      end
    end

    def read_file
      if encoding.eql?('UTF-8')
        XML::Reader.io(open(file_path), options: XML::Parser::Options::NOERROR, encoding: XML::Encoding::UTF_8)
      else
        reader = @text.gsub(/(?<=encoding=").*(?=")/, 'utf-8').gsub(/&#x[0-1]?[0-9a-fA-F];/, ' ').gsub(/[\0-\x1f\x7f\u2028]/, ' ')
        XML::Reader.string(reader, options: XML::Parser::Options::NOERROR, encoding: XML::Encoding::UTF_8)
      end
    end

    def analyze_line(line)
      @doc[:source_language] = line.scan(/(?<=srclang=\S)\S+(?=")/)[0] if line.include?('srclang=') && !line.scan(/(?<=srclang=\S)\S+(?=")/).empty?
      @doc[:source_language] = line.scan(/(?<=srclang=\S)\S+(?=')/)[0] if line.include?('srclang=') && !line.scan(/(?<=srclang=\S)\S+(?=')/).empty?
      @doc[:tu][:counter] += line.scan(/<\/tu>/).count
      @doc[:seg][:counter] += line.scan(/<\/seg>/).count
      if line.include?('lang')
        @doc[:seg][:lang] = line.scan(/(?<=[^cn]lang=\S)\S+(?=")/)[0] if !line.scan(/(?<=[^cn]lang=\S)\S+(?=")/).empty?
        @doc[:seg][:lang] = line.scan(/(?<=[^cn]lang=\S)\S+(?=')/)[0] if !line.scan(/(?<=[^cn]lang=\S)\S+(?=')/).empty?
        @doc[:seg][:lang] = @doc[:seg][:lang] unless @doc[:seg][:lang].nil?
        write_language_pair
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
        @doc[:source_language] = reader.get_attribute("srclang") if @doc[:source_language].empty? && reader.has_attributes? && reader.get_attribute("srclang")
      when [116, 117]
        write_tu(reader)
        @doc[:tu][:counter] += 1
      when [116, 117, 118]
        seg_lang = reader.get_attribute("lang") || reader.get_attribute("xml:lang")
        @doc[:seg][:lang] = seg_lang unless seg_lang.empty?
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
      @doc[:tu][:creation_date] = reader.get_attribute("creationdate").nil? ? DateTime.now.to_s : DateTime.parse(reader.get_attribute("creationdate")).to_s
      @doc[:tu][:vals] << [@doc[:tu][:id], @doc[:tu][:creation_date]]
    end

    def write_seg(reader)
      return if reader.read_string.nil?
      text = PrettyStrings::Cleaner.new(reader.read_string).pretty.gsub("\\","&#92;").gsub("'",%q(\\\'))
      word_count = text.gsub("\s+", ' ').split(' ').length
      @doc[:seg][:vals] << [@doc[:tu][:id], @doc[:seg][:role], word_count, @doc[:seg][:lang], text, @doc[:tu][:creation_date]]
    end

    def write_seg_nokogiri(segment_text)
      return if segment_text.nil? || segment_text.empty?
      text = PrettyStrings::Cleaner.new(segment_text).pretty.gsub("\\","&#92;").gsub("'",%q(\\\'))
      word_count = text.gsub("\s+", ' ').split(' ').length
      @doc[:seg][:vals] << [@doc[:tu][:id], @doc[:seg][:role], word_count, @doc[:seg][:lang], text, @doc[:tu][:creation_date]]
    end

    def generate_unique_id
      @doc[:tu][:id] = [(1..4).map{rand(10)}.join(''), Time.now.to_i, @doc[:tu][:counter] += 1 ].join("-")
    end
  end
end
