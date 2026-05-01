source "https://rubygems.org"

# Match the Ruby version GitHub Pages currently builds with. If you upgrade,
# verify the site still builds on the GitHub Pages action runner.
ruby ">= 3.1"

# Use Jekyll directly (rather than the github-pages gem) so we can control
# plugin versions explicitly. Switch to the github-pages gem if you want
# strict GitHub Pages compatibility.
gem "jekyll", "~> 4.3"

group :jekyll_plugins do
  gem "jekyll-seo-tag",       "~> 2.8"
  gem "jekyll-sitemap",       "~> 1.4"
  gem "jekyll-redirect-from", "~> 0.16"
end

# Windows and JRuby do not include zoneinfo files, so bundle the tzinfo-data gem.
platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end

# Performance booster for watching directories on Windows.
gem "wdm", "~> 0.1.1", :platforms => [:mingw, :x64_mingw, :mswin]

# Lock http_parser.rb on JRuby builds.
gem "http_parser.rb", "~> 0.6.0", :platforms => [:jruby]
