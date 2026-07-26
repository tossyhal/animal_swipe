// test/animal_images_notifier_test.dart
import 'dart:async';

import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/providers/animal_providers.dart';
import 'package:animal_swipe/services/api_service.dart'
    show IApiService, apiServiceProvider;
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テスト用データを返すダミーの ApiService
class FakeApiService implements IApiService {
  /// fetchImages が呼ばれた回数
  int callCount = 0;

  /// 直近に要求された動物タイプ
  List<String>? lastRequestedTypes;

  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) async {
    callCount++;
    lastRequestedTypes = List<String>.of(types);
    // 各動物タイプごとに1件のダミーデータを返す。
    // 追加読み込みで重複排除されないよう、呼び出し回数を URL に含める。
    return types.map((type) => _image(type, callCount)).toList();
  }
}

AnimalImage _image(String type, int seq) => AnimalImage(
  id: '$type-$seq',
  url: 'http://example.com/$type-$seq.jpg',
  type: type,
);

/// 常に空リストを返す ApiService
class EmptyApiService implements IApiService {
  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) async => [];
}

/// 常に例外を投げる ApiService
class FailingApiService implements IApiService {
  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) async =>
      throw Exception('network down');
}

/// 応答を任意のタイミングまで保留できる ApiService。
/// 「リクエスト中に選択が変わる」競合状態を決定的に再現するために使う。
class DeferredApiService implements IApiService {
  final _pending = <Completer<List<AnimalImage>>>[];

