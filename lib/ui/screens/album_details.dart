import 'dart:ui';

import 'package:app/models/models.dart';
import 'package:app/providers/providers.dart';
import 'package:app/ui/widgets/app_bar.dart';
import 'package:app/ui/widgets/bottom_space.dart';
import 'package:app/ui/widgets/song_list_buttons.dart';
import 'package:app/ui/widgets/song_row.dart';
import 'package:app/ui/widgets/sortable_song_list.dart';
import 'package:app/ui/widgets/spinner.dart';
import 'package:flutter/material.dart' hide AppBar;
import 'package:provider/provider.dart';

SortField _currentSortOrder = SortField.trackNumber;

class AlbumDetailsScreen extends StatefulWidget {
  static const routeName = '/album';

  const AlbumDetailsScreen({Key? key}) : super(key: key);

  _AlbumDetailsScreenState createState() => _AlbumDetailsScreenState();
}

class _AlbumDetailsScreenState extends State<AlbumDetailsScreen> {
  SortField _sortOrder = _currentSortOrder;

  @override
  Widget build(BuildContext context) {
    int albumId = ModalRoute.of(context)!.settings.arguments as int;

    return Scaffold(
      body: FutureBuilder(
        future: Future.wait([
          context.read<AlbumProvider>().resolve(albumId),
          context.read<SongProvider>().fetchForAlbum(albumId),
        ]),
        builder: (_, AsyncSnapshot<List<dynamic>> snapshot) {
          if (!snapshot.hasData || snapshot.hasError) {
            return const Center(child: const Spinner());
          }

          var album = snapshot.data![0] as Album;
          var songs = sortSongs(
            snapshot.data![1] as List<Song>,
            orderBy: _sortOrder,
          );

          return CustomScrollView(
            slivers: <Widget>[
              AppBar(
                headingText: album.name,
                actions: [
                  SortButton(
                    options: {
                      SortField.trackNumber: 'Track number',
                      SortField.title: 'Song title',
                      SortField.recentlyAdded: 'Recently added',
                    },
                    currentSortField: _sortOrder,
                    onActionSheetActionPressed: (SortField order) {
                      _currentSortOrder = order;
                      setState(() => _sortOrder = order);
                    },
                  ),
                ],
                backgroundImage: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: album.image,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                ),
                coverImage: Hero(
                  tag: "album-hero-${album.id}",
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: album.image,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(16),
                      ),
                      boxShadow: const <BoxShadow>[
                        const BoxShadow(
                          color: Colors.black38,
                          blurRadius: 10.0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (songs.isNotEmpty)
                SliverToBoxAdapter(child: SongListButtons(songs: songs)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, int index) => SongRow(
                    song: songs[index],
                    listContext: SongListContext.album,
                  ),
                  childCount: songs.length,
                ),
              ),
              const BottomSpace(),
            ],
          );
        },
      ),
    );
  }
}
