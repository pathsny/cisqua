root = File.expand_path('../', __dir__)
exec("cd #{root} && HOME=#{File.join(root,
                                     'bundler_home')} bundle exec ruby #{File.expand_path('script/post_process.rb',
                                                                                          root)} #{ARGV.join(' ')}")
