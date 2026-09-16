import 'package:flutter/material.dart';

import '../folders/collection_page.dart';

/// Favorites tab — the same screen used when Favorites is opened from the
/// Folders list, so both entry points behave identically (phase 6).
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) => CollectionPage.favorites();
}
