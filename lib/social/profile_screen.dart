import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/social/avatar_picker.dart';
import 'package:v_meeting/social/presence_avatar.dart';
import 'package:v_meeting/social/social_actions.dart';
import 'package:v_meeting/social/social_api.dart';
import 'package:v_meeting/social/social_models.dart';
import 'package:v_meeting/widgets/glass.dart';

/// Opens the profile: a window in the middle on a computer, a screen of
/// its own on a phone.
void showProfile(BuildContext context, SocialProfile profile) {
  if (MediaQuery.sizeOf(context).width >= 840) {
    showGlassDialog<void>(
      context: context,
      builder: (context) => Dialog(
        key: const ValueKey('profile-dialog'),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 520,
          height: 720,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.myProfile,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const CloseButton(),
                  ],
                ),
              ),
              Expanded(
                child: ProfileView(
                  profile: profile,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(profile: profile)),
    );
  }
}

/// The profile as a screen of its own, on a phone.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.profile});

  final SocialProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.myProfile)),
      body: GlassBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ProfileView(profile: profile),
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's own profile: how they show to friends and teams.
class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({
    super.key,
    required this.profile,
    this.padding = const EdgeInsets.fromLTRB(0, 12, 0, 24),
  });

  final SocialProfile profile;
  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  late final _displayName = TextEditingController(
    text: widget.profile.displayName,
  );
  late final _status = TextEditingController(
    text: widget.profile.statusMessage,
  );
  late var _presence = widget.profile.presence;
  bool _saving = false;
  bool _uploading = false;

  /// Chooses a new profile photo, or, when there is one, offers to remove
  /// it instead.
  Future<void> _changePhoto(bool hasPhoto) async {
    final l10n = AppLocalizations.of(context)!;
    final api = ref.read(socialApiProvider);
    if (hasPhoto) {
      final choose = await showDialog<bool>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(l10n.profilePhoto),
          children: [
            SimpleDialogOption(
              key: const ValueKey('photo-choose'),
              onPressed: () => Navigator.pop(context, true),
              child: ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(l10n.choosePhoto),
              ),
            ),
            SimpleDialogOption(
              key: const ValueKey('photo-remove'),
              onPressed: () => Navigator.pop(context, false),
              child: ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: Text(l10n.removePhoto),
              ),
            ),
          ],
        ),
      );
      if (choose == null || !mounted) return;
      if (!choose) {
        await runSocialAction(context, ref, api.deleteAvatar);
        return;
      }
    }
    final messenger = ScaffoldMessenger.of(context);
    Uint8List? photo;
    try {
      photo = await pickProfilePicture();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(localizeError(error, l10n))),
      );
      return;
    }
    if (photo == null || !mounted) return;
    setState(() => _uploading = true);
    final saved = await runSocialAction(
      context,
      ref,
      () => api.uploadAvatar(photo!),
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoSaved)));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final saved = await runSocialAction(
      context,
      ref,
      () => ref
          .read(socialApiProvider)
          .updateProfile(
            displayName: _displayName.text,
            statusMessage: _status.text,
            presence: _presence,
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
      navigator.maybePop();
    }
  }

  @override
  void dispose() {
    _displayName.dispose();
    _status.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profile = widget.profile;
    // The photo as it is now: it changes here, after the profile opened.
    final avatarUrl =
        ref.watch(socialOverviewProvider).value?.profile.avatarUrl ??
        profile.avatarUrl;
    return ListView(
      padding: widget.padding,
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PresenceAvatar(
                name: _displayName.text.isEmpty
                    ? profile.nick
                    : _displayName.text,
                seed: profile.nick,
                presence: _presence,
                avatarUrl: avatarUrl,
                size: 104,
              ),
              if (_uploading)
                const Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              Positioned(
                left: -6,
                bottom: -2,
                child: GlassIconButton(
                  key: const ValueKey('profile-avatar-edit'),
                  size: 38,
                  iconSize: 18,
                  tint: brandColor,
                  icon: Icons.photo_camera_rounded,
                  onPressed: _uploading
                      ? null
                      : () => _changePhoto(avatarUrl.isNotEmpty),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '@${profile.nick}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: glassMuted),
        ),
        const SizedBox(height: 12),
        GlassSection(
          radius: 14,
          title: l10n.editProfile,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                spacing: 14,
                children: [
                  TextField(
                    key: const ValueKey('profile-display-name'),
                    controller: _displayName,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.displayName,
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                  ),
                  TextField(
                    key: const ValueKey('profile-status'),
                    controller: _status,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: l10n.statusMessage,
                      prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        GlassSection(
          radius: 14,
          title: l10n.presenceTitle,
          children: [
            for (final presence in const [
              Presence.online,
              Presence.busy,
              Presence.offline,
            ])
              ListTile(
                key: ValueKey('presence-${presence.name}'),
                leading: Icon(Icons.circle, color: presence.color),
                title: Text(presence.label(l10n)),
                trailing: _presence == presence
                    ? const Icon(Icons.check_rounded, color: glassAccent)
                    : null,
                onTap: () => setState(() => _presence = presence),
              ),
          ],
        ),
        GlassSection(
          radius: 14,
          title: l10n.account,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded),
              title: Text(l10n.shareProfile),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => showSocialComingSoon(context),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GlassButton(
            radius: 12,
            key: const ValueKey('profile-save'),
            tint: brandColor,
            icon: Icons.check_rounded,
            label: l10n.saveProfile,
            onPressed: _saving ? null : _save,
          ),
        ),
      ],
    );
  }
}
