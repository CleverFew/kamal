require "active_support/core_ext/hash/deep_merge"

class Kamal::Configuration::ContainerBase
  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_accessor :name

  def initialize(name, config:)
    @name, @config = name.inquiry, config
    @delegate_config ||= config.raw_config[name]
  end

  def logging_args
    args = specializations("logging") || {}
    if args.any?
      optionize({ "log-driver" => args["driver"] }.compact) +
        argumentize("--log-opt", args["options"])
    else
      config.logging_args
    end
  end

  def volume_args
    if specializations('volumes').present?
      argumentize "--volume", specializations('volumes')
    else
      []
    end
  end

  private
    attr_accessor :config

    def delegate_config
      @delegate_config || {}
    end

    def specializations(key)
      base_config = config.raw_config[key]
      specialization = delegate_config[key]
      return base_config unless specialization.present?
      return specialization unless base_config.present?

      if base_config.is_a?(Hash) && specialization.is_a?(Hash)
        Hash.new.tap do |hash|
          hash.deep_merge!(base_config)
          hash.deep_merge!(delegate_config[key])
        end
      elsif base_config.is_a?(Array) && specialization.is_a?(Array)
        base_config + specialization
      else
        specialization
      end
    end
end
