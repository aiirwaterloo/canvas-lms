/*
 * Copyright (C) 2017 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import React from 'react'
import { useScope as createI18nScope } from '@canvas/i18n'
import Modal from '@canvas/instui-bindings/react/InstuiModal'
import RichContentEditor from '@canvas/rce/RichContentEditor'
import { Link } from '@instructure/ui-link'
import { bool } from 'prop-types'
import doFetchApi from '@canvas/do-fetch-api-effect'

const I18n = createI18nScope('terms_of_service_modal')

const termsOfServiceText = I18n.t('Acceptable Use Policy')

class TermsOfServiceCustomContents extends React.Component {
  state = {
    TERMS_OF_SERVICE_CUSTOM_CONTENT: undefined,
  }

  async componentDidMount() {
    try {
      const { json, response } = await doFetchApi({
        path: '/api/v1/acceptable_use_policy',
        method: 'GET',
      })

      if (response.ok) {
        this.setState({ TERMS_OF_SERVICE_CUSTOM_CONTENT: json?.content || '' })
      } else {
        console.error(
          `Failed to load Terms of Service content: ${response.status} ${response.statusText}`,
        )
      }
    } catch (error) {
      console.error('An error occurred while fetching the Terms of Service content:', error)
    }
  }

  render() {
    return this.state.TERMS_OF_SERVICE_CUSTOM_CONTENT ? (
      <div dangerouslySetInnerHTML={{ __html: this.state.TERMS_OF_SERVICE_CUSTOM_CONTENT }} />
    ) : (
      <span>{I18n.t('Loading...')}</span>
    )
  }
}

export default class TermsOfServiceModal extends React.Component {
  static propTypes = {
    preview: bool,
    footerLink: bool,
  }

  static defaultProps = {
    preview: false,
    footerLink: false,
  }

  state = {
    open: false,
  }

  handleCloseModal = () => {
    this.link.focus()
    this.setState({ open: false })
  }

  handleLinkClick = () => {
    this.setState(state => {
      const rceContainer = document.getElementById('custom_tos_rce_container')
      let TERMS_OF_SERVICE_CUSTOM_CONTENT
      if (rceContainer) {
        const textArea = rceContainer.querySelector('textarea')
        TERMS_OF_SERVICE_CUSTOM_CONTENT = RichContentEditor.callOnRCE(textArea, 'get_code')
      }

      return {
        open: !state.open,
        TERMS_OF_SERVICE_CUSTOM_CONTENT,
      }
    })
  }

  render() {
    const linkThemeOverrides = this.props.footerLink && window.CANVAS_ACTIVE_BRAND_VARIABLES ? {
      color: window.CANVAS_ACTIVE_BRAND_VARIABLES['ic-brand-font-color-dark-lightened-15']
    } : {}

    return (
      <span id="terms_of_service_modal">
        <Link
          elementRef={c => {
            this.link = c
          }}
          href="#"
          onClick={this.handleLinkClick}
          isWithinText={!this.props.footerLink}
          themeOverride={linkThemeOverrides}
        >
          {this.props.preview ? I18n.t('Preview') : termsOfServiceText}
        </Link>
        {this.state.open && (
          <Modal
            open={this.state.open}
            onDismiss={this.handleCloseModal}
            size="fullscreen"
            label={termsOfServiceText}
          >
            <Modal.Body>
              {this.props.preview ? (
                <div
                  dangerouslySetInnerHTML={{ __html: this.state.TERMS_OF_SERVICE_CUSTOM_CONTENT }}
                />
              ) : (
                <TermsOfServiceCustomContents />
              )}
            </Modal.Body>
          </Modal>
        )}
      </span>
    )
  }
}
