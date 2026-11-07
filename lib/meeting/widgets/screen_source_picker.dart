import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_platform.dart';

const _surface = Color(0xFF1C1C1E);
const _card = Color(0xFF2C2C2E);
const _accent = Color(0xFF8A5CFF);

/// Lets a desktop user choose a screen or window to share, and whether to
/// include computer audio. Styled like the rest of the meeting UI.
class ScreenSourcePicker extends StatefulWidget {
  const ScreenSourcePicker({
    super.key,
    required this.capturer,
    required this.audioSupport,
  });

  final rtc.DesktopCapturer capturer;
  final SystemAudioSupport audioSupport;

  static Future<ScreenShareChoice?> show(
    BuildContext context, {
    required rtc.DesktopCapturer capturer,
    required SystemAudioSupport audioSupport,
  }) => showDialog<ScreenShareChoice>(
    context: context,
    builder: (_) =>
        ScreenSourcePicker(capturer: capturer, audioSupport: audioSupport),
  );

  @override
  State<ScreenSourcePicker> createState() => _ScreenSourcePickerState();
}

class _ScreenSourcePickerState extends State<ScreenSourcePicker> {
  static const _thumbnailSize = (width: 320, height: 180);

  rtc.SourceType _type = rtc.SourceType.Screen;
  final _sources = <rtc.SourceType, List<rtc.DesktopCapturerSource>>{};
  final _loading = <rtc.SourceType>{};
  String? _selectedId;
  late bool _shareAudio =
      widget.audioSupport == SystemAudioSupport.excludesMeeting;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _refreshTimer;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    final capturer = widget.capturer;
    _subscriptions.addAll([
      capturer.onAdded.stream.listen((_) => _changed()),
      capturer.onRemoved.stream.listen((source) {
        if (source.id == _selectedId) _selectedId = null;
        _changed();
      }),
      capturer.onNameChanged.stream.listen((_) => _changed()),
    ]);
    unawaited(_load(_type));
    // Windows open and close while the picker is visible.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(capturer.updateSources(types: [_type])),
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load(rtc.SourceType type) async {
    if (!_loading.add(type)) return;
    try {
      final sources = await widget.capturer.getSources(
        types: [type],
        thumbnailSize: rtc.ThumbnailSize(
          _thumbnailSize.width,
          _thumbnailSize.height,
        ),
      );
      if (!mounted) return;
      setState(() {
        _sources[type] = sources;
        // Most people share their (only) screen; preselect the first one.
        if (_selectedId == null &&
            type == rtc.SourceType.Screen &&
            _type == type &&
            sources.isNotEmpty) {
          _selectedId = sources.first.id;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _sources[type] = const []);
    } finally {
      _loading.remove(type);
    }
  }

  void _selectType(rtc.SourceType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _selectedId = null;
    });
    unawaited(_load(type));
  }

  /// Selects at once; a second click on the same item shares it. (InkWell's
  /// onDoubleTap would delay every single click.)
  void _tap(String id) {
    final now = DateTime.now();
    final last = _lastTap;
    _lastTap = now;
    if (id == _selectedId &&
        last != null &&
        now.difference(last) < const Duration(milliseconds: 400)) {
      _share(id);
      return;
    }
    setState(() => _selectedId = id);
  }

