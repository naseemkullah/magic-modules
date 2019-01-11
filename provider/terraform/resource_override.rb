# Copyright 2017 Google Inc.
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

require 'provider/abstract_core'
require 'provider/resource_override'
require 'provider/terraform/custom_code'

module Provider
  class Terraform < Provider::AbstractCore
    # Collection of properties allowed in the ResourceOverride section for
    # Terraform. All properties should be `attr_reader :<property>`
    module OverrideProperties
      def self.attributes
        [
          # The Terraform resource id format used when calling #setId(...).
          # For instance, `{{name}}` means the id will be the resource name.
          :id_format,
          :import_format,
          :custom_code,
          :docs,

          # Lock name for a mutex to prevent concurrent API calls for a given
          # resource.
          :mutex,

          # Examples in documentation. Backed by generated tests, and have
          # corresponding OiCS walkthroughs.
          :examples
        ]
      end

      attr_reader(*attributes)
    end

    # Shared code between new resource overrides and old.
    module ResourceOverrideSharedCode
      def validate
        super

        @examples ||= []

        check :id_format, type: String, default: '{{name}}'
        check :examples, item_type: Provider::Terraform::Examples, type: Array, default: []

        check :custom_code, type: Provider::Terraform::CustomCode, default: Provider::Terraform::CustomCode.new
        check :docs, type: Provider::Terraform::Docs, default: Provider::Terraform::Docs.new
        check :import_format, type: Array, default: []
        check :import_format, type: Array, item_type: String
      end

      def apply(resource)
        unless description.nil?
          @description = format_string(:description, @description,
                                       resource.description)
        end

        super
      end

      private

      # Formats the string and potentially uses its old value as part of the new
      # value. The marker should be in the form `{{name}}` where `name` is the
      # field being formatted.
      #
      # Note: This function only supports the variable with the same name as the
      # property being updated.
      def format_string(name, mask, current_value)
        mask.gsub "{{#{name.id2name}}}", current_value
      end
    end

    # A class to control overridden properties on terraform.yaml in lieu of
    # values from api.yaml.
    class ResourceOverride < Provider::ResourceOverride
      include OverrideProperties
      include ResourceOverrideSharedCode

      private

      def overriden
        Provider::Terraform::OverrideProperties
      end
    end
  end
end
