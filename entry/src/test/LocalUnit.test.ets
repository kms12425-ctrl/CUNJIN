import { describe, it, expect } from '@ohos/hypium';

import {
  CardArrays, CardSettings, TaskCardData, WorkState, normalizeCards, normalizePunchCard,
  normalizeNotes, normalizeSettings, createDefaultSettings
} from '../main/ets/model/TaskCardData';
import { deserializeCards, serializeCards } from '../main/ets/model/CardCodec';
import { formatElapsedClock } from '../main/ets/model/TimeFormat';
import {
  LegacyCardRaw, decodeLegacyCards, isLegacySentinel, parseLegacyMatrix,
  parseLegacyNumberList, splitLegacyList
} from '../main/ets/model/LegacyCodec';
import {
  applyPunch, clampDayIndex, createPunchCard, creditDone, fromCards, relativeDaysPassed, toCards,
  moveCardToIndex, swapCardPositions, moveIdToIndex, swapIdPositions, appendPlaceholderId, removeIdAt,
  shiftIndexAfterDelete
} from '../main/ets/model/CardMapper';
import {
  connectedDate, doneValue, donePercentage, timeLeftPercentage, averageDailyWorkLeftForDisplay,
  averageDailyWork, todayBlockIndex, dateOfChosen
} from '../main/ets/model/CardQueries';
import {
  cardHoursOnDay, hoursOnDay, hoursInRecentDays, totalHours, currentStreak, activeDayCount,
  forecastCard
} from '../main/ets/model/CardStats';
import {
  EXPORT_FORMAT, buildExportText, parseExportText, exportFileName, preImportFileName
} from '../main/ets/model/ExportDocument';

const START: number = 1700000000000;

/** 备份测试用的两套配色（与页面默认值一致）。 */
const TEST_LIGHT: string[] = ['#5D1E3928', '#FFC1CFC6', '#FFFFFFFF', '#FF334C42', '#B0263F0F', '#FFE3ECE7'];
const TEST_DARK: string[] = ['#B3243930', '#FF1F2B26', '#FFC1CFC6', '#FFC1CFC6', '#80090E0B', '#FF3F5A4E'];

/** 生成一份含 2 张卡片 + 设置 + 计时状态的备份文本。 */
function exportFixture(): string {
  const cards: TaskCardData[] = [
    makeCard('idA', 'A', 'descA', 3, 1),
    makeCard('idB', 'B', 'descB', 7, 2)
  ];
  const settings = createDefaultSettings(TEST_LIGHT, TEST_DARK, 25, 450);
  const work: WorkState = {
    schemaVersion: 2, workingCardName: 'A', workStart: START, workLastEnd: START - 1000
  };
  return buildExportText(cards, settings, work, START);
}

function makeCard(id: string, name: string, desc: string, timeLimitDays: number, doneHours: number): TaskCardData {
  const card: TaskCardData = {
    id: id,
    name: name,
    desc: desc,
    length: 200,
    timeLimitDays: timeLimitDays,
    targetHours: 12,
    doneHours: doneHours,
    startAt: START,
    endAt: START + 86400000 * timeLimitDays,
    // 不变量：打卡数组长度必须等于 timeLimitDays + 1
    punchCard: createPunchCard(timeLimitDays),
    archived: false,
    // 备注与打卡数组等长（schema 5）
    notes: createPunchCard(timeLimitDays).map((_v: number) => '')
  };
  return card;
}

function makeLegacyFixture(): LegacyCardRaw {
  const raw: LegacyCardRaw = {
    cardsName: 'Alpha,Beta,Gamma',
    cardsDesc: 'first,second,third',
    cardsLength: '200,250,300',
    cardsTimeLimit: '21,7,3',
    cardsTarget: '12,6,2',
    cardsDone: '1.5,0,2.25',
    cardsStart: '1700000000000,1700000000000,1700000000000',
    cardsEnd: '1701814400000,1700604800000,1700259200000',
    cardsPunchCard: '1,0.5;0,0;2,2'
  };
  return raw;
}

/** 任务 A 回归用的三张卡片夹具（id 与名字一一对应，便于验证身份是否跟随）。 */
function threeCardsFixture(): TaskCardData[] {
  const cards: TaskCardData[] = [
    makeCard('idA', 'A', 'a', 3, 1),
    makeCard('idB', 'B', 'b', 3, 2),
    makeCard('idC', 'C', 'c', 3, 3)
  ];
  return cards;
}

/** 把数组视图里的卡片名拼成一行，便于断言顺序。 */
function cardNamesOf(arrays: CardArrays): string {
  return arrays.name.join(',');
}

function expectCardsEqual(actual: TaskCardData[], expected: TaskCardData[]): void {
  expect(actual.length).assertEqual(expected.length);
  for (let i = 0; i < expected.length; i++) {
    expect(actual[i].id).assertEqual(expected[i].id);
    expect(actual[i].name).assertEqual(expected[i].name);
    expect(actual[i].desc).assertEqual(expected[i].desc);
    expect(actual[i].length).assertEqual(expected[i].length);
    expect(actual[i].timeLimitDays).assertEqual(expected[i].timeLimitDays);
    expect(actual[i].targetHours).assertEqual(expected[i].targetHours);
    expect(actual[i].doneHours).assertEqual(expected[i].doneHours);
    expect(actual[i].startAt).assertEqual(expected[i].startAt);
    expect(actual[i].endAt).assertEqual(expected[i].endAt);
    expect(actual[i].punchCard.length).assertEqual(expected[i].punchCard.length);
  }
}

