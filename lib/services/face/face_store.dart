import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../zedgift_api.dart';
import 'face_embedder.dart';

/// One enrolled person and their face descriptors (several, one per angle).
class FaceEntry {
  FaceEntry({required this.employeeId, required this.name, required this.embeddings});
  final int employeeId;
  final String name;
  final List<List<double>> embeddings;

  Map<String, dynamic> toJson() => {
        'employee_id': employeeId,
        'name': name,
        'embeddings': embeddings,
      };

  factory FaceEntry.fromJson(Map<String, dynamic> j) => FaceEntry(
        employeeId: (j['employee_id'] as num).toInt(),
        name: j['name']?.toString() ?? '',
        embeddings: (j['embeddings'] as List)
            .map((e) => (e as List).map((x) => (x as num).toDouble()).toList())
            .toList(),
      );
}

/// The best match returned by [FaceStore.identify].
class FaceMatch {
  FaceMatch(this.employeeId, this.name, this.score);
  final int employeeId;
  final String name;
  final double score; // cosine similarity, higher = closer
}

/// On-device store of enrolled faces (JSON file in the app's documents dir).
/// Enrollment writes here so the kiosk can identify people offline.
class FaceStore {
  FaceStore._();
  static final FaceStore instance = FaceStore._();

  final List<FaceEntry> _entries = [];
  bool _loaded = false;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/face_db.json');
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        if (data is List) {
          _entries
            ..clear()
            ..addAll(data
                .whereType<Map>()
                .map((e) => FaceEntry.fromJson(e.cast<String, dynamic>())));
        }
      }
    } catch (_) {/* start empty */}
  }

  Future<void> _persist() async {
    final f = await _file();
    await f.writeAsString(jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  int get count => _entries.length;

  /// Ensure the on-device DB is loaded, then report how many faces it holds.
  Future<int> ensureLoadedCount() async {
    await _ensureLoaded();
    return _entries.length;
  }

  /// Add or replace an employee's enrolled descriptors.
  Future<void> enroll(int employeeId, String name, List<List<double>> embeddings) async {
    await _ensureLoaded();
    _entries.removeWhere((e) => e.employeeId == employeeId);
    _entries.add(FaceEntry(employeeId: employeeId, name: name, embeddings: embeddings));
    await _persist();
  }

  /// Pull every employee's stored face descriptor from the backend so this
  /// device can identify people even though enrolment happened elsewhere.
  /// Returns how many faces were loaded. Fetches in small parallel chunks.
  Future<int> syncFromServer({void Function(int done, int total)? onProgress}) async {
    final emps = await ZedgiftApi.instance.employees();
    final loaded = <FaceEntry>[];
    const chunk = 8;
    var done = 0;
    for (var i = 0; i < emps.length; i += chunk) {
      final slice = emps.skip(i).take(chunk).toList();
      await Future.wait(slice.map((e) async {
        try {
          final m = await ZedgiftApi.instance.getFace(e.id);
          final embs = _parseDescriptor(m['descriptor']);
          if (embs.isNotEmpty) {
            loaded.add(FaceEntry(
                employeeId: e.id, name: e.name, embeddings: embs));
          }
        } catch (_) {/* no face for this employee */}
      }));
      done += slice.length;
      onProgress?.call(done, emps.length);
    }
    _entries
      ..clear()
      ..addAll(loaded);
    _loaded = true;
    await _persist();
    return _entries.length;
  }

  /// Parse a stored descriptor into a list of embeddings. Accepts a JSON
  /// string or already-decoded value; handles both a single vector and a
  /// list of vectors.
  List<List<double>> _parseDescriptor(dynamic raw) {
    if (raw == null) return const [];
    dynamic d = raw;
    if (d is String) {
      if (d.trim().isEmpty) return const [];
      try {
        d = jsonDecode(d);
      } catch (_) {
        return const [];
      }
    }
    if (d is! List || d.isEmpty) return const [];
    // List of vectors -> [[...],[...]]; single vector -> [...]
    if (d.first is List) {
      return d
          .whereType<List>()
          .map((v) => v.map((x) => (x as num).toDouble()).toList())
          .toList();
    }
    return [d.map((x) => (x as num).toDouble()).toList()];
  }

  /// Find the closest enrolled person for [probe]. Returns null if the store
  /// is empty. Caller applies a threshold on [FaceMatch.score].
  Future<FaceMatch?> identify(List<double> probe) async {
    await _ensureLoaded();
    FaceMatch? best;
    for (final entry in _entries) {
      for (final emb in entry.embeddings) {
        final s = FaceEmbedder.cosine(probe, emb);
        if (best == null || s > best.score) {
          best = FaceMatch(entry.employeeId, entry.name, s);
        }
      }
    }
    return best;
  }
}
