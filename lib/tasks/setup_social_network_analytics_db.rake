desc "Load, Migrate, Seed the Social Networking Analytics database"

# References:
# [1] http://jasonseifer.com/2010/04/06/rake-tutorial

task :development_environment_only do
  # References:
  # [1] http://stackoverflow.com/questions/2715035/rails-env-vs-rails-env
  allowed_envs = %w(custom_development)

  is_valid_env = false
  env_name = nil
  allowed_envs.each do |env|
    if Rails.env.send("#{env}?")
      env_name = env
      is_valid_env = true
      break;
    end
  end

  raise "Hey, use this for #{allowed_envs.to_s} environments only!" unless is_valid_env
end

task :setup_analytics_database => [
    'environment',
    'development_environment_only',
    'db:schema:load',
    'db:migrate',
    'db:seed'
]