  void _share([String? sourceId]) {
    final id = sourceId ?? _selectedId;
    if (id == null) return;
    Navigator.pop(
      context,
      ScreenShareChoice(
        sourceId: id,
        shareAudio:
            widget.audioSupport != SystemAudioSupport.none && _shareAudio,
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final sources = _sources[_type];
    return Dialog(
      backgroundColor: _surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.screen_share_rounded, color: _accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.selectScreenToShare,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.cancel,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<rtc.SourceType>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: _card,
                  foregroundColor: Colors.white70,
                  selectedBackgroundColor: _accent,
                  selectedForegroundColor: Colors.white,
                  side: BorderSide.none,
                ),
                segments: [
                  ButtonSegment(
                    value: rtc.SourceType.Screen,
                    icon: const Icon(Icons.desktop_windows_rounded),
                    label: Text(l10n.screen),
                  ),
                  ButtonSegment(
                    value: rtc.SourceType.Window,
                    icon: const Icon(Icons.web_asset_rounded),
                    label: Text(l10n.window),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (value) => _selectType(value.single),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: sources == null
                    ? const _CenteredBox(child: CircularProgressIndicator())
                    : sources.isEmpty
                    ? _CenteredBox(
                        child: Text(
                          l10n.noShareSources,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    : _SourceGrid(
                        sources: sources,
                        selectedId: _selectedId,
                        labelFor: (source, index) =>
                            source.type == rtc.SourceType.Screen
                            ? '${l10n.screen} ${index + 1}'
                            : source.name,
                        onTap: _tap,
                      ),
              ),
              if (widget.audioSupport != SystemAudioSupport.none) ...[
                const SizedBox(height: 12),
                _AudioOption(
                  value: _shareAudio,
                  hint: switch (widget.audioSupport) {
                    SystemAudioSupport.includesMeeting =>
                      l10n.shareSystemAudioEchoHint,
                    _ when _type == rtc.SourceType.Window =>
                      l10n.shareSystemAudioWindowHint,
                    _ => l10n.shareSystemAudioScreenHint,
                  },
                  onChanged: (value) => setState(() => _shareAudio = value),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const ValueKey('screen-picker-share'),
                    onPressed: _selectedId == null ? null : _share,
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    icon: const Icon(Icons.screen_share_rounded),
                    label: Text(l10n.share),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredBox extends StatelessWidget {
  const _CenteredBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 220, child: Center(child: child));
}

class _SourceGrid extends StatelessWidget {
  const _SourceGrid({
    required this.sources,
    required this.selectedId,
    required this.labelFor,
    required this.onTap,
  });

  final List<rtc.DesktopCapturerSource> sources;
  final String? selectedId;
  final String Function(rtc.DesktopCapturerSource source, int index) labelFor;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 240).floor().clamp(1, 4);
        return GridView.builder(
          shrinkWrap: true,
          itemCount: sources.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            // A 16:9 preview plus one line of text.
            childAspectRatio: 16 / 11,
          ),
          itemBuilder: (context, index) {
            final source = sources[index];
            return _SourceTile(
              key: ValueKey('screen-source-${source.id}'),
              source: source,
              label: labelFor(source, index),
              selected: source.id == selectedId,
              onTap: () => onTap(source.id),
            );
          },
        );
      },
    );
  }
}

class _SourceTile extends StatefulWidget {
  const _SourceTile({
    super.key,
    required this.source,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final rtc.DesktopCapturerSource source;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SourceTile> createState() => _SourceTileState();
}

class _SourceTileState extends State<_SourceTile> {
  Uint8List? _thumbnail;
  StreamSubscription<Uint8List>? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant _SourceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.source, widget.source)) {
      unawaited(_subscription?.cancel());
      _listen();
    }
  }

  void _listen() {
    final thumbnail = widget.source.thumbnail;
    _thumbnail = thumbnail != null && thumbnail.isNotEmpty ? thumbnail : null;
    try {
      _subscription = widget.source.onThumbnailChanged.stream.listen(
        (thumbnail) => setState(() => _thumbnail = thumbnail),
      );
    } on UnimplementedError {
      _subscription = null;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Material(
      color: selected ? _accent.withValues(alpha: 0.18) : _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? _accent : Colors.transparent,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(
                    color: Colors.black,
                    child: _thumbnail == null
                        ? const Icon(
                            Icons.image_outlined,
                            color: Colors.white24,
                            size: 32,
                          )
                        : Image.memory(
                            _thumbnail!,
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      color: _accent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioOption extends StatelessWidget {
  const _AudioOption({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final bool value;
  final String hint;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: SwitchListTile(
        key: const ValueKey('screen-picker-audio'),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: _accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        secondary: const Icon(Icons.volume_up_rounded, color: Colors.white70),
        title: Text(
          AppLocalizations.of(context)!.shareSystemAudio,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(hint, style: const TextStyle(color: Colors.white54)),
      ),
    );
  }
}
