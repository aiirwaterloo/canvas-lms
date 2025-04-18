# frozen_string_literal: true

# Copyright (C) 2014 - present Instructure, Inc.
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
# By Henrik Nyh <http://henrik.nyh.se> 2008-01-30.
# Free to modify and redistribute with credit.

# modified by Dave Nolan <http://textgoeshere.org.uk> 2008-02-06
# Ellipsis appended to text of last HTML node
# Ellipsis inserted after final word break

# modified by Mark Dickson <mark@sitesteaders.com> 2008-12-18
# Option to truncate to last full word
# Option to include a 'more' link
# Check for nil last child

# Copied from http://pastie.textmate.org/342485,
# based on http://henrik.nyh.se/2008/01/rails-truncate-html-helper

require "i18n"
require "cgi"

I18n.load_path += Dir.glob(File.join(File.dirname(__FILE__), "../config/locales/*.yml"))

module CanvasTextHelper
  def self.truncate_text(text, options = {})
    truncated = text || ""

    # truncate words
    if options[:max_words]
      word_separator = options[:word_separator] || I18n.t("lib.text_helper.word_separator")
      truncated = truncated.split(word_separator)[0, options[:max_words]].join(word_separator)
    end

    if options[:max_byte]
      ellipsis = options[:ellipsis] || I18n.t("lib.text_helper.ellipsis")
      ellipsis_size = ellipsis.bytesize
      max_byte = options[:max_byte]

      if truncated.bytesize > max_byte
        max_byte -= ellipsis_size if ellipsis_size > 0
        truncated = truncated.byteslice(0, max_byte).force_encoding("UTF-8")
        unless truncated.valid_encoding?
          # We might cut a character in half, so we need to find the last valid character
          truncated = truncated.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        end
        truncated += ellipsis
      end

      return truncated
    end

    max_length = options[:max_length] || 30
    return truncated if truncated.length <= max_length

    ellipsis = options[:ellipsis] || I18n.t("lib.text_helper.ellipsis")
    actual_length = max_length - ellipsis.length
    return ellipsis if actual_length <= 0

    # First truncate the text down to the bytes max, then lop off any invalid
    # unicode characters at the end.
    truncated = truncated[0, actual_length][/.{0,#{actual_length}}/mu]
    truncated + ellipsis
  end

  def self.indent(text, spaces = 2)
    text.to_s.gsub("\n", "\n#{" " * spaces}")
  end

  # CGI escape a string, truncating it without breaking apart UTF-8 characters or other escape sequences
  def self.cgi_escape_truncate(string, max_len)
    retval = +""
    string.chars do |char|
      escape_seq = CGI.escape(char)
      break if retval.length + escape_seq.length > max_len

      retval << escape_seq
    end
    retval
  end
end
