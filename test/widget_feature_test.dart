import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:timora/features/widget/data/models/widget_data.dart';

void main() {
  group('Timora Widget Feature Tests', () {
    test('WidgetScheduleItem serialization and deserialization', () {
      const item = WidgetScheduleItem(
        id: 'act-101',
        title: 'Deep Work & Study',
        timeStr: '9:00 AM – 11:30 AM',
        startMillis: 1725346800000,
        endMillis: 1725355800000,
        isCompleted: true,
      );

      final jsonMap = item.toJson();
      expect(jsonMap['id'], 'act-101');
      expect(jsonMap['title'], 'Deep Work & Study');
      expect(jsonMap['timeStr'], '9:00 AM – 11:30 AM');
      expect(jsonMap['isCompleted'], true);

      final restored = WidgetScheduleItem.fromJson(jsonMap);
      expect(restored.id, item.id);
      expect(restored.title, item.title);
      expect(restored.timeStr, item.timeStr);
      expect(restored.startMillis, item.startMillis);
      expect(restored.endMillis, item.endMillis);
      expect(restored.isCompleted, true);
    });

    test('WidgetData full serialization round-trip', () {
      final data = WidgetData(
        currentTaskId: 'task-1',
        currentTaskTitle: 'AI Research Paper',
        currentTaskTime: '10:00 AM – 12:00 PM',
        nextTaskId: 'task-2',
        nextTaskTitle: 'Team Standup',
        nextTaskTime: '12:30 PM',
        completedTasksCount: 3,
        totalTasksCount: 5,
        progressPercentage: 60,
        focusActive: true,
        focusTitle: 'Deep Coding',
        focusRemainingSeconds: 1500,
        scheduleItems: const [
          WidgetScheduleItem(
            id: 'act-1',
            title: 'Morning Routine',
            timeStr: '8:00 AM – 9:00 AM',
            startMillis: 1000,
            endMillis: 2000,
            isCompleted: true,
          ),
          WidgetScheduleItem(
            id: 'act-2',
            title: 'AI Research Paper',
            timeStr: '10:00 AM – 12:00 PM',
            startMillis: 3000,
            endMillis: 4000,
            isCompleted: false,
          ),
        ],
        lastUpdatedMillis: 1725350000000,
      );

      final jsonStr = data.serialize();
      final decodedMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = WidgetData.fromJson(decodedMap);

      expect(restored.currentTaskId, 'task-1');
      expect(restored.currentTaskTitle, 'AI Research Paper');
      expect(restored.completedTasksCount, 3);
      expect(restored.totalTasksCount, 5);
      expect(restored.progressPercentage, 60);
      expect(restored.focusActive, true);
      expect(restored.focusTitle, 'Deep Coding');
      expect(restored.focusRemainingSeconds, 1500);
      expect(restored.scheduleItems.length, 2);
      expect(restored.scheduleItems[0].title, 'Morning Routine');
      expect(restored.scheduleItems[0].isCompleted, true);
      expect(restored.scheduleItems[1].title, 'AI Research Paper');
      expect(restored.scheduleItems[1].isCompleted, false);
    });

    test('WidgetData handles empty and null state gracefully', () {
      final empty = WidgetData(
        lastUpdatedMillis: DateTime.now().millisecondsSinceEpoch,
      );

      final jsonStr = empty.serialize();
      final restored = WidgetData.fromJson(jsonDecode(jsonStr));

      expect(restored.currentTaskId, isEmpty);
      expect(restored.currentTaskTitle, isEmpty);
      expect(restored.completedTasksCount, 0);
      expect(restored.totalTasksCount, 0);
      expect(restored.progressPercentage, 0);
      expect(restored.focusActive, false);
      expect(restored.scheduleItems, isEmpty);
    });

    test('Progress percentage calculation accuracy', () {
      int calculateProgress(int completed, int total) {
        return total > 0 ? ((completed / total) * 100).round() : 0;
      }

      expect(calculateProgress(0, 0), 0);
      expect(calculateProgress(0, 5), 0);
      expect(calculateProgress(1, 5), 20);
      expect(calculateProgress(3, 5), 60);
      expect(calculateProgress(5, 5), 100);
      expect(calculateProgress(5, 7), 71); // 71.4% -> 71%
    });
  });
}
