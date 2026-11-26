import 'package:material_ui/material_ui.dart';
import 'package:v_meeting/widgets/glass.dart';

/// The meeting's windows are less round than the rest of the app.
const meetingWindowRadius = 14.0;

/// Opens a glass dialog for the meeting, with its squarer corners.
Future<T?> showMeetingDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGlassDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) {
      final theme = Theme.of(context);
      return Theme(
        data: theme.copyWith(
          dialogTheme: theme.dialogTheme.copyWith(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(meetingWindowRadius),
              side: const BorderSide(color: glassStroke),
            ),
          ),
        ),
        child: builder(context),
      );
    },
  );
}
