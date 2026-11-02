/**
 * 寸进 · CUNJIN —— 卡片详情：预计时长 / 开始计时
 *
 * 从 pages/Index.ets 的「PLAN ESTIMATED」FlowItem 原样搬出。
 * 尺寸（250 / 240）、字号、颜色、动画延迟（500）逐字保留。
 *
 * ⚠ 关键：onClick 里的 4 步顺序是有意义的，不能被合并或重排——
 *   1. WORK_start_card(卡片名)
 *   2. STATUS_card_index_of_last_expanded = -2   ← collapse 会把它当成"刚从卡片流返回"
 *   3. CARD_collapse_card_detail(true, true)      ← 内部按 -2 + 3 算出滚动目标
 *   4. STATUS_card_index_of_last_expanded = 0
 * 因此这里保留 2 个回调 + 1 个 @Link 索引，按原顺序逐个触发，不做"优化"。
 */

import { animateParam } from '../design/JunHaoUi';

@Component
export struct EstimatingBlock {
  // == CARD_get_average_daily_work_left_processed_for_display()
  @Prop average_left_text: string;
  // == DATA_cards_name[STATUS_card_expanding]（开始计时要用它写工作状态）
  @Prop card_name: string;
  // == WORK_is_work_on_idle()
  @Prop work_is_idle: boolean;
  @Prop font_color: string;
  @Prop block_background_color: string;
  @Prop detail_hidden: boolean;
  @Prop wide_screen: boolean;

  // ── 进度预测（按最近 7 天的实际速度，与上面"每天仅需"的理想值并列）──
  // status: 'none'（无限目标/期限，不显示）/ 'done' / 'no-pace' / 'on-track' / 'late'
  @Prop forecast_status: string;
  @Prop forecast_days: number;
  @Prop forecast_late: number;

  // 第 2 步与第 4 步要写父页面的展开下标，必须双向绑定
  @Link STATUS_card_index_of_last_expanded: number;

  // 第 1 步：页面执行 WORK_start_card（含落盘）
  onStartWork: (card_name: string) => void = () => {
  };
  // 第 3 步：页面执行 CARD_collapse_card_detail(true, true)
  onCollapseDetail: () => void = () => {
  };

  build() {
    FlowItem() {
      Column({ space: 5 }) {
        Text($r("app.string.Card_Progress_Desc_Estimating")).fontSize(16).fontColor(this.font_color)

        Row() {
          Text(this.average_left_text)
            .fontSize(40)
            .fontColor(this.font_color)
            .fontWeight(FontWeight.Bold)
          Text($r('app.string.Add_Value_Unit_Hour'))
            .fontSize(16)
            .fontColor(this.font_color)
            .margin({ bottom: 6 })
        }.alignItems(VerticalAlign.Bottom)

        Text($r('app.string.Card_Progress_Desc_Estimating_Hours'))
          .fontSize(16)
          .fontColor(this.font_color)
          .textAlign(TextAlign.Center)

        // 现实预测：照最近的实际速度，还来不来得及
        if (this.forecast_status == 'done') {
          Text('已经完成啦')
            .fontSize(13)
            .fontColor(this.font_color)
            .opacity(0.7)
            .textAlign(TextAlign.Center)
        } else if (this.forecast_status == 'no-pace') {
          Text('最近还没有记录，暂时无法预测')
            .fontSize(13)
            .fontColor(this.font_color)
            .opacity(0.7)
            .textAlign(TextAlign.Center)
        } else if (this.forecast_status == 'late') {
          Text('按最近速度还需 ' + this.forecast_days.toString() + ' 天，会比期限晚 ' +
          this.forecast_late.toString() + ' 天')
            .fontSize(13)
            .fontColor(this.font_color)
            .opacity(0.7)
            .textAlign(TextAlign.Center)
        } else if (this.forecast_status == 'on-track') {
          Text('按最近速度还需 ' + this.forecast_days.toString() + ' 天，来得及')
            .fontSize(13)
            .fontColor(this.font_color)
            .opacity(0.7)
            .textAlign(TextAlign.Center)
        }

        Button() {
          Text(this.work_is_idle ? $r("app.string.Work_Start") :
          $r("app.string.Work_Start_Other_Ongoing"))
            .fontSize(15)
            .fontColor(this.block_background_color)
            .fontWeight(FontWeight.Bolder)

        }
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .width("100%")
        .padding(5)
        .margin({ top: 15 })
        .backgroundColor(this.font_color)
        .onClick(() => {
          if (this.work_is_idle) {
            // 严格保持原顺序：开始计时 → 置 -2 → 收起详情 → 归零
            this.onStartWork(this.card_name)
            this.STATUS_card_index_of_last_expanded = -2
            this.onCollapseDetail()
            this.STATUS_card_index_of_last_expanded = 0
          }
        })

        // START WORKING

      }
      .alignItems(HorizontalAlign.Center)
      .offset({ y: (this.detail_hidden) ? 100 : 0 })
      .visibility((this.detail_hidden) ? Visibility.Hidden : Visibility.Visible)
      .animation(animateParam(this.detail_hidden ? 0 : 500))
      .width("100%")

      // PLAN ESTIMATED
    }.width("100%")
    // 有预测文案时多给一行高度，避免把内容挤进固定高度里被裁掉
    .height((this.wide_screen ? 250 : 240) + (this.forecast_status == 'none' ? 0 : 24))
  }
}