  int get pendingCount => _pending.length;

  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) {
    final completer = Completer<List<AnimalImage>>();
    _pending.add(completer);
    return completer.future;
  }

  /// 保留中の最初のリクエストに、指定タイプの画像を1件ずつ返す
  void completeFirstWith(List<String> types, {int seq = 1}) {
    _pending.removeAt(0).complete(
      types.map((type) => _image(type, seq)).toList(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnimalImagesNotifier テスト', () {
    late PrefsService prefsService;

    /// 選択済みタイプと ApiService を差し替えた [ProviderContainer] を作る
    ///
    /// animalImagesProvider は autoDispose なので、購読者がいないと read 直後に
    /// 破棄されてしまう。画面が表示され続けている状況を再現するため、
    /// ダミーの listen で生存させる。
    ProviderContainer createContainer(IApiService apiService) {
      final container = ProviderContainer(
        overrides: [
          prefsServiceProvider.overrideWithValue(prefsService),
          apiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);
      container.listen(animalImagesProvider, (_, _) {}, fireImmediately: true);
      return container;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'selected_animal_types': ['cat', 'dog'],
      });
      prefsService = PrefsService(await SharedPreferences.getInstance());
    });

    test('初回 watch で自動的に画像が読み込まれる', () async {
      final container = createContainer(FakeApiService());

      // build() が走る前は loading
      expect(container.read(animalImagesProvider), isA<AsyncLoading<void>>());

      final images = await container.read(animalImagesProvider.future);

      // 選択した動物タイプごとに1件ずつ返るため、件数は2件であるはず
      expect(images.length, 2);
      expect(container.read(animalImagesProvider).hasValue, isTrue);
    });

    test('トップ画像の削除後、必要なら追加読み込みが実行される', () async {
      final api = FakeApiService();
      final container = createContainer(api);
      await container.read(animalImagesProvider.future);

      final notifier = container.read(animalImagesProvider.notifier);
      final initialLength = container.read(animalImagesProvider).requireValue
          .length;

      notifier.removeTopImage();

      // 残り1件は閾値(3)未満なので追加読み込みが走る
      await Future<void>.delayed(Duration.zero);
      final after = container.read(animalImagesProvider).requireValue;
      expect(after.length, greaterThanOrEqualTo(initialLength - 1));
      expect(api.callCount, greaterThan(1), reason: '追加読み込みが呼ばれること');
    });

    /// build() の失敗を待ち、その AsyncError を返す
    Future<AsyncValue<List<AnimalImage>>> awaitError(
      ProviderContainer container,
    ) async {
      try {
        await container.read(animalImagesProvider.future);
      } on Object {
        // build() が投げるのは想定どおり
      }
      return container.read(animalImagesProvider);
    }

    test('取得結果が 0 件ならエラー状態になる', () async {
      final container = createContainer(EmptyApiService());

      final state = await awaitError(container);

      expect(state.hasError, isTrue);
      expect(state.error, isA<EmptyResultException>());
    });

    test('通信に失敗したらエラー状態になる', () async {
      final container = createContainer(FailingApiService());

      final state = await awaitError(container);

      expect(state.hasError, isTrue);
      expect(state.error, isA<Exception>());
    });

    test('reload() でエラー状態から復帰できる', () async {
      // 1回目は失敗、2回目は成功する ApiService
      var shouldFail = true;
      final container = createContainer(_SwitchableApiService(() => shouldFail));

      expect((await awaitError(container)).hasError, isTrue);

      shouldFail = false;
      await container.read(animalImagesProvider.notifier).reload();

      final state = container.read(animalImagesProvider);
      expect(state.hasError, isFalse);
      expect(state.requireValue, isNotEmpty);
    });

    // リトライ待ちの間に選択が変わったら、その応答は捨てること。
    test('reload() 中に選択が変わったら結果を破棄する', () async {
      final api = DeferredApiService();
      final container = createContainer(api);

      // 初回読み込みを完了させる（cat + dog）
      final initial = container.read(animalImagesProvider.future);
      api.completeFirstWith(['cat', 'dog']);
      await initial;

      // reload を開始（応答は保留）
      final reloading = container.read(animalImagesProvider.notifier).reload();

      // 応答前に dog を外す → 再 build で新しい初回読み込みが走る
      container
          .read(selectedAnimalTypesProvider.notifier)
          .selectType('dog', false);
      container.read(animalImagesProvider);

      // 古い選択に対する reload の応答をいま返す
      api.completeFirstWith(['cat', 'dog'], seq: 2);
      await reloading;

      // 新しい選択の読み込みを完了させる
      api.completeFirstWith(['cat'], seq: 3);
      final images = await container.read(animalImagesProvider.future);

      expect(images.map((i) => i.type), ['cat']);
    });

    // スワイプ完了は 250ms 遅れて通知されるため、その間に再取得が完了して
    // 山札が入れ替わっていることがある。古い操作で新しい山札を削ってはいけない。
    //
    // ランダム画像 API は同じ画像を返し得るので、新旧の山札の先頭 URL が
    // 一致していても「同じ山札」とは限らない。ここでは意図的に
    // 同じ URL を返させ、世代トークンでのみ判別できることを確かめる。
    test('先頭 URL が同じでも入れ替わった山札への遅延スワイプは無視される', () async {
      final api = DeferredApiService();
      final container = createContainer(api);
      final notifier = container.read(animalImagesProvider.notifier);

      final initial = container.read(animalImagesProvider.future);
      api.completeFirstWith(['cat', 'dog']);
      await initial;
      // カード表示時点の世代を控える（画面がコールバックに持たせる値）
      final oldDeckToken = notifier.deckGeneration;

      // 再取得して山札を入れ替える。ただし先頭の画像は前回と同一 URL
      final reloading = notifier.reload();
      api.completeFirstWith(['cat', 'dog']);
      await reloading;

      final newDeck = container.read(animalImagesProvider).requireValue;
      expect(
        newDeck.first.url,
        'http://example.com/cat-1.jpg',
        reason: '新旧で先頭 URL が一致する状況を作っていること',
      );

      // ここで「古いカードのスワイプ完了」が遅れて届く
      final removed = notifier.removeTopImage(deckToken: oldDeckToken);

      expect(removed, isFalse, reason: 'URL は同じでも世代が違うので無視される');
      expect(
        container.read(animalImagesProvider).requireValue,
        newDeck,
        reason: '新しい山札が削られていないこと',
      );

      // 現在の世代での操作は通る
      expect(
        notifier.removeTopImage(deckToken: notifier.deckGeneration),
        isTrue,
      );
    });

    // invalidate すると Notifier ごと作り直されるため、インスタンス内の
    // カウンタでトークンを採番すると新旧で同じ値が再利用され、古い操作が
    // 新しい山札を通過してしまう。採番元がプロセス全体で単調増加すること。
    test('invalidate で Notifier が作り直されても山札トークンが再利用されない', () async {
      final container = createContainer(FakeApiService());

      await container.read(animalImagesProvider.future);
      final oldToken = container
          .read(animalImagesProvider.notifier)
          .deckGeneration;

      // StartScreen の「はじめる」相当。Notifier ごと作り直される
      container.invalidate(animalImagesProvider);
      await container.read(animalImagesProvider.future);
      final newNotifier = container.read(animalImagesProvider.notifier);

      expect(
        newNotifier.deckGeneration,
        greaterThan(oldToken),
        reason: '作り直し後のトークンは以前の値より必ず大きいこと',
      );
      expect(
        newNotifier.removeTopImage(deckToken: oldToken),
        isFalse,
        reason: '古い山札のトークンでは新しい山札を削れないこと',
      );
    });

    // 選択変更時に「維持」ではなく「リセットして取り直す」ことを仕様として固定する。
    // 外したはずの動物が残り続けるのはユーザーの意図に反するため。
    group('選択タイプが変わったときの挙動（意図的なリセット）', () {
      test('選択から外した動物の画像は残らない', () async {
        final api = FakeApiService();
        final container = createContainer(api);

        final before = await container.read(animalImagesProvider.future);
        expect(before.map((i) => i.type), containsAll(['cat', 'dog']));

        container
            .read(selectedAnimalTypesProvider.notifier)
            .selectType('dog', false);

        final after = await container.read(animalImagesProvider.future);
        expect(
          after.map((i) => i.type),
          everyElement('cat'),
          reason: '外した dog の画像は残らないこと',
        );
        expect(api.lastRequestedTypes, ['cat'], reason: '新しい選択で取得し直すこと');
      });

      test('選択を追加した場合も取得し直す', () async {
        SharedPreferences.setMockInitialValues({
          'selected_animal_types': ['cat'],
        });
        prefsService = PrefsService(await SharedPreferences.getInstance());

        final api = FakeApiService();
        final container = createContainer(api);

        expect((await container.read(animalImagesProvider.future)).length, 1);

        container
            .read(selectedAnimalTypesProvider.notifier)
            .selectType('dog', true);

        final after = await container.read(animalImagesProvider.future);
        expect(after.map((i) => i.type), ['cat', 'dog']);
      });

      test('スワイプ画面が居ない間のトグルは取得を発生させない', () async {
        final api = FakeApiService();
        // ここでは animalImagesProvider を購読しない（＝スワイプ画面が居ない状況）
        final container = ProviderContainer(
          overrides: [
            prefsServiceProvider.overrideWithValue(prefsService),
            apiServiceProvider.overrideWithValue(api),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        notifier.selectType('dog', false);
        notifier.selectType('dog', true);
        notifier.selectType('cat', false);
        await Future<void>.delayed(Duration.zero);

        expect(
          api.callCount,
          0,
          reason: 'StartScreen でのトグルは無駄な通信を発生させないこと',
        );
      });
    });

    test('エラー時に Riverpod の自動リトライが走らない', () async {
      final api = _CountingFailingApiService();
      final container = createContainer(api);

      expect((await awaitError(container)).hasError, isTrue);

      // 自動リトライが有効だとバックオフ後に再度 fetch されてしまう
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(api.callCount, 1, reason: '自動リトライは無効化されていること');
      expect(container.read(animalImagesProvider).hasError, isTrue);
    });

    // Notifier のフィールドを late final にすると、依存の変化で build() が
    // 再実行された際に LateInitializationError になる。その回帰を防ぐ。
    test('選択タイプが変わると再取得され、例外にならない', () async {
      final api = FakeApiService();
      final container = createContainer(api);

      expect((await container.read(animalImagesProvider.future)).length, 2);

      // 選択を変更して animalImagesProvider の再 build を発生させる
      container
          .read(selectedAnimalTypesProvider.notifier)
          .selectType('dog', false);

      final images = await container.read(animalImagesProvider.future);
      expect(images.map((i) => i.type), ['cat']);
      expect(api.lastRequestedTypes, ['cat']);
    });

    // 追加読み込みの応答が、選択変更後の state を汚染しないこと。
    test('選択変更前に開始した追加読み込みの結果は破棄される', () async {
      final api = DeferredApiService();
      final container = createContainer(api);

      // 初回読み込みを完了させる（cat + dog）
      final initial = container.read(animalImagesProvider.future);
      api.completeFirstWith(['cat', 'dog']);
      expect((await initial).length, 2);

      // 追加読み込みを開始（まだ応答は返さない）
      final more = container.read(animalImagesProvider.notifier)
          .loadMoreImages();
      expect(api.pendingCount, 1);

      // 応答が返る前に dog を外す → animalImagesProvider が再 build される
      container
          .read(selectedAnimalTypesProvider.notifier)
          .selectType('dog', false);
      // 再 build を確定させる（新しい初回読み込みが発行される）
      container.read(animalImagesProvider);

      // 古い選択（cat + dog）に対する追加読み込みの応答をいま返す
      api.completeFirstWith(['cat', 'dog'], seq: 2);
      await more;

      // 新しい選択の初回読み込みを完了させる
      api.completeFirstWith(['cat'], seq: 3);
      final images = await container.read(animalImagesProvider.future);

      // 古い応答は捨てられ、外したはずの dog が混ざらないこと
      expect(images.map((i) => i.type), ['cat']);
    });
  });
}

/// 常に失敗し、呼ばれた回数を数える ApiService
class _CountingFailingApiService implements IApiService {
  int callCount = 0;

  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) async {
    callCount++;
    throw Exception('network down');
  }
}

/// 呼び出しごとに成功/失敗を切り替えられる ApiService
class _SwitchableApiService implements IApiService {
  final bool Function() _shouldFail;

  _SwitchableApiService(this._shouldFail);

  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) async {
    if (_shouldFail()) throw Exception('network down');
    return types.map((type) => _image(type, 1)).toList();
  }
}
