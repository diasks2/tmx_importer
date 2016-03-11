require 'spec_helper'

describe TmxImporter do
  it 'has a version number' do
    expect(TmxImporter::VERSION).not_to be nil
  end

  it 'raises an error if the encoding is not supported' do
    file_path = File.expand_path('../tmx_importer/spec/test_sample_files/test_tm(utf-8).tmx')
    -> { expect(TmxImporter::Tmx.new(file_path: file_path, encoding: 'ISO-8859-9').stats).to raise_error }
  end

  it 'raises an error if the file contains bad markup' do
    file_path = File.expand_path('../tmx_importer/spec/test_sample_files/bad_markup(utf-8).tmx')
    -> { expect(TmxImporter::Tmx.new(file_path: file_path, encoding: 'utf-8').stats).to raise_error }
  end

  it 'raises an error if the file contains bad markup 2' do
    file_path = File.expand_path('../tmx_importer/spec/test_sample_files/bad_markup(utf-16).tmx')
    -> { expect(TmxImporter::Tmx.new(file_path: file_path, encoding: 'utf-16le').stats).to raise_error }
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
      expect(tmx.stats).to eq({:tu_count=>4, :seg_count=>8, :language_pairs=>[["de", "en"]]})
    end

    it 'reports the stats of a UTF-16LE TMX file' do
      file_path = File.expand_path('../tmx_importer/spec/test_sample_files/test_tm(utf-16LE).tmx')
      tmx = TmxImporter::Tmx.new(file_path: file_path, encoding: 'utf-16le')
      expect(tmx.stats).to eq({:tu_count=>4, :seg_count=>8, :language_pairs=>[["de-DE", "en-US"]]})
    end

    it 'reports the stats of a multiple language pair TMX file' do
      file_path = File.expand_path('../tmx_importer/spec/test_sample_files/multiple_language_pairs.tmx')
      tmx = TmxImporter::Tmx.new(file_path: file_path, encoding: 'utf-8')
      expect(tmx.stats).to eq({:tu_count=>4, :seg_count=>10, :language_pairs=>[["de-DE", "en-US"], ["de-DE", "it"], ["de-DE", "fr"]]})
    end

    it 'reports the stats of a srclang equals *all* TMX file' do
      file_path = File.expand_path('../tmx_importer/spec/test_sample_files/srclang_all.tmx')
      tmx = TmxImporter::Tmx.new(file_path: file_path, encoding: 'utf-8')
      expect(tmx.stats).to eq({:tu_count=>4, :seg_count=>10, :language_pairs=>[["de-DE", "en-US"], ["de-DE", "it"], ["de-DE", "fr"]]})
    end
  end
end
