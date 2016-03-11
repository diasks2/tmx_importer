require 'tmx_importer/version'
require 'xml'
require 'open-uri'

module TmxImporter
  class Tmx
    attr_reader :file_path, :encoding
    def initialize(file_path:, encoding:)
      @file_path = file_path
      @encoding = encoding.upcase
      @doc = {
        source_language: "",
        tu: { id: "", counter: 0, vals: "", lang: "" },
        seg: { lang: "", counter: 0, vals: "" },
        language_pairs: []
      }
      raise "Encoding type not supported. Please choose an encoding of UTF-8, UTF-16LE, or UTF-16BE" unless @encoding.eql?('UTF-8') || @encoding.eql?('UTF-16LE') || @encoding.eql?('UTF-16BE')
    end

    def stats
      reader = read_file
      parse_file(reader)
      {tu_count: @doc[:tu][:counter], seg_count: @doc[:seg][:counter], language_pairs: @doc[:language_pairs].uniq}
    end

    def import

    end

    private

    def read_file
      XML::Reader.io(open(file_path), options: XML::Parser::Options::NOERROR, encoding: set_encoding)
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
          tag_stack.pop if d.bytes.to_a == [35, 116, 101, 120, 116] || tag_stack.length > 3
        end
      end
      reader.close
    end

    def eval_state_initial(tag_stack, reader)
      case tag_stack.last.bytes.to_a
      when [104, 101, 97, 100, 101, 114]
        @doc[:source_language] = reader.get_attribute("srclang").force_encoding("UTF-8") if @doc[:source_language].empty? && reader.has_attributes? && reader.get_attribute("srclang")
      when [116, 117]
        @doc[:tu][:counter] += 1
      when [116, 117, 118]
        seg_lang = reader.get_attribute("lang") || reader.get_attribute("xml:lang")
        @doc[:seg][:lang] = seg_lang.force_encoding("UTF-8") unless seg_lang.empty?
      when [115, 101, 103]
        @doc[:seg][:counter] += 1
        if !@doc[:seg][:lang].empty? &&
           @doc[:seg][:lang] != @doc[:source_language] &&
           @doc[:seg][:lang].split('-')[0].downcase != @doc[:source_language].split('-')[0].downcase &&
           @doc[:source_language] != '*all*'
          @doc[:language_pairs] << [@doc[:source_language], @doc[:seg][:lang]]
        elsif @doc[:source_language] == '*all*'
          @doc[:source_language] = @doc[:seg][:lang]
        end
      end
    end
  end
end
