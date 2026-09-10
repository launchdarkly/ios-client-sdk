source 'https://rubygems.org'

gem 'jazzy', '0.15.4'

# jazzy 0.15 accepts mustache ~> 1.1, but mustache 1.1.3 reworked `template_path=` to
# take a String or an Array, and jazzy passes it a Pathname. That raises
# "undefined method 'map' for an instance of Pathname" while jazzy parses its own
# configuration, before it reads any source. Hold mustache below 1.1.3 until jazzy
# accommodates the new signature.
gem 'mustache', '< 1.1.3'

# jazzy 0.15.4 (the latest release) builds its search index with
# `JSON.generate(..., quirks_mode: true)`, and json 3.0 removed the `quirks_mode`
# keyword, so a fresh bundle install crashes doc generation. jazzy's source has
# already dropped the call but it is unreleased. Hold json below 3.0 until a jazzy
# release includes the fix, then remove this.
gem 'json', '< 3.0'
