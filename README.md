# TMX Importer

[![Gem Version](https://badge.fury.io/rb/tmx_importer.svg)](https://badge.fury.io/rb/tmx_importer) [![Build Status](https://travis-ci.org/diasks2/tmx_importer.png)](https://travis-ci.org/diasks2/tmx_importer) [![License](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](https://github.com/diasks2/tmx_importer/blob/master/LICENSE.txt)

This gem handles the importing and parsing of [.tmx translation memory files](http://www.ttt.org/oscarstandards/tmx/tmx14-20020710.htm). [TMX files](https://en.wikipedia.org/wiki/Translation_Memory_eXchange) are xml files.

## Installation

Add this line to your application's Gemfile:

**Ruby**  
```
gem install tmx_importer
```

**Ruby on Rails**  
Add this line to your application’s Gemfile:  
```ruby 
gem 'tmx_importer'
```

## Usage

```ruby
# Get the high level stats of a TMX file
file_path = File.expand_path('../tmx_importer/spec/test_sample_files/test_tm(utf-8).tmx')
TmxImporter::Tmx.new(file_path: file_path, encoding: 'utf-8').stats
# => {:tu_count=>4, :seg_count=>8, :language_pairs=>[["de-DE", "en-US"]]}

# Extract the segments of a TMX file
# Result: [translation_units, segments]
# translation_units = [tu_id, creation_date]
# segments = [tu_id, segment_role, word_count, language, segment_text, creation_date]

file_path = File.expand_path('../tmx_importer/spec/test_sample_files/test_tm(utf-8).tmx')
TmxImporter::Tmx.new(file_path: file_path, encoding: 'utf-8').import
# => [[["3638-1457683912-1", "2016-03-11T17:11:52+09:00"], ["7214-1457683912-3", "2016-03-11T17:11:52+09:00"], ["1539-1457683912-5", "2016-03-11T17:11:52+09:00"], ["6894-1457683912-7", "2016-03-11T17:11:52+09:00"]], [["3638-1457683912-1", "", 1, "de-DE", "überprüfen", "2016-03-11T17:11:52+09:00"], ["3638-1457683912-1", "target", 1, "en-US", "check", "2016-03-11T17:11:52+09:00"], ["7214-1457683912-3", "source", 1, "de-DE", "Rückenlehneneinstellung", "2016-03-11T17:11:52+09:00"], ["7214-1457683912-3", "target", 2, "en-US", "Backrest adjustment", "2016-03-11T17:11:52+09:00"], ["1539-1457683912-5", "source", 1, "de-DE", "Bezüglich", "2016-03-11T17:11:52+09:00"], ["1539-1457683912-5", "target", 3, "en-US", "In terms of", "2016-03-11T17:11:52+09:00"], ["6894-1457683912-7", "source", 20, "de-DE", "Der Staatsschutz prüft, ob es einen Zusammenhang mit einem Anschlag auf eine geplante Flüchtlingsunterkunft in der Nachbarschaft Ende August gibt.", "2016-03-11T17:11:52+09:00"], ["6894-1457683912-7", "target", 23, "en-US", "The state protection checks whether there is a connection with an attack on a planned refugee camp in the neighborhood of late August.", "2016-03-11T17:11:52+09:00"]]]
```

## Contributing

1. Fork it ( https://github.com/diasks2/tmx_importer/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The MIT License (MIT)

Copyright (c) 2016 Kevin S. Dias

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
