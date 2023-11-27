require "test_helper"

class ConfigurationContainerBaseTest < ActiveSupport::TestCase
  class TestConfiguration < Kamal::Configuration::ContainerBase
    def initialize(name, config:)
      super(name, config: config, delegate_config: config.raw_config[name])
    end
  end

  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      env: { "REDIS_URL" => "redis://x/y" }
    }

    @config = TestConfiguration.new('some_container', config: Kamal::Configuration.new(@deploy))

    @deploy_with_container = @deploy.dup.merge({
      some_container: {
        "hosts" => [ "1.1.1.3", "1.1.1.4" ],
        "cmd" => "bin/jobs"
      }
    })

    @config_with_container = TestConfiguration.new('some_container', config: Kamal::Configuration.new(@deploy_with_container))
  end

  test "logging_args returns defaults" do
    assert_equal ["--log-opt", "max-size=\"10m\""], @config.logging_args
    assert_equal ["--log-opt", "max-size=\"10m\""], @config_with_container.logging_args
  end

  test "logging_args does not merge defaults" do
    @deploy_with_container[:some_container]["logging"] = { "driver" => "awslogs" }

    assert_equal ["--log-opt", "max-size=\"10m\""], @config.logging_args
    assert_equal ["--log-driver", "\"awslogs\""], @config_with_container.logging_args
  end

  test "logging_args merges root config" do
    @deploy[:logging] = { "driver" => "awslogs", "options" => { "awslogs-region": "eu-central-2" } }
    @deploy_with_container[:logging] = { "driver" => "awslogs", "options" => { "awslogs-region": "eu-central-2" } }
    @deploy_with_container[:some_container]["logging"] = { "options" => { "awslogs-group": "group-name" } }

    assert_equal ["--log-driver", "\"awslogs\"", "--log-opt", "awslogs-region=\"eu-central-2\""], @config.logging_args
    assert_equal ["--log-driver", "\"awslogs\"", "--log-opt", "awslogs-region=\"eu-central-2\"", "--log-opt", "awslogs-group=\"group-name\""], @config_with_container.logging_args
  end

  test "volume_args returns defaults" do
    assert_equal [], @config.volume_args
    assert_equal [], @config_with_container.volume_args
  end

  test "volume_args merges root config" do
    @deploy[:volumes] = ["/local/path:/container/path"]
    @deploy_with_container[:volumes] = ["/local/path:/container/path"]
    @deploy_with_container[:some_container]["volumes"] = ["/local/another_path:/container/another_path"]

    assert_equal ["--volume", "/local/path:/container/path"], @config.volume_args
    assert_equal ["--volume", "/local/path:/container/path", "--volume", "/local/another_path:/container/another_path"], @config_with_container.volume_args
  end

  test "conflicting types default to delegate" do
    @deploy[:volumes] = { "invalid" => "configuration" }
    @deploy_with_container[:some_container]["volumes"] = ["/local/path:/container/path"]

    assert_equal ["--volume", "invalid=\"configuration\""], @config.volume_args
    assert_equal ["--volume", "/local/path:/container/path"], @config_with_container.volume_args
  end
end
