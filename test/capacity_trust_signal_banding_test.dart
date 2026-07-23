import 'package:flutter_test/flutter_test.dart';
import 'package:capacify/core/models/capacity_model.dart';

/// The trust signals on a `capacities` document are world-readable, and so is
/// the `companies` collection they are snapshotted from. Storing them EXACTLY
/// let anyone join a post back against the directory and name an anonymous
/// poster — a rating sum of 47 over 11 reviews is a fingerprint, not an
/// aggregate. These tests pin the two properties that fix relies on:
///
///  1. Coarsening — many companies collapse onto the same stored value.
///  2. Never overstating — a band only ever moves against the poster, so the
///     displayed signal stays honest.
void main() {
  group('bandRatingCount', () {
    test('floors onto a shared band once there are enough reviews', () {
      expect(CapacityModel.bandRatingCount(5), 5);
      expect(CapacityModel.bandRatingCount(7), 5);
      expect(CapacityModel.bandRatingCount(12), 10);
      expect(CapacityModel.bandRatingCount(20), 20);
      expect(CapacityModel.bandRatingCount(23), 20);
      expect(CapacityModel.bandRatingCount(60), 50);
      expect(CapacityModel.bandRatingCount(150), 100);
    });

    test('leaves counts below the first band exact', () {
      // Rounding 3 up to "5+" would overstate, which is the one thing a trust
      // signal must never do.
      for (var n = 0; n < 5; n++) {
        expect(CapacityModel.bandRatingCount(n), n);
      }
    });

    test('never reports more reviews than the company actually has', () {
      for (var n = 0; n <= 250; n++) {
        expect(CapacityModel.bandRatingCount(n), lessThanOrEqualTo(n));
      }
    });

    test('distinct counts collapse onto shared bands', () {
      // The whole point: 12, 15 and 19 reviews are indistinguishable once
      // stored, so the count alone can no longer single a company out.
      final banded =
          [12, 15, 19].map(CapacityModel.bandRatingCount).toSet();
      expect(banded, hasLength(1));
    });
  });

  group('bandRatingSum', () {
    test('stores a sum whose ratio is the half-star floor of the real average',
        () {
      // 47/11 = 4.27… → floor to 4.0, paired with the banded count of 10.
      expect(CapacityModel.bandRatingSum(47, 11), 40);
      expect(CapacityModel.bandRatingCount(11), 10);

      // 46/10 = 4.6 → 4.5.
      expect(CapacityModel.bandRatingSum(46, 10), 45);
    });

    test('is zero when there are no ratings', () {
      expect(CapacityModel.bandRatingSum(0, 0), 0);
      expect(CapacityModel.bandRatingSum(10, 0), 0);
    });

    test('never reports a higher average than the company actually has', () {
      for (var count = 1; count <= 120; count++) {
        for (final stars in [1, 3, 4, 5]) {
          final sum = stars * count;
          final bandedSum = CapacityModel.bandRatingSum(sum, count);
          final bandedCount = CapacityModel.bandRatingCount(count);
          if (bandedCount == 0) continue;
          expect(
            bandedSum / bandedCount,
            lessThanOrEqualTo(sum / count + 1e-9),
            reason: 'count=$count sum=$sum overstated the average',
          );
        }
      }
    });

    test('exact sums that differ collapse onto the same stored pair', () {
      // 4.6 and 4.9 average, different exact sums, same band — so the sum is
      // no longer a usable join key.
      final a = (
        CapacityModel.bandRatingSum(46, 10),
        CapacityModel.bandRatingCount(10)
      );
      final b = (
        CapacityModel.bandRatingSum(49, 10),
        CapacityModel.bandRatingCount(10)
      );
      expect(a, b);
    });
  });

  group('bandResponseHours', () {
    test('raises to the next band ceiling', () {
      expect(CapacityModel.bandResponseHours(1), 2);
      expect(CapacityModel.bandResponseHours(3), 4);
      expect(CapacityModel.bandResponseHours(8), 8);
      expect(CapacityModel.bandResponseHours(9), 24);
      expect(CapacityModel.bandResponseHours(50), 72);
      // Past the last band: whole days, rounded up.
      expect(CapacityModel.bandResponseHours(73), 96);
      expect(CapacityModel.bandResponseHours(100), 120);
    });

    test('passes null through — no samples means no signal', () {
      expect(CapacityModel.bandResponseHours(null), isNull);
    });

    test('never claims a poster is faster than they are', () {
      for (var h = 1; h <= 200; h++) {
        expect(CapacityModel.bandResponseHours(h), greaterThanOrEqualTo(h));
      }
    });
  });

  group('idempotence', () {
    // toFirestore() bands on every write, so an already-banded post that gets
    // re-serialized (or run through the admin backfill twice) must not drift.
    test('banding an already-banded value is a no-op', () {
      for (var count = 0; count <= 150; count++) {
        final sum = 4 * count;
        final bandedCount = CapacityModel.bandRatingCount(count);
        final bandedSum = CapacityModel.bandRatingSum(sum, count);
        expect(CapacityModel.bandRatingCount(bandedCount), bandedCount);
        expect(
          CapacityModel.bandRatingSum(bandedSum, bandedCount),
          bandedSum,
          reason: 're-banding drifted at count=$count',
        );
      }
      for (var h = 1; h <= 200; h++) {
        final banded = CapacityModel.bandResponseHours(h);
        expect(CapacityModel.bandResponseHours(banded), banded);
      }
    });
  });

  group('posterRatingCountDisplay', () {
    CapacityModel modelWith(int count) => CapacityModel(
          id: 'x',
          type: CapacityType.offer,
          status: CapacityStatus.active,
          availabilityType: AvailabilityType.now,
          title: '',
          description: '',
          trade: 'Trockenbau',
          location: 'Hamburg-Altona',
          workerCount: 1,
          availableFrom: DateTime(2026, 1, 1),
          availableTo: DateTime(2026, 2, 1),
          posterRatingCount: count,
        );

    test('marks a banded count with "+" and leaves small counts bare', () {
      expect(modelWith(3).posterRatingCountDisplay, '3');
      expect(modelWith(10).posterRatingCountDisplay, '10+');
      expect(modelWith(50).posterRatingCountDisplay, '50+');
    });
  });
}
