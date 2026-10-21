import 'package:flutter_test/flutter_test.dart';
import 'package:unimarket/config/campus_policy.dart';

void main() {
  test(
    'student branches and roll numbers may vary; case and spaces normalize',
    () {
      for (final roll in [
        'CB.SC.U4CSE24157',
        'CB.SC.U4ECE25001',
        'CB.SC.U4MECH23123',
        'CB.SC.U4EEE24123',
      ]) {
        expect(CampusPolicy.rollError(roll), isNull);
        expect(
          CampusPolicy.emailError(
            ' ${roll.toLowerCase()}@cb.students.edu ',
            roll: roll,
          ),
          isNull,
        );
      }
      expect(CampusPolicy.department(' cb.sc.u4mech23123 '), 'MECH');
    },
  );
  test(
    'reject non-campus domain, wrong campus, malformed roll and mismatched email',
    () {
      for (final email in [
        '',
        'a@gmail.com',
        'CB.SC.U4CSE24157@cb.students.edu.evil.com',
        'CB.SC.U4CSE24157@students.edu',
        'CB.SC.U4CSE24157@@cb.students.edu',
        'AM.SC.U4CSE24157@cb.students.edu',
      ]) {
        expect(CampusPolicy.emailError(email), isNotNull);
      }
      for (final roll in ['', 'CSE24157', 'CB.SC.U4CSE', 'CB.SC.U4CSE24!157']) {
        expect(CampusPolicy.rollError(roll), isNotNull);
      }
      expect(
        CampusPolicy.emailError(
          'cb.sc.u4cse24157@cb.students.edu',
          roll: 'CB.SC.U4ECE24157',
        ),
        isNotNull,
      );
    },
  );
}
