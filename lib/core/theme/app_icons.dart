// ignore_for_file: constant_identifier_names

import 'package:flutter/widgets.dart';

/// The app's icons: soft, filled and rounded all over, in the same spirit as
/// the navigation glyphs — no hairlines and no sharp corners.
///
/// Members keep the names of the Material icons they replaced, so reading a
/// call site still says what the icon is. Drawn from Phosphor Icons (MIT,
/// see assets/fonts/SoftIcons-LICENSE.txt), bundled with the app so nothing
/// is ever fetched.
abstract final class AppIcons {
  static const String _fill = 'SoftIcons';

  /// The same shapes as a heavier outline, for the "off" half of a toggle
  /// such as a heart that is not yet a favourite.
  static const String _line = 'SoftIconsLine';

  static const IconData add_rounded = IconData(0xe3d4, fontFamily: _fill);
  static const IconData add_to_queue_rounded = IconData(
    0xe6ac,
    fontFamily: _fill,
  );
  static const IconData album_outlined = IconData(0xecac, fontFamily: _fill);
  static const IconData album_rounded = IconData(0xecac, fontFamily: _fill);
  static const IconData arrow_back_rounded = IconData(
    0xe138,
    fontFamily: _fill,
    matchTextDirection: true,
  );
  static const IconData aspect_ratio_rounded = IconData(
    0xe626,
    fontFamily: _fill,
  );
  static const IconData auto_awesome_rounded = IconData(
    0xe6a2,
    fontFamily: _fill,
  );
  static const IconData bedtime_outlined = IconData(0xe58e, fontFamily: _fill);
  static const IconData bedtime_rounded = IconData(0xe330, fontFamily: _fill);
  static const IconData blur_on_rounded = IconData(0xe210, fontFamily: _fill);
  static const IconData bookmark_rounded = IconData(0xe0ea, fontFamily: _fill);
  static const IconData brightness_6_rounded = IconData(
    0xe472,
    fontFamily: _fill,
  );
  static const IconData brightness_auto_rounded = IconData(
    0xe18c,
    fontFamily: _fill,
  );
  static const IconData brightness_high_rounded = IconData(
    0xe472,
    fontFamily: _fill,
  );
  static const IconData brightness_low_rounded = IconData(
    0xe474,
    fontFamily: _fill,
  );
  static const IconData brightness_medium_rounded = IconData(
    0xe474,
    fontFamily: _fill,
  );
  static const IconData cancel_rounded = IconData(0xe4f8, fontFamily: _fill);
  static const IconData instagram_logo = IconData(0xe2d0, fontFamily: _fill);
  static const IconData play_box = IconData(0xe4fc, fontFamily: _fill);
  static const IconData remove_rounded = IconData(0xe32a, fontFamily: _fill);
  static const IconData touch_app_rounded = IconData(0xec90, fontFamily: _fill);
  static const IconData check_circle_rounded = IconData(
    0xe184,
    fontFamily: _fill,
  );
  static const IconData check_rounded = IconData(0xe182, fontFamily: _fill);
  static const IconData checklist_rounded = IconData(0xeadc, fontFamily: _fill);
  static const IconData chevron_right_rounded = IconData(
    0xe13a,
    fontFamily: _fill,
    matchTextDirection: true,
  );
  static const IconData circle_outlined = IconData(0xe18a, fontFamily: _line);
  static const IconData close_rounded = IconData(0xe4f6, fontFamily: _fill);
  static const IconData copy_rounded = IconData(0xe1ca, fontFamily: _fill);
  static const IconData crop_16_9_rounded = IconData(0xe3f0, fontFamily: _fill);
  static const IconData crop_din_rounded = IconData(0xe45e, fontFamily: _fill);
  static const IconData crop_free_rounded = IconData(0xe1d0, fontFamily: _fill);
  static const IconData dark_mode_outlined = IconData(
    0xe330,
    fontFamily: _fill,
  );
  static const IconData delete_forever_rounded = IconData(
    0xe4a6,
    fontFamily: _fill,
  );
  static const IconData delete_outline_rounded = IconData(
    0xe4a6,
    fontFamily: _fill,
  );
  static const IconData delete_sweep_outlined = IconData(
    0xec54,
    fontFamily: _fill,
  );
  static const IconData drag_handle_rounded = IconData(
    0xe794,
    fontFamily: _fill,
  );
  static const IconData drag_indicator_rounded = IconData(
    0xeae2,
    fontFamily: _fill,
  );
  static const IconData drive_file_move_outline = IconData(
    0xe256,
    fontFamily: _fill,
  );
  static const IconData drive_file_rename_outline_rounded = IconData(
    0xe3b4,
    fontFamily: _fill,
  );
  static const IconData edit_outlined = IconData(0xe3b4, fontFamily: _fill);
  static const IconData edit_rounded = IconData(0xe3b4, fontFamily: _fill);
  static const IconData equalizer_rounded = IconData(0xebbc, fontFamily: _fill);
  static const IconData error_outline_rounded = IconData(
    0xe4e2,
    fontFamily: _fill,
  );
  static const IconData family_restroom_rounded = IconData(
    0xe4d6,
    fontFamily: _fill,
  );
  static const IconData fast_forward_rounded = IconData(
    0xe6a6,
    fontFamily: _fill,
  );
  static const IconData fast_rewind_rounded = IconData(
    0xe6a8,
    fontFamily: _fill,
  );
  static const IconData favorite = IconData(0xe2a8, fontFamily: _fill);
  static const IconData favorite_border = IconData(0xe2a8, fontFamily: _line);
  static const IconData favorite_border_rounded = IconData(
    0xe2a8,
    fontFamily: _line,
  );
  static const IconData favorite_rounded = IconData(0xe2a8, fontFamily: _fill);
  static const IconData fit_screen_rounded = IconData(
    0xe626,
    fontFamily: _fill,
  );
  static const IconData flight_rounded = IconData(0xe002, fontFamily: _fill);
  static const IconData folder_off_outlined = IconData(
    0xe25c,
    fontFamily: _fill,
  );
  static const IconData folder_outlined = IconData(0xe24a, fontFamily: _fill);
  static const IconData folder_rounded = IconData(0xe24a, fontFamily: _fill);
  static const IconData forward_10_rounded = IconData(
    0xe22c,
    fontFamily: _fill,
  );
  static const IconData graphic_eq_rounded = IconData(
    0xe802,
    fontFamily: _fill,
  );
  static const IconData grid_view_rounded = IconData(0xe464, fontFamily: _fill);
  static const IconData headphones_rounded = IconData(
    0xe2a6,
    fontFamily: _fill,
  );
  static const IconData history_rounded = IconData(0xe1a0, fontFamily: _fill);
  static const IconData info_outline_rounded = IconData(
    0xe2ce,
    fontFamily: _fill,
  );
  static const IconData keyboard_arrow_down_rounded = IconData(
    0xe136,
    fontFamily: _fill,
  );
  static const IconData library_music_outlined = IconData(
    0xecac,
    fontFamily: _fill,
  );
  static const IconData lock_outline_rounded = IconData(
    0xe2fa,
    fontFamily: _fill,
  );
  static const IconData lock_rounded = IconData(0xe2fa, fontFamily: _fill);
  static const IconData mic_rounded = IconData(0xe326, fontFamily: _fill);
  static const IconData more_vert = IconData(0xe208, fontFamily: _line);
  static const IconData more_vert_rounded = IconData(0xe208, fontFamily: _line);
  static const IconData movie_creation_rounded = IconData(
    0xe8c2,
    fontFamily: _fill,
  );
  static const IconData movie_outlined = IconData(0xe792, fontFamily: _fill);
  static const IconData music_note_rounded = IconData(
    0xe33c,
    fontFamily: _fill,
  );
  static const IconData north_rounded = IconData(0xe08e, fontFamily: _fill);
  static const IconData open_in_full_rounded = IconData(
    0xe0a2,
    fontFamily: _fill,
  );
  static const IconData pause_rounded = IconData(0xe39e, fontFamily: _fill);
  static const IconData person_outline_rounded = IconData(
    0xe4c2,
    fontFamily: _fill,
  );
  static const IconData person_rounded = IconData(0xe4c2, fontFamily: _fill);
  static const IconData phone_android_rounded = IconData(
    0xe1e0,
    fontFamily: _fill,
  );
  static const IconData photo_library_outlined = IconData(
    0xe836,
    fontFamily: _fill,
  );
  static const IconData photo_size_select_actual_outlined = IconData(
    0xe2ca,
    fontFamily: _fill,
  );
  static const IconData picture_in_picture_alt_rounded = IconData(
    0xe64c,
    fontFamily: _fill,
  );
  static const IconData play_arrow_rounded = IconData(
    0xe3d0,
    fontFamily: _fill,
  );
  static const IconData play_circle_fill_rounded = IconData(
    0xe3d2,
    fontFamily: _fill,
  );
  static const IconData play_circle_outline_rounded = IconData(
    0xe3d2,
    fontFamily: _fill,
  );
  static const IconData playlist_add_rounded = IconData(
    0xe2f8,
    fontFamily: _fill,
  );
  static const IconData playlist_play_rounded = IconData(
    0xe6aa,
    fontFamily: _fill,
  );
  static const IconData playlist_remove_rounded = IconData(
    0xe2f4,
    fontFamily: _fill,
  );
  static const IconData push_pin_outlined = IconData(0xe3e2, fontFamily: _line);
  static const IconData push_pin_rounded = IconData(0xe3e2, fontFamily: _fill);
  static const IconData queue_music_rounded = IconData(
    0xe6aa,
    fontFamily: _fill,
  );
  static const IconData queue_play_next_rounded = IconData(
    0xe6ac,
    fontFamily: _fill,
  );
  static const IconData refresh_rounded = IconData(0xe094, fontFamily: _fill);
  static const IconData repeat_one_on_rounded = IconData(
    0xe3f8,
    fontFamily: _fill,
  );
  static const IconData repeat_one_rounded = IconData(
    0xe3f8,
    fontFamily: _fill,
  );
  static const IconData repeat_rounded = IconData(0xe3f6, fontFamily: _fill);
  static const IconData restart_alt_rounded = IconData(
    0xe038,
    fontFamily: _fill,
  );
  static const IconData restore_from_trash_rounded = IconData(
    0xe038,
    fontFamily: _fill,
  );
  static const IconData restore_rounded = IconData(0xe1a0, fontFamily: _fill);
  static const IconData rule_folder_outlined = IconData(
    0xec2e,
    fontFamily: _fill,
  );
  static const IconData school_rounded = IconData(0xe62c, fontFamily: _fill);
  static const IconData screen_lock_portrait_rounded = IconData(
    0xe2fe,
    fontFamily: _fill,
  );
  static const IconData screen_rotation_rounded = IconData(
    0xedf2,
    fontFamily: _fill,
  );
  static const IconData search = IconData(0xe30c, fontFamily: _fill);
  static const IconData search_off_rounded = IconData(
    0xe30e,
    fontFamily: _fill,
  );
  static const IconData search_rounded = IconData(0xe30c, fontFamily: _fill);
  static const IconData select_all_rounded = IconData(
    0xe746,
    fontFamily: _fill,
  );
  static const IconData settings_outlined = IconData(0xe272, fontFamily: _fill);
  static const IconData shuffle_rounded = IconData(0xe422, fontFamily: _fill);
  static const IconData skip_next_rounded = IconData(0xe5a6, fontFamily: _fill);
  static const IconData skip_previous_rounded = IconData(
    0xe5a4,
    fontFamily: _fill,
  );
  static const IconData sort_rounded = IconData(0xe444, fontFamily: _fill);
  static const IconData south_rounded = IconData(0xe03e, fontFamily: _fill);
  static const IconData speed_rounded = IconData(0xe628, fontFamily: _fill);
  static const IconData sports_esports_rounded = IconData(
    0xe26e,
    fontFamily: _fill,
  );
  static const IconData sports_soccer_rounded = IconData(
    0xe716,
    fontFamily: _fill,
  );
  static const IconData star_rounded = IconData(0xe46a, fontFamily: _fill);
  static const IconData stay_current_landscape_rounded = IconData(
    0xedf2,
    fontFamily: _fill,
  );
  static const IconData stay_current_portrait_rounded = IconData(
    0xe1e0,
    fontFamily: _fill,
  );
  static const IconData storage_rounded = IconData(0xe2a0, fontFamily: _fill);
  static const IconData swap_vert_rounded = IconData(0xe098, fontFamily: _fill);
  static const IconData swipe_rounded = IconData(0xec92, fontFamily: _fill);
  static const IconData translate_rounded = IconData(0xe4a2, fontFamily: _fill);
  static const IconData tune_rounded = IconData(0xe434, fontFamily: _fill);
  static const IconData vibration_rounded = IconData(0xe4d8, fontFamily: _fill);
  static const IconData videocam_rounded = IconData(0xe4da, fontFamily: _fill);
  static const IconData view_agenda_rounded = IconData(
    0xe0f8,
    fontFamily: _fill,
  );
  static const IconData view_list_rounded = IconData(0xe5a2, fontFamily: _fill);
  static const IconData visibility_off_outlined = IconData(
    0xe224,
    fontFamily: _fill,
  );
  static const IconData visibility_off_rounded = IconData(
    0xe224,
    fontFamily: _fill,
  );
  static const IconData visibility_outlined = IconData(
    0xe220,
    fontFamily: _fill,
  );
  static const IconData visibility_rounded = IconData(
    0xe220,
    fontFamily: _fill,
  );
  static const IconData volume_down_rounded = IconData(
    0xe44c,
    fontFamily: _fill,
  );
  static const IconData volume_off_rounded = IconData(
    0xe45a,
    fontFamily: _fill,
  );
  static const IconData volume_up_rounded = IconData(0xe44a, fontFamily: _fill);
  static const IconData wallpaper_rounded = IconData(0xe2ca, fontFamily: _fill);
  static const IconData work_rounded = IconData(0xe0ee, fontFamily: _fill);
}
