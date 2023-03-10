import 'package:app/models/models.dart';
import 'package:app/providers/providers.dart';
import 'package:app/utils/api_request.dart';
import 'package:app/values/values.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

ParseResult parsePlaylists(List<dynamic> data) {
  ParseResult result = ParseResult();
  data.forEach((json) => result.add(Playlist.fromJson(json), json['id']));

  return result;
}

class PlaylistProvider with ChangeNotifier {
  SongProvider _songProvider;
  AppStateProvider _appState;
  late List<Playlist> _playlists;

  final BehaviorSubject<Playlist> _playlistPopulated = BehaviorSubject();

  ValueStream<Playlist> get playlistPopulatedStream =>
      _playlistPopulated.stream;

  PlaylistProvider({
    required SongProvider songProvider,
    required AppStateProvider appState,
  })  : _songProvider = songProvider,
        _appState = appState;

  Future<void> init(List<dynamic> playlistData) async {
    ParseResult result = await compute(parsePlaylists, playlistData);
    _playlists = result.collection.cast();
    notifyListeners();
  }

  List<Playlist> get playlists => _playlists;

  List<Playlist> get standardPlaylists =>
      _playlists.where((playlist) => playlist.isStandard).toList();

  Future<Playlist> populatePlaylist({required Playlist playlist}) async {
    if (!playlist.populated) {
      List<dynamic> response = await get('playlist/${playlist.id}/songs');

      response.cast<String>().forEach((id) {
        Song? song = _songProvider.byId(id);
        if (song != null) {
          playlist.songs.add(song);
        }
      });

      playlist.populated = true;
      _playlistPopulated.add(playlist);
    }

    return playlist;
  }

  void populateAllPlaylists() {
    _playlists.forEach((playlist) => populatePlaylist(playlist: playlist));
  }

  Future<void> addSongToPlaylist({
    required Song song,
    required Playlist playlist,
  }) async {
    assert(!playlist.isSmart, 'Cannot manually mutate smart playlists.');

    if (!playlist.populated) {
      await populatePlaylist(playlist: playlist);
    }

    if (playlist.songs.contains(song)) return;

    try {
      await _syncPlaylist(playlist: playlist..songs.add(song));
    } catch (err) {
      print(err);
      // not the end of the world
    }
  }

  Future<void> removeSongFromPlaylist({
    required Song song,
    required Playlist playlist,
  }) async {
    assert(!playlist.isSmart, 'Cannot manually mutate smart playlists.');

    try {
      await delete('playlists/${playlist.id}/songs', data: {
        'songs': [song.id],
      });

      // remove the song from the playlist's songs cache
      _appState.set(
        ['playlist.songs', playlist.id],
        _appState
            .get<List<Song>>(['playlist.songs', playlist.id])!
            .where((s) => s.id != song.id)
            .toList(),
      );
    } catch (err) {
      print(err);
      // not the end of the world
    }
  }

  Future<Playlist> create({required String name}) async {
    var json = await post('playlist', data: {
      'name': name,
    });

    Playlist playlist = Playlist.fromJson(json);
    _playlists.add(playlist);
    notifyListeners();

    return playlist;
  }

  Future<void> _syncPlaylist({required Playlist playlist}) async {
    await put('playlist/${playlist.id}/sync', data: {
      'songs': playlist.songs.map((song) => song.id).toList(),
    });

    _playlistPopulated.add(playlist);
  }

  Future<void> remove({required Playlist playlist}) async {
    // For a snappier experience, we don't `await` the operation.
    delete('playlist/${playlist.id}');
    _playlists.remove(playlist);
  }
}