export default function localUnitTest() {
  describe('TaskCardCodec', () => {
    it('round_trips_plain_values', 0, () => {
      const cards: TaskCardData[] = [
        makeCard('c1', 'Alpha', 'first', 3, 1.25),
        makeCard('c2', 'Beta', 'second', 7, 0)
      ];
      const restored = deserializeCards(serializeCards(cards));
      expectCardsEqual(restored, cards);
    });

    it('round_trips_special_characters_in_name_and_desc', 0, () => {
      // 逗号 / 分号 / 双引号 / 换行 / emoji —— 旧版 CSV 下前两者会破坏结构
      const trickyName = 'a,b;c"d';
      const trickyDesc = 'line1\nline2\n😀 完成 50%, 剩余 50%;';
      const cards: TaskCardData[] = [makeCard('c1', trickyName, trickyDesc, 3, 2.5)];

      const restored = deserializeCards(serializeCards(cards));

      expect(restored.length).assertEqual(1);
      expect(restored[0].name).assertEqual(trickyName);
      expect(restored[0].desc).assertEqual(trickyDesc);
      expect(restored[0].doneHours).assertEqual(2.5);
    });

    it('deserializes_malformed_json_to_empty_without_throwing', 0, () => {
      expect(deserializeCards('not-json').length).assertEqual(0);
      expect(deserializeCards('').length).assertEqual(0);
      expect(deserializeCards('{"a":1}').length).assertEqual(0);
    });

    it('normalizes_punch_card_length_to_time_limit_plus_one', 0, () => {
      expect(normalizePunchCard([], 3).length).assertEqual(4);
      expect(normalizePunchCard([1, 2], 3).length).assertEqual(4);
      expect(normalizePunchCard([1, 2, 3, 4, 5, 6, 7], 3).length).assertEqual(4);
      expect(normalizePunchCard([], 3)[0]).assertEqual(0);
    });

    it('drops_cards_with_empty_name_and_repairs_nan', 0, () => {
      const broken: TaskCardData[] = [
        makeCard('c1', 'Keep', 'ok', 3, 1),
        makeCard('c2', '', 'no name', 3, 1)
      ];
      broken[0].doneHours = NaN;
      broken[0].targetHours = NaN;

      const fixed = normalizeCards(broken);
      expect(fixed.length).assertEqual(1);
      expect(fixed[0].name).assertEqual('Keep');
      expect(Number.isFinite(fixed[0].doneHours)).assertTrue();
      expect(fixed[0].doneHours).assertEqual(0);
      expect(Number.isFinite(fixed[0].targetHours)).assertTrue();
    });
  });

  describe('LegacyCodec', () => {
    it('parses_legacy_csv_lists_and_empty_values', 0, () => {
      expect(splitLegacyList('').length).assertEqual(0);
      expect(splitLegacyList(undefined).length).assertEqual(0);
      expect(splitLegacyList('a,b').length).assertEqual(2);
      expect(parseLegacyNumberList('1,2,3').length).assertEqual(3);
      expect(parseLegacyNumberList('1,2,3')[2]).assertEqual(3);
      // 旧版行为：空串 -> 空数组
      expect(parseLegacyNumberList('').length).assertEqual(0);
    });

    it('keeps_legacy_matrix_trailing_separator_semantics', 0, () => {
      expect(parseLegacyMatrix('').length).assertEqual(0);
      const m = parseLegacyMatrix('1,2;');
      expect(m.length).assertEqual(2);
      expect(m[0].length).assertEqual(2);
      expect(m[1].length).assertEqual(1);
      expect(m[1][0]).assertEqual(0);
    });

    it('migrates_nine_parallel_arrays_into_cards', 0, () => {
      const result = decodeLegacyCards(makeLegacyFixture(), START);
      expect(result.sentinelDetected).assertFalse();
      expect(result.cards.length).assertEqual(3);

      expect(result.cards[0].name).assertEqual('Alpha');
      expect(result.cards[0].desc).assertEqual('first');
      expect(result.cards[0].timeLimitDays).assertEqual(21);
      expect(result.cards[0].doneHours).assertEqual(1.5);
      expect(result.cards[0].targetHours).assertEqual(12);
      // punchCard 长度必须是 timeLimitDays + 1
      expect(result.cards[0].punchCard.length).assertEqual(22);
      expect(result.cards[0].punchCard[0]).assertEqual(1);
      expect(result.cards[0].punchCard[1]).assertEqual(0.5);

      expect(result.cards[2].name).assertEqual('Gamma');
      expect(result.cards[2].timeLimitDays).assertEqual(3);
      expect(result.cards[2].doneHours).assertEqual(2.25);
      expect(result.cards[2].punchCard.length).assertEqual(4);
    });

    it('migration_is_idempotent_when_run_twice', 0, () => {
      const first = decodeLegacyCards(makeLegacyFixture(), START);
      const second = decodeLegacyCards(makeLegacyFixture(), START);
      expect(second.cards.length).assertEqual(first.cards.length);
      expectCardsEqual(second.cards, first.cards);
    });

    it('reports_comma_corruption_instead_of_silently_losing_cards', 0, () => {
      // 旧版把 "Read,Book" 当成两张卡片写进 cards_name，但 desc 只有两项
      const corrupted: LegacyCardRaw = {
        cardsName: 'Read,Book,Write',
        cardsDesc: 'reading,writing',
        cardsLength: '200,250',
        cardsTimeLimit: '7,7',
        cardsTarget: '5,5',
        cardsDone: '1,1',
        cardsStart: '1700000000000,1700000000000',
        cardsEnd: '1700604800000,1700604800000',
        cardsPunchCard: '1;1'
      };
      const result = decodeLegacyCards(corrupted, START);
      // 不丢数据：按旧版当时的切分结果重建 3 张卡片
      expect(result.cards.length).assertEqual(3);
      expect(result.cards[0].name).assertEqual('Read');
      expect(result.cards[1].name).assertEqual('Book');
      expect(result.cards[2].name).assertEqual('Write');
      // 第 3 张没有对应 desc，用空串兜底而不是 undefined
      expect(result.cards[2].desc).assertEqual('');
      // 必须给出可解释的警告
      expect(result.warnings.length > 0).assertTrue();
    });

    it('detects_all_sentinel_snapshot', 0, () => {
      const sentinel: LegacyCardRaw = {
        cardsName: 'no', cardsDesc: 'no', cardsLength: 'no', cardsTimeLimit: 'no',
        cardsTarget: 'no', cardsDone: 'no', cardsStart: 'no', cardsEnd: 'no',
        cardsPunchCard: 'no'
      };
      expect(isLegacySentinel(sentinel)).assertTrue();
      const result = decodeLegacyCards(sentinel, START);
      expect(result.sentinelDetected).assertTrue();
      expect(result.cards.length).assertEqual(0);
    });

    it('does_not_treat_real_card_named_no_as_sentinel', 0, () => {
      const real: LegacyCardRaw = {
        cardsName: 'no', cardsDesc: 'a real card', cardsLength: '200',
        cardsTimeLimit: '7', cardsTarget: '5', cardsDone: '1',
        cardsStart: '1700000000000', cardsEnd: '1700604800000',
        cardsPunchCard: '1'
      };
      expect(isLegacySentinel(real)).assertFalse();
      const result = decodeLegacyCards(real, START);
      expect(result.cards.length).assertEqual(1);
      expect(result.cards[0].name).assertEqual('no');
    });
  });

  describe('CardMapper', () => {
    it('round_trips_arrays_and_models', 0, () => {
      const cards: TaskCardData[] = [
        makeCard('c1', 'Alpha', 'first', 3, 1.5),
        makeCard('c2', 'Beta', 'second', 7, 0)
      ];
      const arrays: CardArrays = fromCards(cards);
      const ids: string[] = ['c1', 'c2'];
      const back = toCards(arrays, ids, START);
      expectCardsEqual(back, cards);
    });

    it('apply_punch_is_immutable_and_accumulates', 0, () => {
      const rows: number[][] = [[0, 0, 0], [1, 1, 1]];
      const next = applyPunch(rows, 0, 1, 2.5);

      expect(next === rows).assertFalse();
      expect(next[0] === rows[0]).assertFalse();
      expect(rows[0][1]).assertEqual(0);      // 原数组未被修改
      expect(next[0][1]).assertEqual(2.5);

      const again = applyPunch(next, 0, 1, 0.5);
      expect(again[0][1]).assertEqual(3);
      expect(next[0][1]).assertEqual(2.5);
    });

    it('apply_punch_ignores_out_of_range_and_non_finite', 0, () => {
      const rows: number[][] = [[0, 0]];
      expect(applyPunch(rows, -1, 0, 1)[0][0]).assertEqual(0);
      expect(applyPunch(rows, 5, 0, 1)[0][0]).assertEqual(0);
      expect(applyPunch(rows, 0, 0, NaN)[0][0]).assertEqual(0);
      // 越界天数被夹到最后一格，而不是写入 NaN 索引
      expect(applyPunch(rows, 0, 99, 2)[0][1]).assertEqual(2);
    });

    it('credit_done_is_immutable_and_guards_index', 0, () => {
      const done: number[] = [1, 2];
      const next = creditDone(done, 0, 0.5);
      expect(next === done).assertFalse();
      expect(done[0]).assertEqual(1);
      expect(next[0]).assertEqual(1.5);

      // 这正是旧版 WORK_end_card 的丢数据路径：index = -1
      const guarded = creditDone(done, -1, 10);
      expect(guarded.length).assertEqual(2);
      expect(guarded[0]).assertEqual(1);
      expect(guarded[1]).assertEqual(2);
    });

    it('create_punch_card_has_limit_plus_one_cells', 0, () => {
      expect(createPunchCard(0).length).assertEqual(1);
      expect(createPunchCard(3).length).assertEqual(4);
      expect(createPunchCard(21).length).assertEqual(22);
    });

    it('clamps_day_index_within_bounds', 0, () => {
      expect(clampDayIndex(-5, 4)).assertEqual(0);
      expect(clampDayIndex(0, 4)).assertEqual(0);
      expect(clampDayIndex(3, 4)).assertEqual(3);
      expect(clampDayIndex(9, 4)).assertEqual(3);
      expect(clampDayIndex(NaN, 4)).assertEqual(0);
    });

    it('relative_days_matches_legacy_formula', 0, () => {
      expect(relativeDaysPassed(START, START)).assertEqual(0);
      expect(relativeDaysPassed(START, START + 86400000)).assertEqual(1);
      expect(relativeDaysPassed(START, START + 86400000 * 5 + 1000)).assertEqual(5);
    });
  });

  describe('P0Regression', () => {
    it('reloading_does_not_duplicate_done_hours', 0, () => {
      const cards: TaskCardData[] = [
        makeCard('c1', 'Alpha', 'first', 3, 1.5),
        makeCard('c2', 'Beta', 'second', 7, 2)
      ];

      // 旧版 onPageShow 用 push 加载 cards_done，第二次显示会翻倍。
      // 新版加载是"投影"：重复执行结果完全相同。
      const first = fromCards(cards);
      const second = fromCards(cards);

      expect(second.doneHours.length).assertEqual(first.doneHours.length);
      expect(second.doneHours[0]).assertEqual(first.doneHours[0]);
      expect(second.doneHours[1]).assertEqual(first.doneHours[1]);
      expect(second.name.length).assertEqual(2);
    });

    it('repeated_projection_after_ten_cycles_stays_stable', 0, () => {
      const cards: TaskCardData[] = [makeCard('c1', 'Alpha', 'first', 3, 7.25)];
      let state: CardArrays = fromCards(cards);
      for (let i = 0; i < 10; i++) {
        state = fromCards(cards);
      }
      expect(state.doneHours.length).assertEqual(1);
      expect(state.doneHours[0]).assertEqual(7.25);
    });

    it('add_edit_delete_reorder_keeps_fields_aligned', 0, () => {
      let arrays: CardArrays = fromCards([
        makeCard('c1', 'A', 'a', 3, 1),
        makeCard('c2', 'B', 'b', 3, 2)
      ]);
      let ids: string[] = ['c1', 'c2'];

      // ---- 新增 ----
      arrays.name.push('C');
      arrays.desc.push('c');
      arrays.length.push(200);
      arrays.timeLimitDays.push(3);
      arrays.targetHours.push(12);
      arrays.doneHours.push(0);
      arrays.startAt.push(START);
      arrays.endAt.push(START + 86400000 * 3);
      arrays.punchCard.push(createPunchCard(3));
      ids = appendPlaceholderId(ids);

      let cards = toCards(arrays, ids, START);
      expect(cards.length).assertEqual(3);
      expect(cards[2].name).assertEqual('C');
      expect(cards[2].doneHours).assertEqual(0);
      expect(cards[2].punchCard.length).assertEqual(4);
      // 新增后：前两张保持原 id，第三张拿到非空的新 id
      expect(cards[0].id).assertEqual('c1');
      expect(cards[1].id).assertEqual('c2');
      expect(cards[2].id.length > 0).assertTrue();
      // 模拟 persistCards() 落盘后回填 cardIds
      ids = [cards[0].id, cards[1].id, cards[2].id];
      const idC = ids[2];

      // ---- 编辑 ----
      arrays.name[1] = 'B2';
      arrays.desc[1] = 'b2';
      arrays.length[1] = 320;
      cards = toCards(arrays, ids, START);
      expect(cards[1].name).assertEqual('B2');
      expect(cards[1].desc).assertEqual('b2');
      expect(cards[1].length).assertEqual(320);
      expect(cards[0].name).assertEqual('A');   // 未错位
      expect(cards[1].id).assertEqual('c2');    // 编辑不改变身份

      // ---- 排序：把第 3 张("C")移到最前 ----
      // 排序前：['A','B2','C']  ->  排序后：['C','A','B2']
      arrays = moveCardToIndex(arrays, 2, 0);
      ids = moveIdToIndex(ids, 2, 0);

      cards = toCards(arrays, ids, START);
      expect(cards[0].name).assertEqual('C');
      expect(cards[1].name).assertEqual('A');
      expect(cards[2].name).assertEqual('B2');
      expect(cards[2].length).assertEqual(320);  // 字段跟着卡片一起移动
      expect(cards[2].doneHours).assertEqual(2);
      // 身份必须跟着卡片一起移动（旧版按下标配对，这里会串位）
      expect(cards[0].id).assertEqual(idC);
      expect(cards[1].id).assertEqual('c1');
      expect(cards[2].id).assertEqual('c2');

      // ---- 删除第 2 张("A") ----
      // 删除后：['C','B2']
      arrays.name.splice(1, 1);
      arrays.desc.splice(1, 1);
      arrays.length.splice(1, 1);
      arrays.timeLimitDays.splice(1, 1);
      arrays.targetHours.splice(1, 1);
      arrays.doneHours.splice(1, 1);
      arrays.startAt.splice(1, 1);
      arrays.endAt.splice(1, 1);
      arrays.punchCard.splice(1, 1);
      ids = removeIdAt(ids, 1);

      cards = toCards(arrays, ids, START);
      expect(cards.length).assertEqual(2);
      expect(cards[0].name).assertEqual('C');
      expect(cards[1].name).assertEqual('B2');
      expect(cards[1].doneHours).assertEqual(2);
      expect(cards[1].length).assertEqual(320);
      // 删除后幸存的卡片保持各自 id
      expect(cards[0].id).assertEqual(idC);
      expect(cards[1].id).assertEqual('c2');
    });

    it('new_card_starts_with_zero_done_hours', 0, () => {
      // 旧版因为 cards_done 加载时重复 push，新增卡片会继承错误的 done 值
      const arrays: CardArrays = fromCards([makeCard('c1', 'A', 'a', 3, 4)]);
      arrays.name.push('B');
      arrays.desc.push('b');
      arrays.length.push(200);
      arrays.timeLimitDays.push(3);
      arrays.targetHours.push(12);
      arrays.doneHours.push(0);
      arrays.startAt.push(START);
      arrays.endAt.push(START + 86400000 * 3);
      arrays.punchCard.push(createPunchCard(3));

      const cards = toCards(arrays, ['c1'], START);
      expect(cards[1].name).assertEqual('B');
      expect(cards[1].doneHours).assertEqual(0);
    });

    it('default_settings_are_valid_for_first_run', 0, () => {
      const settings = createDefaultSettings(
        ['#5D1E3928', '#FFC1CFC6', '#FFFFFFFF', '#FF334C42', '#B0263F0F', '#FFE3ECE7'],
        ['#B3243930', '#FF1F2B26', '#FFC1CFC6', '#FFC1CFC6', '#80090E0B', '#FF3F5A4E'],
        25, 450);
      expect(settings.colorSchemeLight.length).assertEqual(6);
      expect(settings.colorSchemeDark.length).assertEqual(6);
      expect(settings.blurRadius).assertEqual(25);
      expect(settings.minCardSize).assertEqual(450);
      expect(settings.useBackdrop).assertFalse();
      expect(settings.appOpenTime).assertEqual(0);
    });
  });

  // -------------------------------------------------------------------------
  // 任务 A 回归：换位（排序）必须落盘，且 id 身份必须跟着卡片一起移动
  //
  // 纯函数层验证「换位 -> 保存 -> 重新读取」的完整往返。覆盖：
  // 单次置顶、连续多次不同换位、交换位置、全部字段跟随、
  // id 身份跟随、增删后的 id 对齐、越界与不可变性。
  // -------------------------------------------------------------------------
  describe('ReorderPersistence', () => {
    it('single_move_to_top_survives_save_and_reload', 0, () => {
      const arrays = moveCardToIndex(fromCards(threeCardsFixture()), 2, 0);
      const ids = moveIdToIndex(['idA', 'idB', 'idC'], 2, 0);

      // 保存 -> 序列化 -> 重新解析 -> 投影回数组，等价于"重启后重新加载"
      const saved = toCards(arrays, ids, START);
      const back = fromCards(deserializeCards(serializeCards(saved)));

      expect(back.name.length).assertEqual(3);
      expect(back.name[0]).assertEqual('C');
      expect(back.name[1]).assertEqual('A');
      expect(back.name[2]).assertEqual('B');
      // 其他字段必须跟着卡片一起移动，不能错位
      expect(back.doneHours[0]).assertEqual(3);
      expect(back.doneHours[1]).assertEqual(1);
      expect(back.desc[0]).assertEqual('c');
    });

    it('multiple_different_moves_keep_consistent_order', 0, () => {
      let arrays = fromCards([
        makeCard('idA', 'A', 'a', 3, 0),
        makeCard('idB', 'B', 'b', 3, 0),
        makeCard('idC', 'C', 'c', 3, 0),
        makeCard('idD', 'D', 'd', 3, 0)
      ]);
      let ids: string[] = ['idA', 'idB', 'idC', 'idD'];

      // [A,B,C,D] -> 把 B 移到末尾 -> [A,C,D,B]
      arrays = moveCardToIndex(arrays, 1, 3);
      ids = moveIdToIndex(ids, 1, 3);
      expect(cardNamesOf(arrays)).assertEqual('A,C,D,B');

      // -> 再置顶 B -> [B,A,C,D]
      arrays = moveCardToIndex(arrays, 3, 0);
      ids = moveIdToIndex(ids, 3, 0);
      expect(cardNamesOf(arrays)).assertEqual('B,A,C,D');

      // -> 把 C 前移一位 -> [B,C,A,D]
      arrays = moveCardToIndex(arrays, 2, 1);
      ids = moveIdToIndex(ids, 2, 1);
      expect(cardNamesOf(arrays)).assertEqual('B,C,A,D');

      // 三轮换位后仍必须完整往返，且 id 仍与卡片对应
      const reloaded = deserializeCards(serializeCards(toCards(arrays, ids, START)));
      expect(cardNamesOf(fromCards(reloaded))).assertEqual('B,C,A,D');
      expect(reloaded.length).assertEqual(4);
      expect(reloaded[0].id).assertEqual('idB');
      expect(reloaded[1].id).assertEqual('idC');
      expect(reloaded[2].id).assertEqual('idA');
      expect(reloaded[3].id).assertEqual('idD');
    });

    it('swap_positions_survives_save_and_reload', 0, () => {
      const arrays = swapCardPositions(fromCards(threeCardsFixture()), 0, 2);
      const ids = swapIdPositions(['idA', 'idB', 'idC'], 0, 2);
      const back = fromCards(deserializeCards(serializeCards(toCards(arrays, ids, START))));
      expect(cardNamesOf(back)).assertEqual('C,B,A');
      expect(back.doneHours[0]).assertEqual(3);
      expect(back.doneHours[2]).assertEqual(1);
    });

    it('reorder_moves_every_field_and_id_with_its_card', 0, () => {
      // 四张卡的 timeLimitDays / punchCard 长度各不相同，
      // 便于检出"只搬了名字"或"只搬了部分数组"这类错位。
      let arrays = fromCards([
        makeCard('idA', 'A', 'a', 3, 1),
        makeCard('idB', 'B', 'b', 7, 2),
        makeCard('idC', 'C', 'c', 21, 3),
        makeCard('idD', 'D', 'd', 5, 4)
      ]);
      let ids: string[] = ['idA', 'idB', 'idC', 'idD'];

      // 把 C(下标 2) 移到最前 —— 与 Index.ets「置顶」同一条路径
      arrays = moveCardToIndex(arrays, 2, 0);
      ids = moveIdToIndex(ids, 2, 0);

      const saved = toCards(arrays, ids, START);

      // id 必须跟着卡片走（toCards 按下标配对，ids 不位移就会串位）
      expect(saved[0].id).assertEqual('idC');
      expect(saved[1].id).assertEqual('idA');
      expect(saved[2].id).assertEqual('idB');
      expect(saved[3].id).assertEqual('idD');

      // 9 个字段整体跟随：抽查最容易被漏掉的两个
      expect(saved[0].name).assertEqual('C');
      expect(saved[0].desc).assertEqual('c');
      expect(saved[0].timeLimitDays).assertEqual(21);
      expect(saved[0].doneHours).assertEqual(3);
      expect(saved[0].punchCard.length).assertEqual(22);  // 21 + 1
      expect(saved[1].name).assertEqual('A');
      expect(saved[1].timeLimitDays).assertEqual(3);
      expect(saved[1].punchCard.length).assertEqual(4);   // 3 + 1

      // 长度不变量：9 个数组与 id 列表等长
      expect(arrays.name.length).assertEqual(arrays.punchCard.length);
      expect(arrays.name.length).assertEqual(arrays.doneHours.length);
      expect(ids.length).assertEqual(arrays.name.length);

      // 落盘/重读后顺序与 id 都稳定
      const reloaded = deserializeCards(serializeCards(saved));
      expect(reloaded.length).assertEqual(4);
      expect(reloaded[0].id).assertEqual('idC');
      expect(reloaded[0].name).assertEqual('C');
      expect(reloaded[0].timeLimitDays).assertEqual(21);
    });

    it('delete_keeps_survivor_ids', 0, () => {
      let arrays = fromCards([makeCard('idA', 'A', 'a', 3, 0), makeCard('idB', 'B', 'b', 3, 0)]);
      let ids: string[] = ['idA', 'idB'];

      // 新增 C
      arrays.name.push('C');
      arrays.desc.push('c');
      arrays.length.push(200);
      arrays.timeLimitDays.push(3);
      arrays.targetHours.push(12);
      arrays.doneHours.push(0);
      arrays.startAt.push(START);
      arrays.endAt.push(START + 86400000 * 3);
      arrays.punchCard.push(createPunchCard(3));
      ids = appendPlaceholderId(ids);

      let cards = toCards(arrays, ids, START);
      const idC = cards[2].id;                        // 记住生成的 id
      expect(idC.length > 0).assertTrue();
      // 模拟 persistCards() 落盘后回填 cardIds
      ids = [cards[0].id, cards[1].id, cards[2].id];

      // 删除中间那张 B
      arrays.name.splice(1, 1);
      arrays.desc.splice(1, 1);
      arrays.length.splice(1, 1);
      arrays.timeLimitDays.splice(1, 1);
      arrays.targetHours.splice(1, 1);
      arrays.doneHours.splice(1, 1);
      arrays.startAt.splice(1, 1);
      arrays.endAt.splice(1, 1);
      arrays.punchCard.splice(1, 1);
      ids = removeIdAt(ids, 1);

      cards = toCards(arrays, ids, START);
      expect(cards.length).assertEqual(2);
      expect(cards[0].name).assertEqual('A');
      expect(cards[0].id).assertEqual('idA');
      expect(cards[1].name).assertEqual('C');
      expect(cards[1].id).assertEqual(idC);           // 幸存者保持自己的 id
    });

    it('reorder_is_immutable_and_ignores_invalid_index', 0, () => {
      const original = fromCards(threeCardsFixture());
      const moved = moveCardToIndex(original, 1, 0);

      // 不可变：原对象不被修改
      expect(original.name[0]).assertEqual('A');
      expect(moved.name[0]).assertEqual('B');
      expect(moved.name === original.name).assertFalse();

      // 越界必须是安全的 no-op，而不是静默打乱
      expect(moveCardToIndex(original, 5, 0).name[0]).assertEqual('A');
      expect(moveCardToIndex(original, 0, 99).name[0]).assertEqual('A');
      expect(moveCardToIndex(original, -1, 0).name[0]).assertEqual('A');
      expect(moveCardToIndex(original, 1, 1).name[1]).assertEqual('B');
      expect(swapCardPositions(original, 0, 9).name[0]).assertEqual('A');
      // id 列表同样受保护
      expect(moveIdToIndex(['a', 'b'], 0, 9)[0]).assertEqual('a');
      expect(removeIdAt(['a', 'b'], 5).length).assertEqual(2);
    });

    it('reorder_then_add_keeps_all_cards_unique', 0, () => {
      // 换位后再新增：既不能丢卡片，也不能产生重复 id
      let arrays = moveCardToIndex(fromCards(threeCardsFixture()), 2, 0);   // C,A,B
      let ids = moveIdToIndex(['idA', 'idB', 'idC'], 2, 0);                 // idC,idA,idB

      arrays.name.push('D');
      arrays.desc.push('d');
      arrays.length.push(200);
      arrays.timeLimitDays.push(3);
      arrays.targetHours.push(12);
      arrays.doneHours.push(0);
      arrays.startAt.push(START);
      arrays.endAt.push(START + 86400000 * 3);
      arrays.punchCard.push(createPunchCard(3));
      ids = appendPlaceholderId(ids);

      const cards = toCards(arrays, ids, START);
      expect(cards.length).assertEqual(4);
      expect(cards[0].name).assertEqual('C');
      expect(cards[1].name).assertEqual('A');
      expect(cards[2].name).assertEqual('B');
      expect(cards[3].name).assertEqual('D');

      // id 全部唯一
      const seen: string[] = [];
      for (let i = 0; i < cards.length; i++) {
        expect(seen.indexOf(cards[i].id)).assertEqual(-1);
        seen.push(cards[i].id);
      }
    });
  });

  // -------------------------------------------------------------------------
  // 计时显示：把"已进行毫秒"格式化成秒级时钟
  //
  // 背景：原来进行中显示的是"小时 + 2 位小数"，分辨率 36 秒，
  // 按下开始后前 18 秒必然一直是 0.00，看起来像没在计时。
  // 这里只改显示精度，不改变 (now - workStart) 的计时模型。
  // -------------------------------------------------------------------------
  describe('ElapsedClock', () => {
    it('formats_sub_hour_as_mm_ss', 0, () => {
      expect(formatElapsedClock(0)).assertEqual('00:00');
      expect(formatElapsedClock(999)).assertEqual('00:00');       // 未满 1 秒不跳字
      expect(formatElapsedClock(1000)).assertEqual('00:01');
      expect(formatElapsedClock(5000)).assertEqual('00:05');
      expect(formatElapsedClock(59000)).assertEqual('00:59');
      expect(formatElapsedClock(60000)).assertEqual('01:00');
      expect(formatElapsedClock(599000)).assertEqual('09:59');
      expect(formatElapsedClock(3599000)).assertEqual('59:59');
    });

    it('formats_hour_and_above_as_h_mm_ss', 0, () => {
      expect(formatElapsedClock(3600000)).assertEqual('1:00:00');
      expect(formatElapsedClock(3661000)).assertEqual('1:01:01');
      expect(formatElapsedClock(7200000)).assertEqual('2:00:00');
      expect(formatElapsedClock(36000000)).assertEqual('10:00:00');
      expect(formatElapsedClock(45296000)).assertEqual('12:34:56');
    });

    it('changes_visibly_every_second', 0, () => {
      // 关键回归：相邻两秒必须产生不同的字符串，否则又会"看起来卡住"
      for (let s = 0; s < 120; s++) {
        const a = formatElapsedClock(s * 1000);
        const b = formatElapsedClock((s + 1) * 1000);
        expect(a === b).assertFalse();
      }
      // 进位边界抽查
      expect(formatElapsedClock(59000)).assertEqual('00:59');
      expect(formatElapsedClock(60000)).assertEqual('01:00');
      expect(formatElapsedClock(3599000)).assertEqual('59:59');
      expect(formatElapsedClock(3600000)).assertEqual('1:00:00');
    });

    it('never_ticks_before_a_full_second_and_never_goes_backwards', 0, () => {
      // 同一秒内的多次刷新必须稳定（避免每秒刷新多次时闪烁）
      expect(formatElapsedClock(1000)).assertEqual(formatElapsedClock(1999));
      expect(formatElapsedClock(61000)).assertEqual(formatElapsedClock(61999));
      // 分钟进位正确
      expect(formatElapsedClock(119000)).assertEqual('01:59');
      expect(formatElapsedClock(120000)).assertEqual('02:00');
      expect(formatElapsedClock(3599999)).assertEqual('59:59');
      expect(formatElapsedClock(3600001)).assertEqual('1:00:00');
    });

    it('handles_invalid_input_defensively', 0, () => {
      expect(formatElapsedClock(-5000)).assertEqual('00:00');
      expect(formatElapsedClock(-1)).assertEqual('00:00');
      expect(formatElapsedClock(NaN)).assertEqual('00:00');
      expect(formatElapsedClock(Infinity)).assertEqual('00:00');
      expect(formatElapsedClock(-Infinity)).assertEqual('00:00');
    });
  });

  // -------------------------------------------------------------------------
  // 编辑卡片的提交路径：数据层不变量
  //
  // 编辑面板的提交动作（Index.EDIT_commit_card）最终就是「改 9 个数组的同一列 ->
  // toCards() -> saveCards()」。这里直接验证这层的数据语义：
  //   - 改名/改描述/改长度后，卡片 id 不变（否则身份漂移）；
  //   - 其他卡片一个字段都不能动；
  //   - 连续编辑两张不同卡片，不发生数组错位。
  // UI 交互本身（打开/取消/重开）无法在本地单测覆盖，不做伪造。
  // -------------------------------------------------------------------------
  describe('CardEdit', () => {
    it('editing_one_card_keeps_its_id_and_leaves_others_untouched', 0, () => {
      const original: TaskCardData[] = [
        makeCard('idA', 'A', 'descA', 3, 1),
        makeCard('idB', 'B', 'descB', 7, 2),
        makeCard('idC', 'C', 'descC', 5, 3)
      ];
      const ids: string[] = ['idA', 'idB', 'idC'];
      let arrays: CardArrays = fromCards(original);

      // 模拟编辑第 2 张（下标 1）：改名 + 改描述 + 改长度（200~400）
      arrays.name[1] = 'B-RENAMED';
      arrays.desc[1] = 'DESC-RENAMED';
      arrays.length[1] = 350;

      const saved = toCards(arrays, ids, START);

      // ① 被编辑的卡片：id 不变，三个字段已更新
      expect(saved[1].id).assertEqual('idB');
      expect(saved[1].name).assertEqual('B-RENAMED');
      expect(saved[1].desc).assertEqual('DESC-RENAMED');
      expect(saved[1].length).assertEqual(350);

      // ② 其他两张卡片：逐字段完全不变
      expectCardsEqual([saved[0]], [original[0]]);
      expectCardsEqual([saved[2]], [original[2]]);

      // ③ 落盘/重读后仍然如此
      const reloaded = deserializeCards(serializeCards(saved));
      expect(reloaded.length).assertEqual(3);
      expect(reloaded[1].id).assertEqual('idB');
      expect(reloaded[1].name).assertEqual('B-RENAMED');
      expect(reloaded[0].id).assertEqual('idA');
      expect(reloaded[2].name).assertEqual('C');
    });

    it('editing_two_cards_in_a_row_does_not_misalign_arrays', 0, () => {
      const ids: string[] = ['idA', 'idB', 'idC'];
      let arrays: CardArrays = fromCards([
        makeCard('idA', 'A', 'descA', 3, 1),
        makeCard('idB', 'B', 'descB', 7, 2),
        makeCard('idC', 'C', 'descC', 5, 3)
      ]);

      // 第一次编辑：第 0 张
      arrays.name[0] = 'A1';
      arrays.desc[0] = 'dA1';
      arrays.length[0] = 210;
      let saved = toCards(arrays, ids, START);
      // 落盘后页面会把 ids 回填成保存结果，这里同样模拟
      const ids1: string[] = [saved[0].id, saved[1].id, saved[2].id];
      expect(ids1.join(',')).assertEqual('idA,idB,idC');

      // 第二次编辑：第 2 张（中间隔着一张，最容易检出错位）
      arrays = fromCards(saved);
      arrays.name[2] = 'C1';
      arrays.desc[2] = 'dC1';
      arrays.length[2] = 390;
      saved = toCards(arrays, ids1, START);

      // id 顺序不变、没有错位
      expect(saved[0].id).assertEqual('idA');
      expect(saved[1].id).assertEqual('idB');
      expect(saved[2].id).assertEqual('idC');

      // 两次编辑都保留了，且没有串到别的卡片上
      expect(saved[0].name).assertEqual('A1');
      expect(saved[0].length).assertEqual(210);
      expect(saved[1].name).assertEqual('B');
      expect(saved[1].desc).assertEqual('descB');
      expect(saved[1].length).assertEqual(200);
      expect(saved[2].name).assertEqual('C1');
      expect(saved[2].desc).assertEqual('dC1');
      expect(saved[2].length).assertEqual(390);

      // 整轮往返后依旧一致
      const reloaded = deserializeCards(serializeCards(saved));
      expect(reloaded.length).assertEqual(3);
      expect(reloaded[0].name).assertEqual('A1');
      expect(reloaded[1].name).assertEqual('B');
      expect(reloaded[2].name).assertEqual('C1');
      expect(reloaded[2].length).assertEqual(390);
    });
  });

  // -------------------------------------------------------------------------
  // 卡片查询纯函数（原 Index 的 CARD_get_* / UTIL_get_connected_date）
  //
  // 这些用例锁定的是**既有产品行为**：无限目标/无限期限的固定返回值、
  // 逾期与恰好到期的分界、除零、下标越界与打卡数据缺失。
  // 特殊常量（如时间进度用 864000）与特殊文案均按原实现断言，不做"修正"。
  // -------------------------------------------------------------------------
  describe('CardQueries', () => {
    it('done_value_caps_and_handles_unlimited_target', 0, () => {
      // 未完成：原样返回
      expect(doneValue(10, 3)).assertEqual(3);
      // 恰好完成
      expect(doneValue(10, 10)).assertEqual(10);
      // 超额：封顶到目标值
      expect(doneValue(10, 15)).assertEqual(10);
      // 无限目标：固定半程 500（先于超额判断返回）
      expect(doneValue(1001, 0)).assertEqual(500);
      expect(doneValue(1001, 9999)).assertEqual(500);
    });

    it('done_percentage_formats_and_handles_edges', 0, () => {
      expect(donePercentage(10, 5)).assertEqual('50.00 %');
      expect(donePercentage(3, 1)).assertEqual('33.33 %');
      expect(donePercentage(10, 0)).assertEqual('0.00 %');
      // 超额时百分比会超过 100，原实现不做截断
      expect(donePercentage(10, 15)).assertEqual('150.00 %');
      // 无限目标固定 "50 %"（注意：不是 50.00）
      expect(donePercentage(1001, 0)).assertEqual('50 %');
      // 目标为 0：原实现除以 0，得到 "Infinity %"（既有行为，锁定防漂移）
      expect(donePercentage(0, 5)).assertEqual('Infinity %');
      // 目标与进度都为 0：0/0 = NaN
      expect(donePercentage(0, 0)).assertEqual('NaN %');
    });

    it('time_left_percentage_boundaries', 0, () => {
      const day = 86400000;
      // 无限期限固定 "50 %"
      expect(timeLeftPercentage(367, START + day, START)).assertEqual('50 %');
      // 恰好到期：不满足 <0，走正常分支 -> "0.00 %"
      expect(timeLeftPercentage(10, START, START)).assertEqual('0.00 %');
      // 已逾期：整 0 %
      expect(timeLeftPercentage(10, START - day, START)).assertEqual('0 %');
      // 正常：剩余 = 10 * 864000 毫秒 -> 1.00 %
      expect(timeLeftPercentage(10, START + 864000 * 10, START)).assertEqual('1.00 %');
      // 正常：剩余一半 -> 0.50 %
      expect(timeLeftPercentage(10, START + 864000 * 5, START)).assertEqual('0.50 %');
    });

    it('average_daily_work_left_for_display_branches', 0, () => {
      // 已完成：颜文字
      expect(averageDailyWorkLeftForDisplay(10, 15, 7, 5)).assertEqual('( •̀ ω •́ )✧');
      // 剩余 0 天：固定 "1"
      expect(averageDailyWorkLeftForDisplay(10, 5, 7, 0)).assertEqual('1');
      // 无限期限
      expect(averageDailyWorkLeftForDisplay(10, 5, 367, 5)).assertEqual(' ∞ ');
      // 无限目标
      expect(averageDailyWorkLeftForDisplay(1001, 5, 7, 5)).assertEqual(' ∞ ');
      // 正常：(10-4)/3 = 2，保留 4 位
      expect(averageDailyWorkLeftForDisplay(10, 4, 7, 3)).assertEqual('2.0000');
      expect(averageDailyWorkLeftForDisplay(10, 3, 7, 7)).assertEqual('1.0000');
    });

    it('average_daily_work_handles_infinite_goal', 0, () => {
      expect(averageDailyWork(100, 10)).assertEqual(10);
      expect(averageDailyWork(10, 367)).assertEqual(1);
      expect(averageDailyWork(1001, 10)).assertEqual(1);
      // 期限为 0 时原实现得到 Infinity，属既有行为
      expect(averageDailyWork(10, 0)).assertEqual(Infinity);
    });

    it('today_block_index_clamps_and_handles_missing_data', 0, () => {
      const day = 86400000;
      // 打卡数据缺失（下标越界 -> undefined）：返回 0
      expect(todayBlockIndex(undefined, START, START)).assertEqual(0);
      // 刚开始：相对天数 0
      expect(todayBlockIndex([0, 0, 0], START, START)).assertEqual(0);
      // 第 1 天，记录更长
      expect(todayBlockIndex([0, 0, 0, 0, 0], START - day, START)).assertEqual(1);
      // 第 5 天但只记录了 3 格：夹到最后一格下标 2
      expect(todayBlockIndex([0, 0, 0], START - 5 * day, START)).assertEqual(2);
      // 空数组：length-1 = -1，Math.min 得到 -1（原实现如此；正常数据不会出现空行）
      expect(todayBlockIndex([], START, START)).assertEqual(-1);
    });

    it('connected_date_formats_with_fullwidth_separator_and_unpadded_parts', 0, () => {
      const ts = START;
      const out = connectedDate(ts);
      expect(out.length).assertEqual(2);
      // 与本地 Date 的取值逐项一致（验证格式而非时区假设）
      const d = new Date(ts);
      expect(out[0]).assertEqual(d.getFullYear() + '／' + (d.getMonth() + 1) + '／' + d.getDate());
      expect(out[1]).assertEqual(d.getDay().toString());
      // 分隔符必须是全角
      expect(out[0].indexOf('／') > 0).assertTrue();
      // 星期几取值必须在 0..6
      const weekday = Number(out[1]);
      expect(weekday >= 0 && weekday <= 6).assertTrue();
      // 不同时间戳得到不同日期文本（相隔一天）
      const next = connectedDate(ts + 86400000);
      expect(next[0] == out[0]).assertFalse();
    });

    it('date_of_chosen_offsets_by_whole_days', 0, () => {
      const day = 86400000;
      // 选中第 0 格 = 起始日
      expect(dateOfChosen(START, 0)[0]).assertEqual(connectedDate(START)[0]);
      expect(dateOfChosen(START, 0)[1]).assertEqual(connectedDate(START)[1]);
      // 选中第 2 格 = 起始日 + 2 天
      expect(dateOfChosen(START, 2)[0]).assertEqual(connectedDate(START + 2 * day)[0]);
      expect(dateOfChosen(START, 2)[1]).assertEqual(connectedDate(START + 2 * day)[1]);
    });
  });

  // -------------------------------------------------------------------------
  // 全局统计纯函数（统计面板的数据来源）
  //
  // 锁定的语义：
  //   · 不同 startAt 的卡片要按「绝对日」对齐后才能跨卡相加；
  //   · 今天是「起始日 + 第 i 天」，i 越界一律 0；
  //   · 连续天数从今天往前数，今天没有记录即中断；
  //   · 累计打卡天数跨卡去重；
  //   · NaN / 缺失行 / 负下标均忽略，不抛异常。
  // -------------------------------------------------------------------------
  describe('CardStats', () => {
    const DAY: number = 86400000;

    it('card_hours_on_day_is_bounds_safe', 0, () => {
      const row: number[] = [1, 2, 3];
      expect(cardHoursOnDay(row, 0)).assertEqual(1);
      expect(cardHoursOnDay(row, 2)).assertEqual(3);
      // 越界
      expect(cardHoursOnDay(row, 3)).assertEqual(0);
      // 负下标（卡片开始于未来）
      expect(cardHoursOnDay(row, -1)).assertEqual(0);
      // 数据缺失
      expect(cardHoursOnDay(undefined, 0)).assertEqual(0);
      // 空行
      expect(cardHoursOnDay([], 0)).assertEqual(0);
    });

    it('hours_on_day_aligns_cards_with_different_start_days', 0, () => {
      // A 从 START 开始：第 0/1/2 天 = 1/2/0
      // B 从 START 前一天开始：第 0/1 天 = 0/5（它的第 1 天正是 START 当天）
      const punch: number[][] = [[1, 2, 0], [0, 5]];
      const starts: number[] = [START, START - DAY];
      // START 当天：A 第 0 天(1) + B 第 1 天(5)
      expect(hoursOnDay(punch, starts, START)).assertEqual(6);
      // START 前一天：A 第 -1 天(0) + B 第 0 天(0)
      expect(hoursOnDay(punch, starts, START - DAY)).assertEqual(0);
      // 空数据
      expect(hoursOnDay([], [], START)).assertEqual(0);
    });

    it('hours_in_recent_days_covers_the_window_inclusively', 0, () => {
      // 单卡从 START-2 天开始，第 0/1/2 天 = 1/2/3
      const punch: number[][] = [[1, 2, 3]];
      const starts: number[] = [START - 2 * DAY];
      // 今天 = 第 2 天 = 3
      expect(hoursOnDay(punch, starts, START)).assertEqual(3);
      // 最近 1 天 = 今天 = 3
      expect(hoursInRecentDays(punch, starts, START, 1)).assertEqual(3);
      // 最近 3 天 = 3+2+1
      expect(hoursInRecentDays(punch, starts, START, 3)).assertEqual(6);
      // 窗口大于记录长度：仍只算已有记录
      expect(hoursInRecentDays(punch, starts, START, 10)).assertEqual(6);
      // 非法天数
      expect(hoursInRecentDays(punch, starts, START, 0)).assertEqual(0);
      expect(hoursInRecentDays(punch, starts, START, -3)).assertEqual(0);
    });

    it('total_hours_sums_every_card', 0, () => {
      expect(totalHours([[1, 2], [3]])).assertEqual(6);
      expect(totalHours([])).assertEqual(0);
      expect(totalHours([[]])).assertEqual(0);
      // NaN 与空行忽略
      expect(totalHours([[NaN, 2], []])).assertEqual(2);
    });

    it('current_streak_counts_back_from_today', 0, () => {
      // 连续 3 天
      expect(currentStreak([[1, 1, 1]], [START - 2 * DAY], START)).assertEqual(3);
      // 今天没有记录 -> 0
      expect(currentStreak([[1, 1, 0]], [START - 2 * DAY], START)).assertEqual(0);
      // 昨天断了 -> 只算今天
      expect(currentStreak([[1, 0, 1]], [START - 2 * DAY], START)).assertEqual(1);
      // 中间有缺口：-3:1 -2:0 -1:1 0:1 -> 2
      expect(currentStreak([[1, 0, 1, 1]], [START - 3 * DAY], START)).assertEqual(2);
      // 空数据
      expect(currentStreak([], [], START)).assertEqual(0);
      expect(currentStreak([[]], [START], START)).assertEqual(0);
    });

    it('streak_is_bounded_by_record_length_not_infinite', 0, () => {
      // 记录只有 2 格，即使"看起来"连续更久也不能超过 2
      expect(currentStreak([[1, 1]], [START - DAY], START)).assertEqual(2);
    });

    it('archived_cards_can_be_excluded_from_stats', 0, () => {
      // 两张卡都在"今天"有记录：A=1, B=2
      const punch: number[][] = [[1], [2]];
      const starts: number[] = [START, START];
      const ids: string[] = ['idA', 'idB'];
      // 不传 id 列表时：保持原行为，合计 3
      expect(hoursOnDay(punch, starts, START)).assertEqual(3);
      expect(totalHours(punch)).assertEqual(3);
      expect(hoursInRecentDays(punch, starts, START, 7)).assertEqual(3);
      // 排除 B（归档）：只剩 A
      expect(hoursOnDay(punch, starts, START, ids, ['idB'])).assertEqual(1);
      expect(totalHours(punch, ids, ['idB'])).assertEqual(1);
      expect(hoursInRecentDays(punch, starts, START, 7, ids, ['idB'])).assertEqual(1);
      // 全部归档：今日合计 0、连续天数归零
      expect(hoursOnDay(punch, starts, START, ids, ['idA', 'idB'])).assertEqual(0);
      expect(currentStreak(punch, starts, START, ids, ['idA', 'idB'])).assertEqual(0);
      expect(currentStreak(punch, starts, START)).assertEqual(1);
      // 只给 cardIds 不给 skipIds：不排除（容错，不误删统计）
      expect(hoursOnDay(punch, starts, START, ids)).assertEqual(3);
    });

    it('active_day_count_dedupes_across_cards', 0, () => {
      // 两张卡同一天都有记录 -> 只算 1 天
      expect(activeDayCount([[1, 0, 0], [2, 0, 0]], [START, START])).assertEqual(1);
      // A: 第 0/1 天；B: 第 1/2 天 -> 并集 3 天
      expect(activeDayCount([[1, 1, 0], [0, 1, 1]], [START, START])).assertEqual(3);
      // 全 0 记录不算"有记录"
      expect(activeDayCount([[0, 0]], [START])).assertEqual(0);
      expect(activeDayCount([], [])).assertEqual(0);
    });
  });

  // -------------------------------------------------------------------------
  // 备份文档（导出 / 导入）的纯函数层
  //
  // 锁定的语义：
  //   · 导出再导入必须无损（卡片 / 设置原文 / 计时状态）；
  //   · 任何非法输入都返回 ok=false + 明确 reason，绝不抛异常、绝不返回"成功但空数据"；
  //   · 空卡片备份被**拒绝**（no-cards），避免误选空文件清空现有数据。
  // 文件选择与磁盘读写（repository/BackupFile.ets）依赖系统能力，本地单测无法覆盖。
  // -------------------------------------------------------------------------
  describe('ExportDocument', () => {
    it('export_then_import_round_trips_without_loss', 0, () => {
      const text = exportFixture();
      const parsed = parseExportText(text);
      expect(parsed.ok).assertTrue();
      expect(parsed.reason).assertEqual('ok');
      expect(parsed.cardCount).assertEqual(2);
      // 卡片内容与顺序保持
      expect(parsed.cards[0].id).assertEqual('idA');
      expect(parsed.cards[0].name).assertEqual('A');
      expect(parsed.cards[1].id).assertEqual('idB');
      expect(parsed.cards[1].timeLimitDays).assertEqual(7);
      // 设置原文非空（由调用方用自己的默认值反序列化）
      expect(parsed.settingsText.length > 0).assertTrue();
      // 计时状态被还原
      expect(parsed.work != undefined).assertTrue();
      if (parsed.work != undefined) {
        expect(parsed.work.workingCardName).assertEqual('A');
      }
    });

    it('export_text_carries_format_and_version', 0, () => {
      const text = exportFixture();
      expect(text.indexOf(EXPORT_FORMAT) >= 0).assertTrue();
      expect(text.indexOf('"version"') >= 0).assertTrue();
    });

    it('rejects_invalid_input_with_specific_reasons', 0, () => {
      expect(parseExportText('').reason).assertEqual('empty');
      expect(parseExportText('not a json at all').reason).assertEqual('not-json');
      expect(parseExportText('{"format":"something-else","version":1,"cards":"[]"}').reason)
        .assertEqual('wrong-format');
      expect(parseExportText('{"format":"' + EXPORT_FORMAT + '","version":99,"cards":"[]"}').reason)
        .assertEqual('unsupported-version');
      expect(parseExportText('{"format":"' + EXPORT_FORMAT + '","version":1}').reason)
        .assertEqual('missing-cards');
      // 全部失败都必须 ok=false
      expect(parseExportText('').ok).assertFalse();
      expect(parseExportText('not a json at all').ok).assertFalse();
    });

    it('refuses_empty_or_corrupt_card_payloads', 0, () => {
      // 声明格式正确但卡片为空 -> 拒绝，避免误清空
      expect(parseExportText('{"format":"' + EXPORT_FORMAT + '","version":1,"cards":"[]"}').reason)
        .assertEqual('no-cards');
      // 卡片 payload 损坏 -> 反序列化得到空数组 -> 同样按 no-cards 拒绝
      expect(parseExportText('{"format":"' + EXPORT_FORMAT + '","version":1,"cards":"{broken"}').reason)
        .assertEqual('no-cards');
    });

    it('export_file_name_is_deterministic', 0, () => {
      expect(exportFileName(1700000000000)).assertEqual('cunjin-backup-1700000000000.json');
    });

    it('pre_import_snapshot_name_is_distinct_from_manual_export', 0, () => {
      // 两者必须是不同前缀，避免沙箱里的自动快照与用户手动导出的备份混淆
      expect(preImportFileName(1700000000000)).assertEqual('cunjin-pre-import-1700000000000.json');
      expect(preImportFileName(1700000000000) == exportFileName(1700000000000)).assertFalse();
      // 自动快照同样能被 parseExportText 正常读回（同一套格式）
      const idleWork: WorkState = { schemaVersion: 2, workingCardName: '', workStart: 0, workLastEnd: 0 };
      const snapshot = buildExportText(
        [makeCard('idA', 'A', 'a', 3, 1)], createDefaultSettings(TEST_LIGHT, TEST_DARK, 25, 450),
        idleWork, START);
      expect(parseExportText(snapshot).ok).assertTrue();
      expect(parseExportText(snapshot).cardCount).assertEqual(1);
    });
  });

  // -------------------------------------------------------------------------
  // 归档字段（schema 2 -> 3）
  //
  // 锁定的语义：
  //   · 旧数据（没有 archived 字段）读入后一律视为未归档，不需要迁移代码；
  //   · archived 必须能经过 序列化 -> 反序列化 -> 规范化 完整存活；
  //   · 页面保存时用"已归档 id 列表"按键判定，不依赖下标，因此重排/增删都不会错位。
  // -------------------------------------------------------------------------
  describe('CardArchive', () => {
    it('old_data_without_archived_normalizes_to_false', 0, () => {
      // 模拟 schema 2 的老数据：JSON 里完全没有 archived 字段
      const raw = JSON.parse('[{"id":"x","name":"A","desc":"","length":200,"timeLimitDays":3,' +
        '"targetHours":12,"doneHours":0,"startAt":0,"endAt":0,"punchCard":[0,0,0,0]}]') as TaskCardData[];
      const normalized = normalizeCards(raw);
      expect(normalized.length).assertEqual(1);
      expect(normalized[0].archived).assertFalse();
    });

    it('archived_survives_serialize_and_deserialize', 0, () => {
      const cards = [makeCard('a', 'A', 'd', 3, 1), makeCard('b', 'B', 'd', 3, 1)];
      cards[1].archived = true;
      const back = normalizeCards(deserializeCards(serializeCards(cards)));
      expect(back.length).assertEqual(2);
      expect(back[0].archived).assertFalse();
      expect(back[1].archived).assertTrue();
    });

    it('to_cards_preserves_archived_flags_by_index', 0, () => {
      const arrays = fromCards([makeCard('a', 'A', 'd', 3, 1), makeCard('b', 'B', 'd', 3, 1)]);
      // 归档标记按下标投影
      arrays.archived = [false, true];
      const cards = toCards(arrays, ['a', 'b'], START);
      expect(cards[0].archived).assertFalse();
      expect(cards[1].archived).assertTrue();

      // 重排后标记跟着卡片一起走（不会因为下标变化而贴错卡）
      const swapped = swapCardPositions(arrays, 0, 1);
      const swappedCards = toCards(swapped, ['b', 'a'], START);
      expect(swappedCards[0].archived).assertTrue();
      expect(swappedCards[1].archived).assertFalse();

      // 标记数组缺失/更短时一律按未归档处理（容错）
      const missing = fromCards([makeCard('c', 'C', 'd', 3, 1)]);
      missing.archived = [];
      expect(toCards(missing, ['c'], START)[0].archived).assertFalse();
    });

    it('newly_added_card_is_never_archived', 0, () => {
      // 回归用例：新建卡片曾被误判为"已归档"（标题出现删除线/被隐藏）。
      // 根因是对比"已归档 id 旁表"，新卡片的占位 id（空串）会与旧 id 混淆；
      // 改成按下标投影后，新卡片只能继承 push 进来的 false。
      const arrays = fromCards([makeCard('a', 'A', 'd', 3, 1)]);
      arrays.archived = [true]; // 已有卡片已归档

      // 按 CARD_add_card 的顺序追加一张新卡片
      const idsWithPlaceholder = appendPlaceholderId(['a']);
      arrays.name.push('B');
      arrays.desc.push('');
      arrays.length.push(200);
      arrays.timeLimitDays.push(3);
      arrays.targetHours.push(12);
      arrays.doneHours.push(0);
      arrays.startAt.push(START);
      arrays.endAt.push(START + 3 * 86400000);
      arrays.punchCard.push(createPunchCard(3));
      arrays.notes.push(createPunchCard(3).map((_v: number) => ''));
      arrays.archived.push(false);

      const cards = toCards(arrays, idsWithPlaceholder, START);
      expect(cards.length).assertEqual(2);
      expect(cards[0].archived).assertTrue();
      // 新卡片必须是未归档 —— 这是用户报告的 bug
      expect(cards[1].archived).assertFalse();
      expect(cards[1].name).assertEqual('B');
    });

    it('hide_archived_switch_defaults_false_and_survives_round_trip', 0, () => {
      const defaults = createDefaultSettings(TEST_LIGHT, TEST_DARK, 25, 450);
      // 默认不隐藏
      expect(defaults.hideArchived).assertFalse();
      // schema 3 的老设置（完全没有 hideArchived 字段）-> 沿用兜底值
      const legacy = JSON.parse('{"schemaVersion":3,"useBackdrop":false,"colorSchemeLight":[],' +
        '"colorSchemeDark":[],"blurRadius":25,"minCardSize":450,"appOpenTime":0}') as CardSettings;
      expect(normalizeSettings(legacy, defaults).hideArchived).assertFalse();
      // 显式开启后，规范化不能把它丢掉
      defaults.hideArchived = true;
      const fresh = createDefaultSettings(TEST_LIGHT, TEST_DARK, 25, 450);
      expect(normalizeSettings(defaults, fresh).hideArchived).assertTrue();
      // 其它字段仍然按兜底值走（没有连带破坏）
      expect(normalizeSettings(defaults, fresh).minCardSize).assertEqual(450);
    });
  });

  // -------------------------------------------------------------------------
  // 每日备注（schema 4 -> 5）
  //
  // 锁定的语义：
  //   · notes 长度必须与 punchCard 一致（timeLimitDays + 1）；
  //   · 旧数据没有 notes 时补空串，不需要迁移代码；
  //   · 备注必须跟着卡片走：换位/移动后仍属于原来那张卡；
  //   · 序列化/反序列化后内容不变。
  // -------------------------------------------------------------------------
  describe('CardNotes', () => {
    it('normalize_notes_matches_punch_card_length', 0, () => {
      // 长度 = timeLimitDays + 1
      expect(normalizeNotes([], 3).length).assertEqual(4);
      expect(normalizeNotes([], 3)[0]).assertEqual('');
      // 已有值保留，缺的补空串
      const filled = normalizeNotes(['a', 'b'], 3);
      expect(filled.length).assertEqual(4);
      expect(filled[0]).assertEqual('a');
      expect(filled[1]).assertEqual('b');
      expect(filled[2]).assertEqual('');
      // 多了就截断
      expect(normalizeNotes(['1', '2', '3', '4', '5', '6'], 3).length).assertEqual(4);
      // 非法天数按最少 1 格处理
      expect(normalizeNotes([], 0).length).assertEqual(1);
    });

    it('notes_follow_their_card_through_arrays_and_reorder', 0, () => {
      const cards = [makeCard('a', 'A', 'd', 3, 1), makeCard('b', 'B', 'd', 3, 1)];
      cards[0].notes[0] = 'A 的第一天';
      cards[1].notes[0] = 'B 的第一天';

      const arrays: CardArrays = fromCards(cards);
      expect(arrays.notes[0][0]).assertEqual('A 的第一天');
      expect(arrays.notes[1][0]).assertEqual('B 的第一天');

      // 换位后备注必须跟着卡片一起走
      const swapped = swapCardPositions(arrays, 0, 1);
      expect(swapped.notes[0][0]).assertEqual('B 的第一天');
      expect(swapped.notes[1][0]).assertEqual('A 的第一天');

      // 移动位置同理
      const moved = moveCardToIndex(arrays, 0, 1);
      expect(moved.notes[0][0]).assertEqual('B 的第一天');
      expect(moved.notes[1][0]).assertEqual('A 的第一天');

      // 数组视图 -> 对象模型，备注不丢
      const back = toCards(arrays, ['a', 'b'], START);
      expect(back[0].notes[0]).assertEqual('A 的第一天');
    });

    it('notes_survive_serialization_and_old_data_gets_empty_notes', 0, () => {
      const cards = [makeCard('a', 'A', 'd', 3, 1)];
      cards[0].notes[1] = '第二天的一句话';
      const roundTripped = normalizeCards(deserializeCards(serializeCards(cards)));
      expect(roundTripped[0].notes[1]).assertEqual('第二天的一句话');

      // schema 4 的老数据（完全没有 notes 字段）
      const legacy = JSON.parse('[{"id":"x","name":"A","desc":"","length":200,"timeLimitDays":3,' +
        '"targetHours":12,"doneHours":0,"startAt":0,"endAt":0,"punchCard":[0,0,0,0],"archived":false}]'
        ) as TaskCardData[];
      const normalized = normalizeCards(legacy);
      expect(normalized[0].notes.length).assertEqual(4);
      expect(normalized[0].notes[0]).assertEqual('');
    });
  });

  // -------------------------------------------------------------------------
  // 删除卡片后的下标修正
  //
  // 删除是唯一会"让所有下标位移"的操作，最容易出的 bug 是：
  // 删掉排在前面的一张卡之后，"当前展开"仍然指向旧位置，于是点开 A 显示 B。
  // 这里把规则钉死，页面在 MANAGE_delete_card / MANAGE_delete_by_id 两处共用。
  // -------------------------------------------------------------------------
  describe('CardDeleteIndex', () => {
    it('deleting_the_selected_card_collapses_selection', 0, () => {
      expect(shiftIndexAfterDelete(0, 0)).assertEqual(-1);
      expect(shiftIndexAfterDelete(3, 3)).assertEqual(-1);
    });

    it('cards_after_the_removed_one_shift_left', 0, () => {
      // 删掉下标 1，原来的 2/3 变成 1/2
      expect(shiftIndexAfterDelete(2, 1)).assertEqual(1);
      expect(shiftIndexAfterDelete(3, 1)).assertEqual(2);
    });

    it('cards_before_the_removed_one_keep_their_index', 0, () => {
      expect(shiftIndexAfterDelete(0, 1)).assertEqual(0);
      expect(shiftIndexAfterDelete(1, 3)).assertEqual(1);
    });

    it('no_selection_and_invalid_input_are_left_alone', 0, () => {
      // -1 表示"没有展开任何卡片"，删卡不应该让它变成有效下标
      expect(shiftIndexAfterDelete(-1, 0)).assertEqual(-1);
      expect(shiftIndexAfterDelete(-1, 5)).assertEqual(-1);
      // 非法删除下标：原样返回，避免把状态改坏
      expect(shiftIndexAfterDelete(2, -1)).assertEqual(2);
    });
  });

  // -------------------------------------------------------------------------
  // 进度预测（按最近实际速度估计还要多久）
  //
  // 锁定的语义：
  //   · 无限目标（1001）/ 无限期限（367）不做预测；
  //   · 已完成 -> done；窗口内 0 投入 -> no-pace（不瞎猜）；
  //   · 观察窗口 = min(最近 N 天, 卡片已存在天数)，新卡片不被空白历史拉低；
  //   · 预计完成日晚于期限 -> late 并给出超出天数，否则 on-track。
  // -------------------------------------------------------------------------
  describe('CardForecast', () => {
    const DAY: number = 86400000;

    it('unlimited_target_or_deadline_is_not_forecast', 0, () => {
      const row = createPunchCard(10);
      expect(forecastCard(row, START, 0, 1001, 10, START + DAY, START, 7).status).assertEqual('none');
      expect(forecastCard(row, START, 0, 10, 367, START + DAY, START, 7).status).assertEqual('none');
    });

    it('finished_card_reports_done', 0, () => {
      const row = createPunchCard(10);
      expect(forecastCard(row, START, 10, 10, 10, START + DAY, START, 7).status).assertEqual('done');
      // 超额完成同样是 done
      expect(forecastCard(row, START, 12, 10, 10, START + DAY, START, 7).status).assertEqual('done');
    });

    it('zero_recent_activity_reports_no_pace', 0, () => {
      const row = createPunchCard(10);
      const f = forecastCard(row, START - 3 * DAY, 0, 10, 10, START + 30 * DAY, START, 7);
      expect(f.status).assertEqual('no-pace');
      expect(f.dailyPace).assertEqual(0);
      expect(f.daysNeeded).assertEqual(0);
      expect(f.remainingHours).assertEqual(10);
    });

    it('steady_pace_finishes_in_time', 0, () => {
      // 卡片已存在 5 天（第 0..4 天各 1 小时），日均 1 小时
      const row = createPunchCard(10);
      row[0] = 1; row[1] = 1; row[2] = 1; row[3] = 1; row[4] = 1;
      const f = forecastCard(row, START - 4 * DAY, 5, 10, 10, START + 30 * DAY, START, 7);
      expect(f.observedDays).assertEqual(5);
      expect(f.dailyPace).assertEqual(1);
      expect(f.remainingHours).assertEqual(5);
      expect(f.daysNeeded).assertEqual(5);
      expect(f.status).assertEqual('on-track');
      expect(f.daysLate).assertEqual(0);
    });

    it('same_pace_against_tight_deadline_reports_late', 0, () => {
      // 与上例同样的速度，但期限只剩 2 天 -> 需要 5 天，晚 3 天
      const row = createPunchCard(10);
      row[0] = 1; row[1] = 1; row[2] = 1; row[3] = 1; row[4] = 1;
      const f = forecastCard(row, START - 4 * DAY, 5, 10, 10, START + 2 * DAY, START, 7);
      expect(f.daysNeeded).assertEqual(5);
      expect(f.status).assertEqual('late');
      expect(f.daysLate).assertEqual(3);
    });

    it('brand_new_card_is_not_diluted_by_empty_history', 0, () => {
      // 今天才建的卡，今天记了 2 小时：观察窗口应该是 1 天而不是 7 天，
      // 否则日均会被压成 2/7，预测出"还要 28 天"这种荒谬结论。
      const row = createPunchCard(10);
      row[0] = 2;
      const f = forecastCard(row, START, 2, 10, 10, START + 100 * DAY, START, 7);
      expect(f.observedDays).assertEqual(1);
      expect(f.dailyPace).assertEqual(2);
      expect(f.daysNeeded).assertEqual(4);
    });
  });
}
