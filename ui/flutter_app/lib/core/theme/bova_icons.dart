import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BovaIconPair {
  final IconData outline;
  final IconData filled;

  const BovaIconPair({required this.outline, required this.filled});
}

class BovaIcons {
  BovaIcons._();

  static const BovaIconPair home = BovaIconPair(
    outline: Icons.home_outlined,
    filled: Icons.home_rounded,
  );
  static const IconData homeOutline = Icons.home_outlined;
  static const IconData homeFilled = Icons.home_rounded;

  static const BovaIconPair player = BovaIconPair(
    outline: CupertinoIcons.play_circle,
    filled: CupertinoIcons.play_circle_fill,
  );
  static const IconData playerOutline = CupertinoIcons.play_circle;
  static const IconData playerFilled = CupertinoIcons.play_circle_fill;

  static const BovaIconPair library = BovaIconPair(
    outline: CupertinoIcons.square_grid_2x2,
    filled: CupertinoIcons.square_grid_2x2_fill,
  );
  static const IconData libraryOutline = CupertinoIcons.square_grid_2x2;
  static const IconData libraryFilled = CupertinoIcons.square_grid_2x2_fill;

  static const BovaIconPair movie = BovaIconPair(
    outline: Icons.local_movies_outlined,
    filled: Icons.local_movies_rounded,
  );
  static const IconData movieOutline = Icons.local_movies_outlined;
  static const IconData movieFilled = Icons.local_movies_rounded;

  static const BovaIconPair tv = BovaIconPair(
    outline: Icons.live_tv_outlined,
    filled: Icons.live_tv_rounded,
  );
  static const IconData tvOutline = Icons.live_tv_outlined;
  static const IconData tvFilled = Icons.live_tv_rounded;

  static const BovaIconPair discover = BovaIconPair(
    outline: Icons.explore_outlined,
    filled: Icons.explore_rounded,
  );

  static const BovaIconPair add = BovaIconPair(
    outline: CupertinoIcons.add_circled,
    filled: CupertinoIcons.add_circled_solid,
  );
  static const IconData addOutline = CupertinoIcons.add_circled;
  static const IconData addFilled = CupertinoIcons.add_circled_solid;

  static const BovaIconPair cloud = BovaIconPair(
    outline: CupertinoIcons.cloud,
    filled: CupertinoIcons.cloud_fill,
  );
  static const IconData cloudOutline = CupertinoIcons.cloud;
  static const IconData cloudFilled = CupertinoIcons.cloud_fill;

  static const BovaIconPair folder = BovaIconPair(
    outline: CupertinoIcons.folder,
    filled: CupertinoIcons.folder_fill,
  );
  static const IconData folderOutline = CupertinoIcons.folder;
  static const IconData folderFilled = CupertinoIcons.folder_fill;

  static const BovaIconPair upload = BovaIconPair(
    outline: CupertinoIcons.cloud_upload,
    filled: CupertinoIcons.cloud_upload_fill,
  );
  static const IconData uploadOutline = CupertinoIcons.cloud_upload;
  static const IconData uploadFilled = CupertinoIcons.cloud_upload_fill;

  static const BovaIconPair refresh = BovaIconPair(
    outline: CupertinoIcons.arrow_clockwise,
    filled: CupertinoIcons.refresh_circled_solid,
  );
  static const IconData refreshOutline = CupertinoIcons.arrow_clockwise;
  static const IconData refreshFilled = CupertinoIcons.refresh_circled_solid;

  static const BovaIconPair edit = BovaIconPair(
    outline: CupertinoIcons.pencil,
    filled: CupertinoIcons.pencil_circle_fill,
  );
  static const IconData editOutline = CupertinoIcons.pencil;

  static const BovaIconPair more = BovaIconPair(
    outline: CupertinoIcons.ellipsis_circle,
    filled: CupertinoIcons.ellipsis_circle_fill,
  );
  static const IconData moreOutline = CupertinoIcons.ellipsis_circle;

  static const BovaIconPair person = BovaIconPair(
    outline: CupertinoIcons.person_circle,
    filled: CupertinoIcons.person_circle_fill,
  );
  static const IconData personOutline = CupertinoIcons.person_circle;
  static const IconData personFilled = CupertinoIcons.person_circle_fill;

  static const BovaIconPair delete = BovaIconPair(
    outline: CupertinoIcons.trash,
    filled: CupertinoIcons.trash_fill,
  );
  static const IconData deleteOutline = CupertinoIcons.trash;

  static const IconData searchOutline = Icons.search_rounded;
  static const IconData bookmarkOutline = Icons.bookmark_border_rounded;
  static const IconData bookmarkFilled = Icons.bookmark_rounded;
  static const IconData bellOutline = Icons.notifications_none_rounded;
  static const IconData bellFilled = Icons.notifications_rounded;
  static const IconData settingsOutline = Icons.settings_outlined;
  static const IconData settingsFilled = Icons.settings_rounded;
  static const IconData chevronRight = CupertinoIcons.chevron_right;
  static const IconData folderOpen = CupertinoIcons.folder_open;
}
