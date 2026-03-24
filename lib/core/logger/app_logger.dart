import 'package:talker_flutter/talker_flutter.dart';

late final Talker talker;

void initTalker() {
  talker = TalkerFlutter.init(
    settings: TalkerSettings(useConsoleLogs: true, maxHistoryItems: 500),
  );
}
