require 'opsmgr/ui_helpers/config_helper'

RSpec.describe 'Configure Elastic Runtime 1.5.X Experimental Features', order: :defined do
  let(:current_ops_manager) { ops_manager_driver }
  let(:env_settings) { fetch_environment_settings }

  let(:elastic_runtime_settings) { env_settings.ops_manager.elastic_runtime }

  it 'logs in' do
    current_ops_manager.setup_page.setup_or_login(
      user: env_settings.ops_manager.username,
      password: env_settings.ops_manager.password,
    )
  end

  it 'enables all of the experimental features' do
    experimental_features_form =
      current_ops_manager.product(elastic_runtime_settings.name).product_form('experimental_features')
    experimental_features_form.open_form

    experimental_features_form.property('.ha_proxy.disable_http').set(true)
    experimental_features_form.property('.uaa.disable_http').set(true)

    experimental_features_form.save_form
  end
end
