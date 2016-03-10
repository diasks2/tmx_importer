require 'spec_helper'

describe TmxImporter do
  it 'has a version number' do
    expect(TmxImporter::VERSION).not_to be nil
  end

  it 'raises an error if the encoding is not supported' do
    -> { expect(TmxImporter::Tmx.new(file_path: file_path, encoding: 'ISO-8859-9').stats).to raise_error }
  end

  describe '#stats' do

    it 'reports the stats of a UTF-8 TMX file' do
      file_path = File.expand_path('../tmx_importer/spec/test_sample_files/test_tm(utf-8).tmx')
      tmx = TmxImporter::Tmx.new(file_path: file_path, encoding: 'utf-8')
      expect(tmx.stats).to eq({:tu_count=>4, :seg_count=>8, :language_pairs=>[["de-DE", "en-US"]]})
    end

    it 'reports the stats of a UTF-8 TMX file 2' do
      file_path = File.expand_path('../tmx_importer/spec/test_sample_files/test_tm_2(utf-8).tmx')
      tmx = TmxImporter::Tmx.new(file_path: file_path, encoding: 'utf-8')
      expect(tmx.stats).to eq({:tu_count=>4, :seg_count=>8, :language_pairs=>[["de-DE", "en-US"]]})
    end

    it 'reports the stats of a UTF-16LE TMX file' do
      file_path = File.expand_path('../tmx_importer/spec/test_sample_files/test_tm(utf-16LE).tmx')
      tmx = TmxImporter::Tmx.new(file_path: file_path, encoding: 'utf-16le')
      expect(tmx.stats).to eq({:tu_count=>4, :seg_count=>8, :language_pairs=>[["de-DE", "en-US"]]})
    end
  end
end
