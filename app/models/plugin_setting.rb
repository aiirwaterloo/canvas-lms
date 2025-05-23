# frozen_string_literal: true

#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

# == Schema Information
#
# Table name: plugin_settings
#
#  id         :integer(4)      not null, primary key
#  name       :string(255)     default(""), not null
#  settings   :text
#  created_at :datetime
#  updated_at :datetime
#
class PluginSetting < ActiveRecord::Base
  validates :name, uniqueness: { if: :validate_uniqueness_of_name? }
  before_save :validate_posted_settings
  serialize :settings, yaml: { permitted_classes: [Symbol, Class] }
  attr_accessor :posted_settings

  attr_writer :plugin

  before_save :encrypt_settings
  after_save :clear_cache
  after_destroy :clear_cache
  after_initialize :initialize_plugin_setting

  def validate_uniqueness_of_name?
    true
  end

  def validate_posted_settings
    if @posted_settings
      plugin = Canvas::Plugin.find(name.to_s)
      @posted_settings.transform_values! { |v| v.is_a?(String) ? v.strip : v }
      result = plugin.validate_settings(self, @posted_settings)
      throw :abort if result == false
    end
  end

  def plugin
    @plugin ||= Canvas::Plugin.find(name.to_s)
  end

  # dummy value for encrypted fields so that you can still have something in the form (to indicate
  # it's set) and be able to tell when it gets blanked out.
  DUMMY_STRING = "~!?3NCRYPT3D?!~"
  def initialize_plugin_setting
    return unless settings && plugin

    @valid_settings = true
    if plugin.encrypted_settings
      was_dirty = changed?
      plugin.encrypted_settings.each do |key|
        next unless settings[:"#{key}_enc"]

        begin
          settings[:"#{key}_dec"] = self.class.decrypt(settings[:"#{key}_enc"], settings[:"#{key}_salt"])
        rescue
          @valid_settings = false
        end
        settings[key] = DUMMY_STRING
      end
      # We shouldn't consider a plugin setting to be dirty if all that changed were the decrypted/placeholder attributes
      clear_changes_information unless was_dirty
    end
  end

  def valid_settings?
    @valid_settings
  end

  def encrypt_settings
    if settings && plugin&.encrypted_settings
      plugin.encrypted_settings.each do |key|
        next if settings[key].blank?

        value = settings.delete(key)
        settings.delete(:"#{key}_dec")
        if value == DUMMY_STRING # no change, use what was there previously
          unless settings_was.nil? # we wont have setting_was if we are a new plugin
            settings[:"#{key}_enc"] = settings_was[:"#{key}_enc"]
            settings[:"#{key}_salt"] = settings_was[:"#{key}_salt"]
          end
        else
          settings[:"#{key}_enc"], settings[:"#{key}_salt"] = self.class.encrypt(value)
        end
      end
    end
  end

  def enabled?
    !disabled
  end

  def self.cached_plugin_setting(name)
    RequestCache.cache(settings_cache_key(name)) do
      MultiCache.fetch(settings_cache_key(name)) do
        PluginSetting.find_by_name(name.to_s)
      end
    end
  end

  def self.settings_for_plugin(name, plugin = nil)
    RequestCache.cache(settings_cache_key(name.to_s + "_settings")) do
      if (plugin_setting = cached_plugin_setting(name)) && plugin_setting.valid_settings? && plugin_setting.enabled?
        plugin_setting.plugin = plugin
        settings = plugin_setting.settings
      else
        plugin ||= Canvas::Plugin.find(name.to_s)
        raise Canvas::NoPluginError unless plugin

        settings = plugin.default_settings
      end

      settings
    end
  end

  def self.settings_cache_key(name)
    ["settings_for_plugin4", name].cache_key
  end

  def clear_cache
    self.class.connection.after_transaction_commit do
      MultiCache.delete(PluginSetting.settings_cache_key(name))
    end
  end

  def self.encrypt(text)
    Canvas::Security.encrypt_password(text, "instructure_plugin_setting")
  end

  def self.decrypt(text, salt)
    Canvas::Security.decrypt_password(text, salt, "instructure_plugin_setting")
  end

  def self.find_by_name(name)
    where(name:).first
  end

  # stub for plugins who want to do something fancy
  def self.current_account=(_); end
end
