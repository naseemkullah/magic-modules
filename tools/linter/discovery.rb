# Copyright 2018 Google Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'net/http'
require 'json'
require 'api/product'
require 'api/resource'
require 'api/type'

TYPES = {
  'string': 'String',
  'boolean': 'Boolean',
  'object': 'NestedObject',
  'integer': 'Integer',
  'number': 'Double',
  'array': 'Array'
}

class DiscoveryProperty
  attr_reader :schema

  def initialize(name, schema)
    @name = name
    @schema = schema
  end

  def get_property
    prop = Module.const_get("Api::Type::#{type}").new
    prop.name = @name
    prop.description = @schema.dig('description')
    prop.output = output?
    prop
  end

  private

  def type
    return "NestedObject" if @schema.dig('$ref')
    return "Enum" if @schema.dig('enum')
    TYPES[@schema.dig('type').to_sym]
  end

  def output?
    (@schema.dig('description') || '').downcase.include?('output only')
  end
end

# Holds information about discovery objects
# Two sections: schema (properties) and methods
class DiscoveryResource
  attr_reader :schema

  def initialize(schema)
    @schema = schema
  end

  def exists?
    !@schema.nil?
  end

  def resource
    res = Api::Resource.new
    res.name = @schema.dig('id')
    res.kind = @schema.dig('properties', 'kind', 'default')
    res.description = @schema.dig('description')
    res.properties = @schema.dig('properties')
                            .reject { |k, _| k == 'kind' }
                            .map { |k, v| DiscoveryProperty.new(k, v).get_property }
    res
  end
end

# Responsible for grabbing Discovery Docs and getting resources from it
class DiscoveryProduct
  attr_reader :results

  def initialize(doc)
    @doc = doc
    @results = send_request(@doc.url)
  end

  def get_resources
    @results['schemas'].map do |name, schema|
      next unless @doc.objects.include?(name)
      DiscoveryResource.new(schema).resource
    end.compact
  end

  def get_product
    product = Api::Product.new
    product.name = @doc.name
    product.prefix = @doc.prefix
    product.scopes = @doc.scopes
    product.objects = get_resources
    product
  end

  private

  def send_request(url)
    JSON.parse(Net::HTTP.get(URI(url)))
  end
end
