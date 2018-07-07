require 'faraday'
require 'faraday_middleware'
require 'recursive-open-struct'
require 'scaleway/version'

module Scaleway

  extend self

  def compute_endpoint
    "https://cp-#{Scaleway.zone}.scaleway.com"
  end

  def account_endpoint
    "https://account.scaleway.com"
  end

  def marketplace_endpoint
    "https://api-marketplace.scaleway.com"
  end

  def zone=(zone)
    @zone = zone
    @zone
  end

  def zone
    return @zone || 'par1'
  end

  def token=(token)
    @token = token
    setup!
    @token
  end

  def token
    return @token if @token
    "token_required"
  end

  def organization=(organization)
    @organization = organization
    setup!
    @organization
  end

  def organization
    return @organization if @organization
    "organization_required"
  end

  DEFINITIONS = {
    "Marketplace" => {
      :all => {
        :method => :get,
        :endpoint => "#{Scaleway.marketplace_endpoint}/images",
      },
      :find_local_image_by_name => {
        :method => :get,
        :endpoint => "#{Scaleway.marketplace_endpoint}/images",
        :default_params => {
            arch: 'x86_64',
        },
        :filters => [
          Proc.new { |params, body, item|
            item.name.include? params.first }
        ],
        :transform => Proc.new { |params, body, item|
          item[0].versions[0].local_images.keep_if do |local_image|
            if local_image.zone == Scaleway.zone and local_image.arch == body[:arch]
              true
            end
          end.first
        },
      },
      :find_local_image => {
        :method => :get,
        :endpoint => "#{Scaleway.marketplace_endpoint}/images/%s/versions/current",
        :default_params => {
            arch: 'x86_64',
        },
        :transform => Proc.new { |params, body, item|
          item.local_images.keep_if do |local_image|
            if local_image.zone == Scaleway.zone and local_image.arch == body[:arch]
              true
            end
          end.first
        },
      },
    },
    "Image" => {
      :all => {
        :method => :get,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/images" },
        :default_params => {
          :public => true
        }
      },
      :find => {
        :method => :get,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/images/%s" },
      },
      :find_by_name => {
        :method => :get,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/images" },
        :filters => [
          Proc.new { |params, body, item| item.name.include? params.first }
        ],
        :transform => Proc.new { |params, body, item| item.first },
      },
      :create => {
        :method => :post,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/images" },
        :default_params => {
          :name => 'default',
          :root_volume => 'required',
          :organization => Proc.new { Scaleway.organization },
        }
      },
      :edit => {
        :method => :put,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/images/%s" },
      },
      :destroy => {
        :method => :delete,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/images/%s" },
      },
    },
    "Volume" => {
      :all => {
        :method => :get,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/volumes" },
      },
      :find => {
        :method => :get,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/volumes/%s" },
      },
      :edit => {
        :method => :put,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/volumes/%s" },
      },
      :destroy => {
        :method => :delete,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/volumes/%s" },
      },
      :create => {
        :method => :post,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/volumes" },
        :default_params => {
          :name => 'default',
          :size => 20 * 10**9,
          :volume_type => 'l_hdd',
          :organization => Proc.new { Scaleway.organization },
        }
      },
    },
    "Ip" => {
      :all => {
        :method => :get,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/ips" },
      },
      :find => {
        :method => :get,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/ips/%s" },
      },
      :edit => {
        :method => :put,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/ips/%s" },
      },
      :destroy => {
        :method => :delete,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/ips/%s" },
      },
      :reserve => {
        :method => :post,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/ips" },
        :default_params => {
          :organization => Proc.new { Scaleway.organization },
        }
      },
      :create => {
        :method => :post,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/ips" },
        :default_params => {
          :organization => Proc.new { Scaleway.organization },
        }
      },
    },
    "Snapshot" => {
      :all => {
        :method => :get,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/snapshots" },
      },
      :find => {
        :method => :get,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/snapshots/%s" },
      },
      :edit => {
        :method => :put,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/snapshots/%s" },
      },
      :destroy => {
        :method => :delete,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/snapshots/%s" },
      },
      :create => {
        :method => :post,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/snapshots" },
        :default_params => {
          :name => 'default',
          :volume_id => 'required',
          :organization => Proc.new { Scaleway.organization },
        }
      },
    },
    "Server" => {
      :all => {
        :method => :get,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/servers" },
      },
      :power_on => {
        :method => :post,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/servers/%s/action" },
        :default_params => {
          :action => :poweron
        }
      },
      :reboot => {
        :method => :post,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/servers/%s/action" },
        :default_params => {
          :action => :reboot
        }
      },
      :power_off => {
        :method => :post,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/servers/%s/action" },
        :default_params => {
          :action => :poweroff
        }
      },
      :terminate => {
        :method => :post,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/servers/%s/action" },
        :default_params => {
          :action => :terminate
        }
      },
      :find => {
        :method => :get,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/servers/%s" },
      },
      :edit => {
        :method => :put,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/servers/%s" },
      },
      :destroy => {
        :method => :delete,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/servers/%s" },
      },
      :create => {
        :method => :post,
        :endpoint => Proc.new { "#{Scaleway.compute_endpoint}/servers" },
        :default_params => {
          :name => 'default',
          :commercial_type => 'VC1S',
          :image => Proc.new { |params, body|
            if body[:commercial_type] == 'C1' || body[:commercial_type].start_with?("ARM64")
              arch = 'arm'
            else
              arch = 'x86_64'
            end
            Scaleway::Marketplace.find_local_image_by_name(
              'Debian Sid', arch: arch).id
          },
          :volumes => {},
          :organization => Proc.new { Scaleway.organization },
          :ipv6 => true
        }
      }
    },
  }

  DEFINITIONS.each do |resource|
    resource_name = resource[0]

    resource_class = Class.new(Object) do
      singleton = class << self; self end

      DEFINITIONS[resource_name].each do |method_name, query|
        singleton.send :define_method, method_name do |*args|
          Scaleway.request_and_respond(query, *args)
        end
      end
    end

    Scaleway.const_set(resource_name, resource_class)
  end

  def request=(request)
    @request = request
  end

  def request
    @request
  end

  def request_and_respond(query, *params)
    body = {}
    body.merge! query[:default_params] || {}
    endpoint = query[:endpoint]

    if endpoint.respond_to? :call
      endpoint = endpoint.call()
    end

    params.each do |param|
      if param.is_a? Hash or param.is_a? RecursiveOpenStruct
        body.merge! param
      elsif not param.nil?
        endpoint = endpoint % param
      end
    end

    body = Hash[body.map { |k, v|
      if v.respond_to? :call then [k, v.call(params, body)] else [k, v] end
    }]

    if Scaleway.request.nil?
      raise ::RuntimeError.new("Authentication is missing")
    end

    resp = Scaleway.request.send(query[:method], endpoint, body)
    response_body = resp.body
    if resp.status == 204
      return
    end

    if resp.status == 404
      raise Scaleway::NotFound, resp
    elsif resp.status >= 300
      raise Scaleway::APIError, resp
    end

    hash = RecursiveOpenStruct.new(response_body, :recurse_over_arrays => true)

    if response_body.length == 1
      hash = hash.send(response_body.keys.first)
    end

    if query[:filters]
      filters = query[:filters]
      hash = hash.find_all do |item|
        filters.all? do |filter|
          filter.call(params, body, item)
        end
      end
    end

    if query[:transform]
      hash = query[:transform].call(params, body, hash)
    end

    hash
  end

  class APIError < Exception
    def initialize(response)
      self.status = response.status
      self.body = RecursiveOpenStruct.new(response.body, :recurse_over_arrays => true)
      self.type = self.body.type
      self.error_message = self.body.message
    end

    def to_s
      "<status:#{status}, type:#{type}, message:\'#{error_message}\'>"
    end

    def message
      "#{self}"
    end

    attr_accessor :status
    attr_accessor :type
    attr_accessor :error_message
    attr_accessor :body
  end

  class NotFound < Scaleway::APIError
  end



  private

  def setup!
    options = {
      :headers => {
        'x-auth-token' => Scaleway.token,
        'content-type' => 'application/json',
      }
    }

    Scaleway.request = ::Faraday::Connection.new(options) do |builder|
      builder.use     ::FaradayMiddleware::EncodeJson
      builder.use     ::FaradayMiddleware::ParseJson
      builder.use     ::FaradayMiddleware::FollowRedirects
      builder.adapter ::Faraday.default_adapter
    end
  end
end
