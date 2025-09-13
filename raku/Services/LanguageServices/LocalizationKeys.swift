//
//  LocalizationKeys.swift
//  raku
//
//  Created by Claude on 2025/1/7.
//

import Foundation

// MARK: - 本地化Key定义参考
/// 本地化Key命名规范：
/// - 通用文案：common_功能_类型
/// - 业务文案：域_功能_场景_类型
/// 
/// 示例：
/// - common_cancel (通用取消按钮)
/// - recording_list_empty (录音列表为空)
/// - detail_tag_edit_title (详情页标签编辑标题)
///
/// 使用方式：
/// - L("common_cancel")
/// - L("search_result_count", 10)

// MARK: - 通用文案 Keys
// common_cancel
// common_confirm
// common_save
// common_delete
// common_edit
// common_done
// common_close
// common_retry
// common_loading
// common_error
// common_success
// common_warning
// common_info
// common_yes
// common_no
// common_ok
// common_back
// common_next
// common_previous
// common_add
// common_remove
// common_search
// common_filter
// common_share
// common_export
// common_import
// common_download
// common_upload
// common_settings
// common_help
// common_about
// common_version
// common_update
// common_refresh
// common_clear
// common_all
// common_none
// common_other
// common_unknown
// common_today
// common_yesterday
// common_tomorrow
// common_now
// common_recently

// MARK: - 录音管理 Keys
// recording_list_title
// recording_list_empty
// recording_list_empty_desc
// recording_control_start
// recording_control_stop
// recording_control_pause
// recording_control_resume
// recording_control_play
// recording_status_recording
// recording_status_paused
// recording_status_stopped
// recording_status_playing
// recording_action_delete
// recording_action_share
// recording_action_export
// recording_action_download
// recording_action_rename
// recording_delete_confirm_title
// recording_delete_confirm_message
// recording_error_save_failed
// recording_error_load_failed
// recording_error_delete_failed
// recording_error_export_failed
// recording_success_saved
// recording_success_deleted
// recording_success_exported

// MARK: - 录音详情 Keys
// detail_nav_title
// detail_nav_back
// detail_tag_edit_title
// detail_tag_current
// detail_tag_add
// detail_tag_suggested
// detail_tag_placeholder
// detail_tag_saving
// detail_tag_save_failed
// detail_section_edit_title
// detail_section_edit_mode
// detail_section_preview_mode
// detail_transcript_original
// detail_transcript_polished
// detail_transcript_full_view
// detail_markdown_title
// detail_markdown_bold
// detail_markdown_italic
// detail_markdown_list
// detail_markdown_todo
// detail_markdown_quote
// detail_markdown_code
// detail_markdown_divider

// MARK: - 连接管理 Keys
// connection_status_connected
// connection_status_disconnected
// connection_status_connecting
// connection_config_title
// connection_config_device
// connection_config_network
// connection_error_failed
// connection_error_network_unavailable
// connection_error_device_not_found

// MARK: - 首页 Keys
// homepage_title
// homepage_filter_tag
// homepage_filter_space
// homepage_search_placeholder
// homepage_search_empty
// homepage_search_empty_desc
// homepage_search_loading
// homepage_product_name
// homepage_device_connected
// homepage_device_disconnected

// MARK: - 搜索 Keys
// search_title
// search_placeholder
// search_result_empty
// search_result_empty_desc
// search_result_count
// search_history_title
// search_history_clear
// search_type_all
// search_type_title
// search_type_content
// search_type_tag

// MARK: - 设置 Keys
// settings_title
// settings_appearance_title
// settings_dark_mode
// settings_language
// settings_theme
// settings_recording_title
// settings_audio_quality
// settings_auto_save
// settings_storage_location
// settings_privacy_title
// settings_data_collection
// settings_analytics
// settings_about_title
// settings_app_version
// settings_build_number
// settings_developer
// settings_contact
// settings_feedback
// settings_rate_app

// MARK: - 导出 Keys
// export_title
// export_format_title
// export_format_text
// export_format_markdown
// export_format_pdf
// export_format_audio
// export_options_title
// export_include_transcript
// export_include_summary
// export_include_timestamp
// export_destination_title
// export_destination_files
// export_destination_share
// export_destination_cloud
// export_progress_title
// export_progress_generating
// export_progress_uploading
// export_success_title
// export_success_message
// export_error_title
// export_error_message
// export_error_invalid_format
// export_error_file_size
// export_error_permission

// MARK: - 时间格式 Keys
// time_format_duration
// time_format_time
// time_format_date
// time_format_datetime
// time_unit_second
// time_unit_minute
// time_unit_hour
// time_unit_day
// time_unit_week
// time_unit_month
// time_unit_year
// time_relative_just_now
// time_relative_minutes_ago
// time_relative_hours_ago
// time_relative_days_ago

// MARK: - 错误提示 Keys
// error_network_title
// error_network_message
// error_storage_title
// error_storage_message
// error_storage_full
// error_permission_title
// error_permission_microphone
// error_permission_storage
// error_file_title
// error_file_not_found
// error_file_corrupted
// error_file_format
// error_unknown_title
// error_unknown_message